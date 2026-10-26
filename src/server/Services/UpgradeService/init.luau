--!strict
-- Level-up cards and passives (DESIGN.md sections 6, 8 and 9). Every time the team levels up (ExperienceService
-- .LevelGained), each participant who is not out gets their own cards (rolled by UpgradeService/UpgradePool) and
-- stands still, invulnerable, while choosing (CombatService.setChoosing); weapons keep firing. Several level-ups
-- queue up. Handles ChooseUpgrade and RequestReroll, picks the first card after Config.Run.levelUp.autoPickSeconds
-- and applies the pick: weapons via WeaponService, passives as bonuses pushed to WeaponService, CombatService and
-- ExperienceService, rewards as healing or Embers. Sends LevelUpOffer to the chooser and Passives to everyone.
-- Chests (WP9) and AdminService use getEvolutions, evolve and addPassive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local ExperienceService = require(script.Parent.ExperienceService)
local RunDirector = require(script.Parent.RunDirector)
local WeaponService = require(script.Parent.WeaponService)
local UpgradePool = require(script.UpgradePool)

local LevelUp = Config.Run.levelUp
local REWARDS = { "Heal", "Embers" }

type Offer = { cards: { Types.UpgradeCard }, expiresAt: number }

type State = {
	passives: { [string]: number }, -- id -> level
	passiveOrder: { string }, -- in the order they were taken, for the HUD
	levels: { number }, -- team levels still to choose for; the first one is open while `offer` is set
	offer: Offer?,
	rerolls: number,
	bonusEmbers: number, -- from maxed-out rewards in this run; paid out with WP13
}

local UpgradeService = {}

local states: { [Player]: State } = {}
local passiveIds: { string } = {}
for id in Config.Passives do
	table.insert(passiveIds, id)
end
table.sort(passiveIds)
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function newState(): State
	return {
		passives = {},
		passiveOrder = {},
		levels = {},
		offer = nil,
		rerolls = LevelUp.freeRerollsPerRun,
		bonusEmbers = 0,
	}
end

local function passiveLoadout(player: Player): Types.PassiveLoadout
	local list: { Types.PassiveInfo } = {}
	local state = states[player]
	if state then
		for _, id in state.passiveOrder do
			table.insert(list, { id = id, level = state.passives[id] })
		end
	end
	return { userId = player.UserId, passives = list }
end

local function sendPassives(player: Player)
	Net.fireAllClients("Passives", passiveLoadout(player))
end

