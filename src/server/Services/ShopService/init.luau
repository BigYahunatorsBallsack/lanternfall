--!strict
-- Shards and the shop between waves (DESIGN.md section 3, Brotato direction since B1). Players earn Shards for the XP
-- orbs they pick up (ExperienceService.OrbsCollected, Config.Shop.shardsPerXp). When a wave ends (RunDirector phase
-- Shop) every participant who is not out gets their own offers (rolled by ShopService/ShopRules); BuyShopOffer and
-- RerollShop are checked here, the item itself comes from UpgradeService.grantItem. Ready is handled by RunDirector.
-- Offers follow what the player owns (level-up cards picked in the same shop, other purchases). Sends ShopState to its
-- player on every change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local ExperienceService = require(script.Parent.ExperienceService)
local RunDirector = require(script.Parent.RunDirector)
local UpgradeService = require(script.Parent.UpgradeService)
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
local passiveIds: { string } = {}
for id in Config.Passives do
	table.insert(passiveIds, id)
end
table.sort(passiveIds)
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

-- Brings unsold offers up to date with what the player owns now (level-up cards, other purchases): the level after
-- buying, "new" or not, and drops offers that can no longer be bought (max level, slots full).
local function refresh(player: Player, state: State)
	local owned = {
		Weapon = ownedWeapons(player),
		Passive = UpgradeService.getPassiveLevels(player),
	}
	local limits = { Weapon = Config.Player.maxWeapons, Passive = Config.Player.maxPassives }
	for index = #state.offers, 1, -1 do
		local offer = state.offers[index]
		if not offer.sold then
			local levels = owned[offer.kind]
			local level = levels[offer.itemId]
			local count = 0
			for _ in levels do
				count += 1
			end
			if level then
				offer.level = level + 1
				offer.isNew = false
			else
				offer.level = 1
				offer.isNew = true
			end
			if (level and level >= Config.Player.maxItemLevel) or (not level and count >= limits[offer.kind]) then
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
		weapons = WeaponService.getImplemented(),
		passives = passiveIds,
		ownedWeapons = ownedWeapons(player),
		ownedPassives = UpgradeService.getPassiveLevels(player),
		maxWeapons = Config.Player.maxWeapons,
		maxPassives = Config.Player.maxPassives,
		maxLevel = Config.Player.maxItemLevel,
		nextId = function(): string
			offerCounter += 1
			return tostring(offerCounter)
		end,
		random = function(): number
			return rng:NextNumber()
		end,
	})
end

local function openShop()
	local wave = RunDirector.getWave()
	for _, player in RunDirector.getParticipants() do
		local state = states[player]
		if state and RunDirector.getParticipantState(player) ~= "Out" then
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
			if not UpgradeService.grantItem(player, offer.kind, offer.itemId) then
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
	-- the level-up cards come before the shop and may change what an offer gives
	UpgradeService.Picked:Connect(function(player: Player)
		local state = states[player]
		if state and state.open then
			send(player, state)
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
