--!strict
-- Shards and the shop between waves (DESIGN.md section 3, Brotato direction since B1). Players earn Shards for the XP
-- orbs they pick up (ExperienceService.OrbsCollected, Config.Shop.shardsPerXp). When a wave ends (RunDirector phase
-- Shop) Harvesting pays out (Shards and team XP, then it grows) and every participant who is not out gets their own
-- offers (rolled by ShopService/ShopRules with their Luck). Since B3 the shop is complete: offers can be locked (they
-- stay through rerolls and into the next shop at their price), weapons come in tiers I-IV and can be sold (SellWeapon)
-- or merged with a copy of the same tier (MergeWeapons; buying one with every slot full merges it right away), and
-- every few purchases earn a free reroll. BuyShopOffer, RerollShop, LockShopOffer, SellWeapon and MergeWeapons are
-- checked here; weapons come from WeaponService, items from StatService. Ready is handled by RunDirector. Offers
-- follow what the player owns. Sends ShopState to its player on every change. UpgradeService pays level-up rerolls
-- with spendShards. Since B4 the shop stats work (Item Prices, Free Rerolls, Sell Value), offers roll on
-- RandomService's Shop stream, and signals tell EffectService about the wave end (before Harvesting pays), the
-- opened shop, rerolls, purchases, sales and the Shards held; item effects pay Shards through addShards.
-- B11 part 2: a RunDirector checkpoint keeps the Shards and locked offers from the start of each wave ("Retry wave").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Copy = require(Shared.Util.Copy)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local StatMath = require(Shared.Util.StatMath)
local Types = require(Shared.Net.Types)