local function sendOffer(player: Player, state: State)
	local offer = state.offer
	local payload: Types.LevelUpOffer = {
		open = offer ~= nil,
		level = state.levels[1] or 0,
		cards = if offer then offer.cards else {},
		expiresAt = if offer then offer.expiresAt else 0,
		rerolls = state.rerolls,
		pending = math.max(0, #state.levels - 1),
	}
	Net.fireClient("LevelUpOffer", player, payload)
end

local function roll(player: Player, state: State, avoid: { [string]: boolean }?): { Types.UpgradeCard }
	local ownedWeapons: { [string]: number } = {}
	for _, weapon in WeaponService.getWeapons(player) do
		ownedWeapons[weapon.id] = weapon.level
	end
	return UpgradePool.roll({
		weapons = WeaponService.getImplemented(),
		passives = passiveIds,
		ownedWeapons = ownedWeapons,
		ownedPassives = state.passives,
		maxWeapons = Config.Player.maxWeapons,
		maxPassives = Config.Player.maxPassives,
		maxLevel = Config.Player.maxItemLevel,
		cardCount = LevelUp.cardCount,
		ownedWeight = LevelUp.ownedItemWeight,
		rewards = REWARDS,
		avoid = avoid,
		random = function(): number
			return rng:NextNumber()
		end,
	})
end

local function openNext(player: Player, state: State)
	if #state.levels == 0 then
		state.offer = nil
		CombatService.setChoosing(player, false)
	else
		state.offer = { cards = roll(player, state, nil), expiresAt = now() + LevelUp.autoPickSeconds }
		CombatService.setChoosing(player, true)
	end
	sendOffer(player, state)
end

local function closeAll(state: State, player: Player)
	table.clear(state.levels)
	if state.offer then
		openNext(player, state)
	end
end

local function pushBonuses(player: Player, state: State)
	local bonuses = UpgradePool.passiveBonuses(state.passives)
	WeaponService.setBonuses(player, bonuses)
	CombatService.setBonuses(player, bonuses)
	ExperienceService.setBonuses(player, bonuses)
end

local function apply(player: Player, state: State, card: Types.UpgradeCard)
	if card.kind == "Weapon" then
		local ok, reason
		if card.isNew then
			ok, reason = WeaponService.addWeapon(player, card.itemId)
		else
			ok, reason = WeaponService.levelUp(player, card.itemId)
		end
		if not ok then -- e.g. a debug button changed the weapons while the cards were open
			warn(`[Lanternfall] Card {card.id} for {player.Name} did nothing: {reason}`)
		end
	elseif card.kind == "Passive" then
		local level = state.passives[card.itemId]
		if not level then
			table.insert(state.passiveOrder, card.itemId)
		end
		state.passives[card.itemId] = math.min((level or 0) + 1, Config.Player.maxItemLevel)
		pushBonuses(player, state)
		sendPassives(player)
	elseif card.itemId == "Heal" then
		local _, maxHp = CombatService.getHp(player)
		CombatService.healPlayer(player, maxHp * LevelUp.maxedOutRewards.healFraction)
	elseif card.itemId == "Embers" then
		state.bonusEmbers += LevelUp.maxedOutRewards.embers
		Net.fireClient("Notify", player, `+{LevelUp.maxedOutRewards.embers} Embers`)
	end
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
			apply(player, state, card)
			openNext(player, state)
			return true
		end
	end
	return false
end

local function onLevelGained(level: number)
	for _, player in RunDirector.getParticipants() do
		local state = states[player]
		if state and RunDirector.getParticipantState(player) ~= "Out" then
			table.insert(state.levels, level)
			if not state.offer then
				openNext(player, state)
			else
				sendOffer(player, state) -- shows the new number of choices waiting
			end
		end
	end
end

local function onRunStarted(participants: { Player })
	table.clear(states)
	for _, player in Players:GetPlayers() do
		if table.find(participants, player) then
			states[player] = newState()
		end
		sendPassives(player) -- empties the passives of players who sat this run out
	end
end

local function autoPick()
	local time = now()
	for player, state in states do
		local offer = state.offer
		if offer and time >= offer.expiresAt and offer.cards[1] then
			choose(player, offer.cards[1].id)
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------

function UpgradeService.init()
	ExperienceService.LevelGained:Connect(onLevelGained)
	RunDirector.RunStarted:Connect(onRunStarted)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Ended" or phase == "Lobby" then
			for player, state in states do
				closeAll(state, player)
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
		Net.fireAllClients("Passives", { userId = player.UserId, passives = {} } :: Types.PassiveLoadout)
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		for _, player in Players:GetPlayers() do
			Net.fireClient("Passives", requester, passiveLoadout(player))
		end
		local state = states[requester]
		if state and state.offer then
			sendOffer(requester, state)
		end
	end)

	Net.onServer("ChooseUpgrade", function(player, cardId: string)
		choose(player, cardId) -- ids the server did not offer are ignored
	end)
	Net.onServer("RequestReroll", function(player)
		local state = states[player]
		local offer = state and state.offer
		if not (state and offer) or state.rerolls <= 0 then
			return
		end
		local avoid: { [string]: boolean } = {}
		for _, card in offer.cards do
			avoid[card.id] = true
		end
		state.rerolls -= 1
		state.offer = { cards = roll(player, state, avoid), expiresAt = now() + LevelUp.autoPickSeconds }
		sendOffer(player, state)
	end)

	RunService.Heartbeat:Connect(autoPick)
end

-- Commands --------------------------------------------------------------------------

-- Gives the player a passive at level 1, or one level more if they have it (chests, debug buttons). False if they
-- are not in the run, their passive slots are full or it is at max level.
function UpgradeService.addPassive(player: Player, passiveId: string): boolean
	local state = states[player]
	if not (state and Config.Passives[passiveId] and WeaponService.isArmed(player)) then
		return false
	end
	local level = state.passives[passiveId]
	if level and level >= Config.Player.maxItemLevel then
		return false
	end
	if not level and #state.passiveOrder >= Config.Player.maxPassives then
		return false
	end
	apply(player, state, {
		id = UpgradePool.cardId("Passive", passiveId),
		kind = "Passive",
		itemId = passiveId,
		level = (level or 0) + 1,
		isNew = level == nil,
	})
	return true
end

-- Turns the weapon into the evolution if the player may take it right now (getEvolutions).
function UpgradeService.evolve(player: Player, evolutionId: string): (boolean, string?)
	if not table.find(UpgradeService.getEvolutions(player), evolutionId) then
		return false, "NotEligible"
	end
	return WeaponService.evolve(player, Config.Evolutions[evolutionId].weapon, evolutionId)
end

-- Queries ---------------------------------------------------------------------------

-- Evolution ids the player may take now: weapon at max level plus the passive (DESIGN.md section 6), sorted.
function UpgradeService.getEvolutions(player: Player): { string }
	local state = states[player]
	if not state then
		return {}
	end
	local owned: { [string]: { level: number, evolution: string? } } = {}
	for _, weapon in WeaponService.getWeapons(player) do
		owned[weapon.id] = { level = weapon.level, evolution = weapon.evolution }
	end
	return UpgradePool.evolutionsFor(owned, state.passives, Config.Player.maxItemLevel)
end

-- The player's passives in the current (or last) run.
function UpgradeService.getPassives(player: Player): { Types.PassiveInfo }
	return passiveLoadout(player).passives
end

-- Embers from maxed-out rewards in the current (or last) run, for the payout in WP13.
function UpgradeService.getBonusEmbers(player: Player): number
	local state = states[player]
	return if state then state.bonusEmbers else 0
end

-- The cards the player can pick right now, or nil.
function UpgradeService.getOffer(player: Player): { Types.UpgradeCard }?
	local state = states[player]
	local offer = state and state.offer
	return if offer then offer.cards else nil
end

return UpgradeService
