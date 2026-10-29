--!strict
-- Team XP (DESIGN.md sections 8 and 9): killed enemies drop XP orbs (OrbField), living participants pick up every
-- orb within their pickup radius right after each enemy step, and the XP goes to one team level (Progression).
-- Sends TeamProgress to everyone and XpOrbs to the participants, and fires LevelGained, which UpgradeService turns
-- into level-up cards, and OrbsCollected, which ShopService turns into Shards, and OrbsPickedUp for item effects
-- (EffectService). Orbs still on the floor when a wave ends are collected for the team (XP) and split evenly between
-- the participants who are not out (Shards). StatService sets each player's Pickup Range, XP Gain and Double Orbs
-- (setStats; a doubled orb gives twice its Shards and XP like Brotato's Metal Detector, rolled on RandomService's
-- Loot stream); ShopService adds Harvesting XP with addXp; AdminService calls grantLevel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)

local EnemySim = require(script.Parent.EnemySim)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local SpawnRules = require(script.Parent.SpawnDirector.SpawnRules)
local OrbField = require(script.OrbField)
local Progression = require(script.Progression)

local ExperienceService = {}

-- (level: number): the team reached this level; fired once per level, in order
ExperienceService.LevelGained = Signal.new()
-- (player: Player, xp: number): XP of the orbs this player picked up, doubled ones twice (or their share of the
-- leftovers at wave end)
ExperienceService.OrbsCollected = Signal.new()
-- (player: Player, orbs: number): how many orbs this player picked up in one step (not the leftovers)
ExperienceService.OrbsPickedUp = Signal.new()

local field = OrbField.new(Config.Run.xpOrbs.maxOrbs)
local progress = Progression.new(Config.Run.xpCurve)
local pickupBonus: { [Player]: number } = {} -- Pickup Range as a fraction
local xpBonus: { [Player]: number } = {} -- XP Gain as a fraction
local doubleChance: { [Player]: number } = {} -- Double Orbs as a chance 0..1
local paused = false

-- Changes since the last flush, in the flat Net/Types.XpOrbEvents layout.
local changedOrbs: { number } = {}
local collectedOrbs: { number } = {}
local collectedIds: { number } = {}
local collectedValues: { number } = {}

