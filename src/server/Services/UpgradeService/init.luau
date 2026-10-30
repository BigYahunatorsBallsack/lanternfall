--!strict
-- Level-up cards (DESIGN.md sections 8 and 9, Brotato direction since B2). Every time the team levels up
-- (ExperienceService.LevelGained), each participant who is not out gets one more choice of their own stat cards
-- (rolled by UpgradeService/UpgradePool with their Luck). The choices wait until the wave ends and open one after
-- another in the shop phase; whatever is still open when the next wave starts is picked automatically. Handles
-- ChooseUpgrade and RequestReroll (new cards for Shards at the shop's reroll prices, paid through ShopService), picks
-- the first card after Config.Run.levelUp.autoPickSeconds and adds the picked stat through StatService. Sends
-- LevelUpOffer to the chooser. Elite chests (LootService) call grantChest: an evolution or an item; AdminService uses
-- getEvolutions and evolve. Since B6 crates (LootService.addCrate -> addCrate) wait for the end of the wave too and open
-- first, one by one: an item rolled like a shop item (wave and Luck, Config.Loot.crate), taken or sold for Shards
-- (ChooseCrate, CrateOffer to the chooser); taken automatically when its time runs out or the shop closes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local LootRules = require(Shared.Util.LootRules)
local Net = require(Shared.Net)
local StatMath = require(Shared.Util.StatMath)
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local ExperienceService = require(script.Parent.ExperienceService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local ShopService = require(script.Parent.ShopService)
local StatService = require(script.Parent.StatService)
local WeaponService = require(script.Parent.WeaponService)
local ShopRules = require(script.Parent.ShopService.ShopRules)
local UpgradePool = require(script.UpgradePool)

local LevelUp = Config.Run.levelUp

type Offer = { cards: { Types.UpgradeCard }, expiresAt: number, rerolls: number }

-- An open crate (B6): its item and what selling it gives.
type Crate = { itemId: string, tier: number, sellPrice: number, expiresAt: number }

type State = {
	levels: { number }, -- team levels still to choose for; the first one is open while `offer` is set
	offer: Offer?,
	crates: number, -- crates waiting (not counting the open one)
	crate: Crate?, -- open crate; crates open before level-up cards
}

local UpgradeService = {}

local states: { [Player]: State } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rerollPrice(offer: Offer?): number
	return ShopRules.rerollPrice(RunDirector.getWave(), if offer then offer.rerolls else 0)
end

local function sendOffer(player: Player, state: State)
	local offer = state.offer
	local payload: Types.LevelUpOffer = {
		open = offer ~= nil,
		level = state.levels[1] or 0,
		cards = if offer then offer.cards else {},
		expiresAt = if offer then offer.expiresAt else 0,
		rerollPrice = rerollPrice(offer),
		pending = if offer then math.max(0, #state.levels - 1) else #state.levels,
	}
	Net.fireClient("LevelUpOffer", player, payload)
end

local function sendCrate(player: Player, state: State)
	local crate = state.crate
	local payload: Types.CrateOffer = {
		open = crate ~= nil,
		itemId = if crate then crate.itemId else "",
		tier = if crate then crate.tier else 0,
		count = if crate then (StatService.getItemCounts(player)[crate.itemId] or 0) + 1 else 0,
		sellPrice = if crate then crate.sellPrice else 0,
		expiresAt = if crate then crate.expiresAt else 0,
		pending = state.crates,
	}
	Net.fireClient("CrateOffer", player, payload)
end

-- The item of a crate opened after the wave that just ended: rarity like a shop item, at least
-- Config.Loot.crate.minTier; nil if no item is left at all.
local function rollCrate(player: Player): Crate?
	local function random(): number
		return RandomService.number("Loot", player)
	end
	local wave = RunDirector.getWave()
	local tier =
		math.max(Config.Loot.crate.minTier, StatMath.rollTier(wave, StatService.getStat(player, "luck"), random()))
	local itemId = ShopRules.pickItem(tier, StatService.getItemCounts(player), {}, random)
	local item = itemId and Config.Items.byId[itemId]
	if not (itemId and item) then
		return nil
	end
	local price = ShopRules.price(item.price, wave)
	return {
		itemId = itemId,
		tier = item.tier,
		sellPrice = LootRules.sellPrice(price, Config.Shop.sellShare, StatService.getStat(player, "sellValue")),
		expiresAt = now() + LevelUp.autoPickSeconds,
	}
end

local function roll(player: Player, state: State, avoid: { [string]: boolean }?): { Types.UpgradeCard }
	return UpgradePool.roll({
		level = state.levels[1] or 1,
		luck = StatService.getStat(player, "luck"),
		cardCount = LevelUp.cardCount,
		avoid = avoid,
		random = function(): number
			return RandomService.number("Upgrades", player)
		end,
	})
end

local function openNext(player: Player, state: State)
	state.offer = nil
	state.crate = nil
	while state.crates > 0 and not state.crate do
		state.crates -= 1
		state.crate = rollCrate(player)
	end
	sendCrate(player, state)
	if state.crate then
		CombatService.setChoosing(player, true)
		sendOffer(player, state) -- the level-ups waiting after the crates
		return
	end
	if #state.levels == 0 then
		state.offer = nil
		CombatService.setChoosing(player, false)
	else
		state.offer = { cards = roll(player, state, nil), expiresAt = now() + LevelUp.autoPickSeconds, rerolls = 0 }
		CombatService.setChoosing(player, true)
	end
	sendOffer(player, state)
end

local function closeAll(state: State, player: Player)
	table.clear(state.levels)
	state.crates = 0
	if state.offer or state.crate then
		openNext(player, state)
	else
		sendCrate(player, state)
	end
end

-- Takes (or sells) the open crate's item and opens what waits next. A crate item that hit its limit meanwhile is
-- sold instead.
local function chooseCrate(player: Player, take: boolean): boolean
	local state = states[player]
	local crate = state and state.crate
	if not (state and crate) then
		return false
	end
	state.crate = nil
	if not (take and StatService.addItem(player, crate.itemId)) then
		ShopService.addShards(player, crate.sellPrice)
	end
	openNext(player, state)
	return true
end

local function choose(player: Player, cardId: string): boolean
	local state = states[player]
	local offer = state and state.offer
	if not (state and offer) then
		return false
	end
	for _, card in offer.cards do
		if card.id == cardId then
			table.remove(state.levels, 1)
			state.offer = nil
			StatService.addUpgrade(player, card.stat, card.amount)
			openNext(player, state)
			return true
		end
	end
	return false
end

-- Takes every open and waiting crate and picks the first card of every open and waiting choice (the shop closed
-- before the player chose).
local function pickAll(player: Player, state: State)
	local crateGuard = state.crates + 2
	while (state.crate or state.crates > 0) and crateGuard > 0 do
		crateGuard -= 1
		if state.crate then
			chooseCrate(player, true)
		else
			openNext(player, state)
		end
	end
	local guard = #state.levels + 1
	while state.offer and state.offer.cards[1] and guard > 0 do
		guard -= 1
		choose(player, state.offer.cards[1].id)
	end
	table.clear(state.levels)
	sendOffer(player, state)
end

local function reroll(player: Player)
	local state = states[player]
	local offer = state and state.offer
	if not (state and offer) then
		return
	end
	if not ShopService.spendShards(player, rerollPrice(offer)) then
		Net.fireClient("Notify", player, "Not enough Shards")
		sendOffer(player, state) -- the client waits for an answer
		return
	end
	local avoid: { [string]: boolean } = {}
	for _, card in offer.cards do
		avoid[card.stat] = true
	end
	state.offer = {
		cards = roll(player, state, avoid),
		expiresAt = now() + LevelUp.autoPickSeconds,
		rerolls = offer.rerolls + 1,
	}
	sendOffer(player, state)
end

local function onLevelGained(level: number)
	local shopOpen = RunDirector.getPhase() == "Shop"
	for _, player in RunDirector.getParticipants() do
		local state = states[player]
		if state and RunDirector.getParticipantState(player) ~= "Out" then
			table.insert(state.levels, level)
			if shopOpen and not (state.offer or state.crate) then
				openNext(player, state)
			else
				sendOffer(player, state) -- shows the new number of choices waiting
			end
		end
	end
end

local function onRunStarted(participants: { Player })
	table.clear(states)
	for _, player in participants do
		states[player] = { levels = {}, offer = nil, crates = 0, crate = nil }
	end
end

local function autoPick()
	local time = now()
	for player, state in states do
		local offer = state.offer
		if offer and time >= offer.expiresAt and offer.cards[1] then
			choose(player, offer.cards[1].id)
		end
		local crate = state.crate
		if crate and time >= crate.expiresAt then
			chooseCrate(player, true)
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------

function UpgradeService.init()
	ExperienceService.LevelGained:Connect(onLevelGained)
	RunDirector.RunStarted:Connect(onRunStarted)
	RunDirector.PhaseChanged:Connect(function(phase, previous)
		if phase == "Ended" or phase == "Lobby" then
			for player, state in states do
				closeAll(state, player)
			end
		elseif phase == "Shop" then
			for player, state in states do
				if not (state.offer or state.crate) and (#state.levels > 0 or state.crates > 0) then
					openNext(player, state)
				end
			end
		elseif previous == "Shop" then
			for player, state in states do
				pickAll(player, state)
			end
		end
	end)
	RunDirector.ParticipantStateChanged:Connect(function(player, participantState)
		local state = states[player]
		if state and participantState == "Out" then
			closeAll(state, player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		local state = states[requester]
		if state and state.offer then
			sendOffer(requester, state)
		end
		if state then
			sendCrate(requester, state)
		end
	end)

	Net.onServer("ChooseUpgrade", function(player, cardId: string)
		choose(player, cardId) -- ids the server did not offer are ignored
	end)
	Net.onServer("RequestReroll", reroll)
	Net.onServer("ChooseCrate", function(player, take: boolean)
		chooseCrate(player, take) -- nothing happens without an open crate
	end)

	RunService.Heartbeat:Connect(autoPick)
end

-- Commands --------------------------------------------------------------------------

-- Turns the weapon into the evolution if the player may take it right now (getEvolutions).
function UpgradeService.evolve(player: Player, evolutionId: string): (boolean, string?)
	if not table.find(UpgradeService.getEvolutions(player), evolutionId) then
		return false, "NotEligible"
	end
	local evolution = Config.Evolutions[evolutionId]
	for _, weapon in WeaponService.getWeapons(player) do
		if weapon.id == evolution.weapon and weapon.tier >= Config.Player.maxWeaponTier and not weapon.evolution then
			return WeaponService.evolve(player, weapon.uid, evolutionId)
		end
	end
	return false, "NotEligible"
end

-- Gives the player what an elite chest holds (DESIGN.md sections 6 and 8): an evolution they may take now, else an
-- item (rarity by wave and Luck, at least Config.Items.chestMinTier), else healing. nil if they are not armed in the
-- run.
function UpgradeService.grantChest(player: Player): Types.ChestReward?
	if not (states[player] and WeaponService.isArmed(player)) then
		return nil
	end
	for _, evolutionId in UpgradeService.getEvolutions(player) do
		if UpgradeService.evolve(player, evolutionId) then
			return { kind = "Evolution", itemId = evolutionId, level = 0 }
		end
	end
	local itemId = ShopRules.chestItem(
		RunDirector.getWave(),
		StatService.getStat(player, "luck"),
		StatService.getItemCounts(player),
		function(): number
			return RandomService.number("Loot", player)
		end
	)
	if itemId and StatService.addItem(player, itemId) then
		return { kind = "Item", itemId = itemId, level = StatService.getItemCounts(player)[itemId] or 1 }
	end
	local _, maxHp = CombatService.getHp(player)
	CombatService.healPlayer(player, maxHp)
	return { kind = "Reward", itemId = "Heal", level = 0 }
end

-- A crate was picked up (LootService, B6): it opens at the end of the wave, before the level-up cards (right away if
-- the shop is open and nothing else is). False for players who are not in the run or out.
function UpgradeService.addCrate(player: Player): boolean
	local state = states[player]
	if not state or RunDirector.getParticipantState(player) == "Out" then
		return false
	end
	state.crates += 1
	if RunDirector.getPhase() == "Shop" and not (state.offer or state.crate) then
		openNext(player, state)
	else
		sendCrate(player, state)
	end
	return true
end

-- Queries ---------------------------------------------------------------------------

-- The open crate (item id, rarity, sell price) and how many wait after it, or nil (B6, tests).
function UpgradeService.getCrate(player: Player): ({ itemId: string, tier: number, sellPrice: number }?, number)
	local state = states[player]
	if not state then
		return nil, 0
	end
	local crate = state.crate
	return if crate then { itemId = crate.itemId, tier = crate.tier, sellPrice = crate.sellPrice } else nil,
		state.crates
end

-- Evolution ids the player may take now: weapon at max tier plus the item (DESIGN.md section 6), sorted.
function UpgradeService.getEvolutions(player: Player): { string }
	if not states[player] then
		return {}
	end
	return UpgradePool.evolutionsFor(
		WeaponService.getWeapons(player),
		StatService.getItemCounts(player),
		Config.Player.maxWeaponTier
	)
end

-- The cards the player can pick right now, or nil.
function UpgradeService.getOffer(player: Player): { Types.UpgradeCard }?
	local state = states[player]
	local offer = state and state.offer
	return if offer then offer.cards else nil
end

return UpgradeService
