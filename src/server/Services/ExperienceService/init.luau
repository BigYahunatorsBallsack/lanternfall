--!strict
-- Team XP (DESIGN.md sections 8 and 9): killed enemies drop XP orbs (OrbField), living participants pick up every
-- orb within their pickup radius right after each enemy step, and the XP goes to one team level (Progression).
-- Sends TeamProgress to everyone and XpOrbs to the participants, and fires LevelGained, which UpgradeService turns
-- into level-up cards. UpgradeService sets the Magnet bonus with setBonuses; AdminService calls grantLevel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)

local EnemySim = require(script.Parent.EnemySim)
local RunDirector = require(script.Parent.RunDirector)
local SpawnRules = require(script.Parent.SpawnDirector.SpawnRules)
local OrbField = require(script.OrbField)
local Progression = require(script.Progression)

local ExperienceService = {}

-- (level: number): the team reached this level; fired once per level, in order
ExperienceService.LevelGained = Signal.new()

local field = OrbField.new(Config.Run.xpOrbs.maxOrbs)
local progress = Progression.new(Config.Run.xpCurve)
local pickupBonus: { [Player]: number } = {}
local paused = false

-- Changes since the last flush, in the flat Net/Types.XpOrbEvents layout.
local changedOrbs: { number } = {}
local collectedOrbs: { number } = {}
local collectedIds: { number } = {}

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
				local radius = Config.Player.pickupRadius * (1 + (pickupBonus[player] or 0))
				table.clear(collectedIds)
				total += field:collect(position.X, position.Z, radius, collectedIds)
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

-- Lifecycle -------------------------------------------------------------------------

function ExperienceService.init()
	EnemySim.EnemyKilled:Connect(onEnemyKilled)
	EnemySim.Stepped:Connect(onStepped)
	RunDirector.RunStarted:Connect(function()
		table.clear(pickupBonus)
		progress:reset()
		clearOrbs()
		sendProgress()
	end)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Ended" or phase == "Lobby" then
			clearOrbs()
		end
	end)
	RunDirector.ParticipantStateChanged:Connect(sendProgress) -- a player who is out no longer counts
	Players.PlayerRemoving:Connect(function(player)
		pickupBonus[player] = nil
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

-- Bonuses from passives (UpgradeService); only pickupRadius (fraction, Magnet) matters here. Cleared at run start.
function ExperienceService.setBonuses(player: Player, bonuses: { [string]: number })
	pickupBonus[player] = bonuses.pickupRadius or 0
end

-- Gives the team exactly the XP missing for the next level (admin debug command).
function ExperienceService.grantLevel(): boolean
	if not RunDirector.isActive() then
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
