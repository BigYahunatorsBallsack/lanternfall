--!strict
-- Shards and the shop between waves (DESIGN.md section 3, Brotato direction since B1). Players earn Shards for the XP
-- orbs they pick up (ExperienceService.OrbsCollected, Config.Shop.shardsPerXp). When a wave ends (RunDirector phase
-- Shop) Harvesting pays out (Shards and team XP, then it grows) and every participant who is not out gets their own
-- offers (rolled by ShopService/ShopRules with their Luck); BuyShopOffer and RerollShop are checked here, weapons come
-- from WeaponService, items from StatService. Ready is handled by RunDirector. Offers follow what the player owns.
-- Sends ShopState to its player on every change. UpgradeService pays level-up rerolls with spendShards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local ExperienceService = require(script.Parent.ExperienceService)
local RunDirector = require(script.Parent.RunDirector)
local StatService = require(script.Parent.StatService)
local WeaponService = require(script.Parent.WeaponService)
local ShopRules = require(script.ShopRules)

type State = {
	shards: number, -- may hold fractions (leftover orbs are split); the client shows the whole Shards
	open: boolean,
	wave: number,
	offers: { Types.ShopOffer },
	rerolls: number, -- rerolls in the current shop
}

local ShopService = {}

local states: { [Player]: State } = {}
local rng = Random.new()
local offerCounter = 0

local function newState(): State
	return { shards = 0, open = false, wave = 0, offers = {}, rerolls = 0 }
end

local function payload(state: State): Types.ShopState
	return {
		shards = math.floor(state.shards),
		open = state.open,
		wave = state.wave,
		offers = state.offers,
		rerollPrice = ShopRules.rerollPrice(state.wave, state.rerolls),
	}
end

local function ownedWeapons(player: Player): { [string]: number }
	local owned: { [string]: number } = {}
	for _, weapon in WeaponService.getWeapons(player) do
		owned[weapon.id] = weapon.level
	end
	return owned
end

-- Brings unsold offers up to date with what the player owns now (other purchases, chests): the level or count after
-- buying, "new" or not, and drops offers that can no longer be bought (max level, weapon slots full, item limit).
local function refresh(player: Player, state: State)
	local weapons = ownedWeapons(player)
	local weaponCount = 0
	for _ in weapons do
		weaponCount += 1
	end
	local items = StatService.getItemCounts(player)
	for index = #state.offers, 1, -1 do
		local offer = state.offers[index]
		if not offer.sold then
			local owned = if offer.kind == "Weapon" then weapons[offer.itemId] else items[offer.itemId]
			offer.level = (owned or 0) + 1
			offer.isNew = owned == nil
			local blocked
			if offer.kind == "Weapon" then
				blocked = if owned then owned >= Config.Player.maxItemLevel else weaponCount >= Config.Player.maxWeapons
			else
				local item = Config.Items.byId[offer.itemId]
				blocked = item == nil or (item.limit ~= nil and (owned or 0) >= item.limit)
			end
			if blocked then
				table.remove(state.offers, index)
			end
		end
	end
end

local function send(player: Player, state: State)
	if state.open then
		refresh(player, state)
	end
	Net.fireClient("ShopState", player, payload(state))
end

local function roll(player: Player, state: State)
	state.offers = ShopRules.roll({
		wave = state.wave,
		luck = StatService.getStat(player, "luck"),
		weapons = WeaponService.getImplemented(),
		ownedWeapons = ownedWeapons(player),
		maxWeapons = Config.Player.maxWeapons,
		maxLevel = Config.Player.maxItemLevel,
		ownedItems = StatService.getItemCounts(player),
		nextId = function(): string
			offerCounter += 1
			return tostring(offerCounter)
		end,
		random = function(): number
			return rng:NextNumber()
		end,
	})
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
			harvest(player, state)
			state.open = true
			state.wave = wave
			state.rerolls = 0
			roll(player, state)
			send(player, state)
		end
	end
end

local function closeShop()
	for player, state in states do
		if state.open then
			state.open = false
			table.clear(state.offers)
			send(player, state)
		end
	end
end

-- Gives the player what the offer sells: a new weapon or its next level, or one more of an item.
local function grant(player: Player, offer: Types.ShopOffer): boolean
	if offer.kind == "Item" then
		return (StatService.addItem(player, offer.itemId))
	end
	if ownedWeapons(player)[offer.itemId] then
		return (WeaponService.levelUp(player, offer.itemId))
	end
	return (WeaponService.addWeapon(player, offer.itemId))
end

local function buy(player: Player, offerId: string)
	local state = states[player]
	if not (state and state.open and RunDirector.getPhase() == "Shop") then
		return
	end
	for _, offer in state.offers do
		if offer.id == offerId and not offer.sold then
			if state.shards < offer.price then
				Net.fireClient("Notify", player, "Not enough Shards")
				return
			end
			if not grant(player, offer) then
				Net.fireClient("Notify", player, "You can't take that right now")
				send(player, state) -- drops the offer if it can no longer be bought
				return
			end
			state.shards -= offer.price
			offer.sold = true
			send(player, state)
			return
		end
	end
end

local function reroll(player: Player)
	local state = states[player]
	if not (state and state.open and RunDirector.getPhase() == "Shop") then
		return
	end
	local price = ShopRules.rerollPrice(state.wave, state.rerolls)
	if state.shards < price then
		Net.fireClient("Notify", player, "Not enough Shards")
		return
	end
	state.shards -= price
	state.rerolls += 1
	roll(player, state)
	send(player, state)
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

-- Adds Shards (admin debug command, tests).
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