local ExperienceService = require(script.Parent.ExperienceService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local StatService = require(script.Parent.StatService)
local WeaponService = require(script.Parent.WeaponService)
local ShopRules = require(script.ShopRules)

type State = {
	shards: number, -- may hold fractions (leftover orbs are split); the client shows the whole Shards
	open: boolean,
	wave: number,
	offers: { Types.ShopOffer },
	carried: { Types.ShopOffer }, -- locked offers kept for the next shop while no shop is open
	rerolls: number, -- paid rerolls in the current shop
	buys: number, -- purchases in the current shop
	freeRerolls: number, -- free rerolls of the current shop (Free Rerolls stat and purchases) not used yet
	reportedShards: number, -- whole Shards last told to ShardsChanged
}

local ShopService = {}

-- (player: Player): a wave ended for this participant; fired before Harvesting pays and the offers roll
ShopService.WaveEnding = Signal.new()
-- (player: Player): the shop opened with fresh offers (sent to the player right after the listeners ran)
ShopService.Opened = Signal.new()
-- (player: Player): the player rerolled the offers
ShopService.Rerolled = Signal.new()
-- (player: Player, kind: "Weapon" | "Item", itemId: string): the player bought an offer
ShopService.Bought = Signal.new()
-- (player: Player, weaponId: string): the player sold a weapon
ShopService.Sold = Signal.new()
-- (player: Player, shards: number): the whole Shards the player holds changed
ShopService.ShardsChanged = Signal.new()

local states: { [Player]: State } = {}
local offerCounter = 0

local function newState(): State
	return {
		shards = 0,
		open = false,
		wave = 0,
		offers = {},
		carried = {},
		rerolls = 0,
		buys = 0,
		freeRerolls = 0,
		reportedShards = 0,
	}
end

local function priceFactor(player: Player): number
	return StatMath.priceFactor(StatService.getStat(player, "itemPrice"))
end

local function sellPrice(player: Player, weaponId: string, tier: number, wave: number): number
	return ShopRules.sellPrice(weaponId, tier, wave, StatService.getStat(player, "sellValue"))
end

local function ownedWeapons(player: Player): { ShopRules.OwnedWeapon }
	local owned: { ShopRules.OwnedWeapon } = {}
	for _, weapon in WeaponService.getWeapons(player) do
		table.insert(owned, { id = weapon.id, tier = weapon.tier, evolution = weapon.evolution })
	end
	return owned
end

local function payload(player: Player, state: State): Types.ShopState
	local weapons: { Types.ShopWeapon } = {}
	for _, weapon in WeaponService.getWeapons(player) do
		table.insert(weapons, {
			uid = weapon.uid,
			id = weapon.id,
			tier = weapon.tier,
			evolution = weapon.evolution,
			sellPrice = sellPrice(player, weapon.id, weapon.tier, state.wave),
			canMerge = WeaponService.findMergePartner(player, weapon.uid) ~= nil,
		})
	end
	return {
		shards = math.floor(state.shards),
		open = state.open,
		wave = state.wave,
		offers = state.offers,
		rerollPrice = if state.freeRerolls > 0 then 0 else ShopRules.rerollPrice(state.wave, state.rerolls),
		freeRerolls = state.freeRerolls,
		weapons = weapons,
		maxWeapons = WeaponService.getMaxWeapons(player),
	}
end

-- Brings unsold offers up to date with what the player owns now (other purchases, sales, merges, chests): the count,
-- "new" or not, whether a weapon merges or is blocked, the price with the current Item Prices, and drops items at
-- their limit.
local function refresh(player: Player, state: State)
	local weapons = ownedWeapons(player)
	local items = StatService.getItemCounts(player)
	local factor = priceFactor(player)
	for index = #state.offers, 1, -1 do
		local offer = state.offers[index]
		if not offer.sold then
			offer.price = ShopRules.offerPrice(offer, factor)
			if offer.kind == "Weapon" then
				local copies = 0
				for _, weapon in weapons do
					if weapon.id == offer.itemId then
						copies += 1
					end
				end
				offer.count = copies
				offer.isNew = copies == 0
				offer.merges, offer.blocked = ShopRules.weaponStatus(
					offer.itemId,
					offer.tier,
					weapons,
					WeaponService.getMaxWeapons(player),
					Config.Player.maxWeaponTier,
					RunDirector.getParticipantClassId(player)
				)
			else
				local owned = items[offer.itemId] or 0
				offer.count = owned + 1
				offer.isNew = owned == 0
				local item = Config.Items.byId[offer.itemId]
				if item == nil or (item.limit ~= nil and owned >= item.limit) then
					table.remove(state.offers, index)
				end
			end
		end
	end
end

local function send(player: Player, state: State)
	if state.open then
		refresh(player, state)
	end
	Net.fireClient("ShopState", player, payload(player, state))
	local whole = math.floor(state.shards)
	if whole ~= state.reportedShards then
		state.reportedShards = whole
		ShopService.ShardsChanged:Fire(player, whole)
	end
end

-- Paket 13: weapon and item ids the player has not unlocked yet (never offered).
local function lockedIds(player: Player): { [string]: boolean }
	local set = PlayerDataService.lockedSet(player, "weapons")
	for itemId in PlayerDataService.lockedSet(player, "items") do
		set[itemId] = true
	end
	return set
end

-- New offers; locked unsold ones (`keep`) stay. `previous`: ids of the roll before, not offered again if possible.
local function roll(player: Player, state: State, keep: { Types.ShopOffer }, previous: { [string]: boolean }?)
	state.offers = ShopRules.roll({
		classId = RunDirector.getParticipantClassId(player),
		wave = state.wave,
		luck = StatService.getStat(player, "luck"),
		priceFactor = priceFactor(player),
		weapons = WeaponService.getImplemented(),
		ownedWeapons = ownedWeapons(player),
		maxWeapons = WeaponService.getMaxWeapons(player),
		maxTier = Config.Player.maxWeaponTier,
		ownedItems = StatService.getItemCounts(player),
		keep = keep,
		previous = previous,
		unavailable = lockedIds(player),
		nextId = function(): string
			offerCounter += 1
			return tostring(offerCounter)
		end,
		random = function(): number
			return RandomService.number("Shop", player)
		end,
	})
end

local function lockedOffers(offers: { Types.ShopOffer }): { Types.ShopOffer }
	local locked = {}
	for _, offer in offers do
		if offer.locked and not offer.sold then
			table.insert(locked, offer)
		end
	end
	return locked
end

-- End of a wave: Harvesting gives its value in Shards (negative Harvesting takes them, down to 0) and team XP, then
-- grows (StatService.growHarvesting).
local function harvest(player: Player, state: State)
	local harvesting = StatService.getStat(player, "harvesting")
	if harvesting == 0 then
		return
	end
	state.shards = math.max(0, state.shards + harvesting)
	ExperienceService.addXp(harvesting)
	StatService.growHarvesting(player)
end

local function openShop()
	local wave = RunDirector.getWave()
	for _, player in RunDirector.getParticipants() do
		local state = states[player]
		if state and RunDirector.getParticipantState(player) ~= "Out" then
			ShopService.WaveEnding:Fire(player) -- wave-end item effects come before Harvesting (Brotato)
			harvest(player, state)
			state.open = true
			state.wave = wave
			state.rerolls = 0
			state.buys = 0
			state.freeRerolls = math.max(0, math.floor(StatService.getStat(player, "freeRerolls")))
			roll(player, state, state.carried, nil)
			state.carried = {}
			ShopService.Opened:Fire(player)
			send(player, state)
		end
	end
end

local function closeShop()
	for player, state in states do
		if state.open then
			state.open = false
			state.carried = lockedOffers(state.offers)
			state.offers = {}
			send(player, state)
		end
	end
end

-- Gives the player what the offer sells: one more of an item, or a weapon of the offer's tier. With every weapon slot
-- full, the owned copy of the same tier goes one tier up instead (Brotato merges on purchase).
local function grant(player: Player, offer: Types.ShopOffer): boolean
	if offer.kind == "Item" then
		return (StatService.addItem(player, offer.itemId))
	end
	local weapons = WeaponService.getWeapons(player)
	local merges, blocked = ShopRules.weaponStatus(
		offer.itemId,
		offer.tier,
		weapons,
		WeaponService.getMaxWeapons(player),
		Config.Player.maxWeaponTier,
		RunDirector.getParticipantClassId(player)
	)
	if blocked then
		return false
	end
	if merges then
		for _, weapon in weapons do
			if weapon.id == offer.itemId and weapon.tier == offer.tier and not weapon.evolution then
				return (WeaponService.raiseTier(player, weapon.uid))
			end
		end
		return false
	end
	return (WeaponService.addWeapon(player, offer.itemId, offer.tier))
end

local function openState(player: Player): State?
	local state = states[player]
	if state and state.open and RunDirector.getPhase() == "Shop" then
		return state
	end
	return nil
end

local function findOffer(state: State, offerId: string): Types.ShopOffer?
	for _, offer in state.offers do
		if offer.id == offerId then
			return offer
		end
	end
	return nil
end

local function buy(player: Player, offerId: string)
	local state = openState(player)
	local offer = state and findOffer(state, offerId)
	if not (state and offer) or offer.sold then
		return
	end
	if state.shards < offer.price then
		Net.fireClient("Notify", player, "Not enough Shards")
		return
	end
	if offer.blocked or not grant(player, offer) then
		Net.fireClient(
			"Notify",
			player,
			if offer.kind == "Weapon"
				then "Weapon slots full: sell or merge one first"
				else "You can't take that right now"
		)
		send(player, state)
		return
	end
	state.shards -= offer.price
	offer.sold = true
	offer.locked = false
	state.buys += 1
	if state.buys % Config.Shop.freeRerollAfterBuys == 0 then
		state.freeRerolls += 1
	end
	ShopService.Bought:Fire(player, offer.kind, offer.itemId)
	send(player, state)
end

local function reroll(player: Player)
	local state = openState(player)
	if not state then
		return
	end
	if state.freeRerolls > 0 then
		state.freeRerolls -= 1
	else
		local price = ShopRules.rerollPrice(state.wave, state.rerolls)
		if state.shards < price then
			Net.fireClient("Notify", player, "Not enough Shards")
			return
		end
		state.shards -= price
		state.rerolls += 1
	end
	local previous: { [string]: boolean } = {}
	for _, offer in state.offers do
		if not offer.locked then
			previous[offer.itemId] = true
		end
	end
	roll(player, state, lockedOffers(state.offers), previous)
	ShopService.Rerolled:Fire(player)
	send(player, state)
end

local function lock(player: Player, offerId: string, locked: boolean)
	local state = openState(player)
	local offer = state and findOffer(state, offerId)
	if state and offer and not offer.sold and offer.locked ~= locked then
		offer.locked = locked
		send(player, state)
	end
end

local function sell(player: Player, uid: number)
	local state = openState(player)
	if not state then
		return
	end
	local weapons = WeaponService.getWeapons(player)
	for _, weapon in weapons do
		if weapon.uid == uid then
			if #weapons <= 1 then
				Net.fireClient("Notify", player, "You can't sell your last weapon")
				return
			end
			if WeaponService.removeWeapon(player, uid) then
				state.shards += sellPrice(player, weapon.id, weapon.tier, state.wave)
				ShopService.Sold:Fire(player, weapon.id)
				send(player, state)
			end
			return
		end
	end
end

local function merge(player: Player, uid: number)
	local state = openState(player)
	if not state then
		return
	end
	if WeaponService.merge(player, uid) then
		send(player, state)
	else
		Net.fireClient("Notify", player, "Needs a second copy of the same tier")
	end
end

-- Lifecycle -------------------------------------------------------------------------

function ShopService.init()
	ExperienceService.OrbsCollected:Connect(function(player: Player, xp: number)
		local state = states[player]
		if state then
			local before = math.floor(state.shards)
			state.shards += xp * Config.Shop.shardsPerXp
			if math.floor(state.shards) ~= before then
				send(player, state)
			end
		end
	end)
	RunDirector.RunStarted:Connect(function(participants: { Player })
		table.clear(states)
		for _, player in participants do
			states[player] = newState()
			send(player, states[player])
		end
	end)
	RunDirector.addCheckpoint("Shop", function()
		local saved = {}
		for player, state in states do
			saved[player] = {
				shards = state.shards,
				carried = Copy.deep(if state.open then lockedOffers(state.offers) else state.carried),
			}
		end
		return saved
	end, function(saved: { [Player]: { shards: number, carried: { Types.ShopOffer } } })
		for player, state in states do
			local data = saved[player]
			if data then
				state.shards = data.shards
				state.carried = Copy.deep(data.carried)
				state.open = false
				state.offers = {}
				send(player, state)
			end
		end
	end)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Shop" then
			openShop()
		else
			closeShop()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		local state = states[requester]
		if state then
			send(requester, state)
		end
	end)

	Net.onServer("BuyShopOffer", buy) -- ids the server did not offer are ignored
	Net.onServer("RerollShop", reroll)
	Net.onServer("LockShopOffer", lock)
	Net.onServer("SellWeapon", sell) -- uids the player does not carry are ignored
	Net.onServer("MergeWeapons", merge)
end

-- Queries and commands ------------------------------------------------------------------

-- Whole Shards of the player in the current (or last) run.
function ShopService.getShards(player: Player): number
	local state = states[player]
	return if state then math.floor(state.shards) else 0
end

-- Takes `amount` Shards if the player has them (level-up rerolls). False otherwise.
function ShopService.spendShards(player: Player, amount: number): boolean
	local state = states[player]
	if not state or state.shards < amount then
		return false
	end
	state.shards -= amount
	send(player, state)
	return true
end

-- Adds Shards (item effects, admin debug command, tests).
function ShopService.addShards(player: Player, amount: number): boolean
	local state = states[player]
	if not state then
		return false
	end
	state.shards += amount
	send(player, state)
	return true
end

-- The player's current offers (smoke test).
function ShopService.getOffers(player: Player): { Types.ShopOffer }
	local state = states[player]
	return if state then state.offers else {}
end

return ShopService