local function playerFactor(): number
	return SpawnRules.playerFactor(#RunDirector.getParticipants())
end

local function progressPayload(): Types.TeamProgress
	return { level = progress.level, xp = progress.xp, needed = progress:needed(playerFactor()) }
end

local function sendProgress()
	Net.fireAllClients("TeamProgress", progressPayload())
end

local function round(value: number): number
	return math.round(value * 10) / 10
end

local function flush()
	if #changedOrbs == 0 and #collectedOrbs == 0 then
		return
	end
	local events: Types.XpOrbEvents = { orbs = changedOrbs, collected = collectedOrbs }
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("XpOrbs", player, events)
	end
	changedOrbs = {}
	collectedOrbs = {}
end

-- Drops every orb on every client and starts the team at level 1 (run start) or keeps the level (run end).
local function clearOrbs()
	field:clear()
	changedOrbs = {}
	collectedOrbs = {}
	Net.fireAllClients("XpOrbs", { reset = true, orbs = {}, collected = {} } :: Types.XpOrbEvents)
end

local function gain(amount: number)
	local before = progress.level
	local gained = progress:add(amount, playerFactor())
	sendProgress()
	for level = before + 1, before + gained do
		ExperienceService.LevelGained:Fire(level)
	end
end

local function onEnemyKilled(info: EnemySim.KillInfo)
	if paused or not RunDirector.isActive() or info.xp <= 0 then
		return
	end
	local x, z = round(info.position.X), round(info.position.Z)
	local id = field:spawn(x, z, info.xp)
	local orbX, orbZ, value = field:get(id)
	table.insert(changedOrbs, id)
	table.insert(changedOrbs, orbX or x)
	table.insert(changedOrbs, orbZ or z)
	table.insert(changedOrbs, value or info.xp)
end

local function onStepped()
	if not RunDirector.isActive() then
		return
	end
	if not paused and field:count() > 0 then
		local total = 0
		for _, player in RunDirector.getParticipants() do
			local position = EnemySim.getPlayerPosition(player) -- nil while down
			if position then
				local radius = Config.Player.pickupRadius * math.max(0, 1 + (pickupBonus[player] or 0))
				table.clear(collectedIds)
				table.clear(collectedValues)
				local collected = field:collect(position.X, position.Z, radius, collectedIds, collectedValues)
				local chance = doubleChance[player] or 0
				if chance > 0 then
					local random = RandomService.stream("Loot", player)
					for _, value in collectedValues do
						if random:NextNumber() < chance then
							collected += value
						end
					end
				end
				total += collected * math.max(0, 1 + (xpBonus[player] or 0))
				if collected > 0 then
					ExperienceService.OrbsCollected:Fire(player, collected)
					ExperienceService.OrbsPickedUp:Fire(player, #collectedValues)
				end
				for _, id in collectedIds do
					table.insert(collectedOrbs, id)
					table.insert(collectedOrbs, player.UserId)
				end
			end
		end
		if total > 0 then
			gain(total)
		end
	end
	flush()
end

-- End of a wave: every orb left goes to the team, its Shards are split between the participants who are not out.
local function collectLeftovers()
	local total = field:total()
	clearOrbs()
	if total <= 0 or paused then
		return
	end
	local sharers = {}
	for _, player in RunDirector.getParticipants() do
		if RunDirector.getParticipantState(player) ~= "Out" then
			table.insert(sharers, player)
		end
	end
	for _, player in sharers do
		ExperienceService.OrbsCollected:Fire(player, total / #sharers)
	end
	gain(total)
end

-- Lifecycle -------------------------------------------------------------------------

function ExperienceService.init()
	EnemySim.EnemyKilled:Connect(onEnemyKilled)
	EnemySim.Stepped:Connect(onStepped)
	RunDirector.RunStarted:Connect(function()
		progress:reset()
		clearOrbs()
		sendProgress()
	end)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Ended" or phase == "Lobby" then
			clearOrbs()
		elseif phase == "Shop" then
			collectLeftovers()
		end
	end)
	RunDirector.ParticipantStateChanged:Connect(sendProgress) -- a player who is out no longer counts
	Players.PlayerRemoving:Connect(function(player)
		pickupBonus[player] = nil
		xpBonus[player] = nil
		doubleChance[player] = nil
		task.defer(sendProgress) -- after RunDirector dropped the player from the participants
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		Net.fireClient("TeamProgress", requester, progressPayload())
		Net.fireClient(
			"XpOrbs",
			requester,
			{ reset = true, orbs = field:flatten(), collected = {} } :: Types.XpOrbEvents
		)
	end)
end

-- Commands --------------------------------------------------------------------------

-- The player's stats (StatService): Pickup Range widens their pickup radius, XP Gain adds to the XP of the orbs they
-- pick up (not to their Shards), Double Orbs is the chance an orb they pick up counts twice (Shards and XP).
function ExperienceService.setStats(player: Player, stats: { [string]: number })
	pickupBonus[player] = (stats.pickupRange or 0) / 100
	xpBonus[player] = (stats.xpGain or 0) / 100
	doubleChance[player] = math.clamp((stats.doubleShards or 0) / 100, 0, 1)
end

-- Adds XP to the team while a run is going on (Harvesting at the end of a wave). False otherwise.
function ExperienceService.addXp(amount: number): boolean
	if not RunDirector.isOngoing() or amount <= 0 then
		return false
	end
	gain(amount)
	return true
end

-- Gives the team exactly the XP missing for the next level (admin debug command).
function ExperienceService.grantLevel(): boolean
	if not RunDirector.isOngoing() then
		return false
	end
	gain(progress:needed(playerFactor()) - progress.xp)
	return true
end

-- Tests: while paused, kills drop no orbs and nobody picks any up. Stays until changed, also across runs.
function ExperienceService.setPaused(value: boolean)
	paused = value
end

-- Queries ---------------------------------------------------------------------------

function ExperienceService.getLevel(): number
	return progress.level
end

function ExperienceService.getProgress(): Types.TeamProgress
	return progressPayload()
end

function ExperienceService.getOrbCount(): number
	return field:count()
end

return ExperienceService
