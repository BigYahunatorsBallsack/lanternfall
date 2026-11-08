--!strict
-- Native individual XP: killed enemies drop material orbs, collectors trigger pickup effects, and integer
-- materials/XP rotate across participants. Each recipient has their own XP Gain, threshold and level.
-- Sends TeamProgress to everyone and XpOrbs to the participants, and fires LevelGained, which UpgradeService turns
-- into level-up cards, and OrbsCollected, which ShopService turns into Shards, and OrbsPickedUp for item effects
-- (EffectService). Since B6 like Brotato (Config.Loot, Util/LootRules): from wave 5 normal enemies drop their orb
-- only by chance, and orbs still on the floor when a wave ends go into the team's bag; in the next waves every new orb
-- takes as much again from the bag. Sends OrbBag (what is in the bag) to everyone. StatService sets each player's Pickup Range, XP Gain and Double Orbs
-- (setStats; a doubled orb gives twice its Shards and XP like Brotato's Metal Detector, rolled on RandomService's
-- Loot stream); ShopService adds Harvesting XP with addXp; AdminService calls grantLevel.
-- B11 part 2: a RunDirector checkpoint keeps the team level, XP and bag from the start of each wave ("Retry wave").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local LootRules = require(Shared.Util.LootRules)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)

local DangerService = require(script.Parent.DangerService)
local EnemySim = require(script.Parent.EnemySim)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local OrbField = require(script.OrbField)
local Progression = require(script.Progression)
local CharacterRules = require(script.CharacterRules)

local ExperienceService = {}

-- (level: number, player: Player): this participant reached the level; fired once per level, in order.
ExperienceService.LevelGained = Signal.new()
-- (player: Player, xp: number): XP of the orbs this player picked up, doubled ones twice
ExperienceService.OrbsCollected = Signal.new()
-- (player: Player, orbs: number): how many orbs this player picked up in one step (not the leftovers)
ExperienceService.OrbsPickedUp = Signal.new()

local field = OrbField.new(Config.Run.xpOrbs.maxOrbs)
local progress: { [Player]: Progression.Progression } = {}
local nextMaterialPlayer = 1
local pickupBonus: { [Player]: number } = {} -- Pickup Range as a fraction
local xpBonus: { [Player]: number } = {} -- XP Gain as a fraction
local doubleChance: { [Player]: number } = {} -- Double Orbs as a chance 0..1
local paused = false
local bag = 0 -- XP of the orbs left at the end of earlier waves (B6)
local eaten: { [number]: number } = {} -- enemy id -> XP of the orbs a Gobbler swallowed (B9)
local eaterIds: { number } = {}
local eatenIds: { number } = {}

-- Changes since the last flush, in the flat Net/Types.XpOrbEvents layout.
local changedOrbs: { number } = {}
local collectedOrbs: { number } = {}
local collectedIds: { number } = {}
local collectedValues: { number } = {}

local function requiredMultiplier(player: Player): number
	return CharacterRules.forClass(RunDirector.getParticipantClassId(player)).xpNeededMultiplier
end

local function progressPayload(player: Player): Types.TeamProgress
	local personal = progress[player]
	return {
		level = if personal then personal.level else 0,
		xp = if personal then personal.xp else 0,
		needed = if personal
			then personal:needed(requiredMultiplier(player))
			else Progression.xpForLevel(Config.Run.xpCurve, 0, 1),
	}
end

local function sendProgress()
	for _, player in Players:GetPlayers() do
		Net.fireClient("TeamProgress", player, progressPayload(player))
	end
end

local function sendBag()
	Net.fireAllClients("OrbBag", bag)
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

local function gain(player: Player, amount: number, applyGain: boolean?)
	local personal = progress[player]
	if not personal then
		return
	end
	local before = personal.level
	local gained = personal:add(
		amount * (if applyGain == false then 1 else math.max(0, 1 + (xpBonus[player] or 0))),
		requiredMultiplier(player)
	)
	Net.fireClient("TeamProgress", player, progressPayload(player))
	for level = before + 1, before + gained do
		ExperienceService.LevelGained:Fire(level, player)
	end
end

local function distributeMaterials(value: number)
	local participants = RunDirector.getParticipants()
	if #participants == 0 then
		return
	end
	local shares
	shares, nextMaterialPlayer = CharacterRules.distributeMaterials(value, #participants, nextMaterialPlayer)
	for index, recipient in participants do
		local amount = shares[index]
		if amount > 0 then
			ExperienceService.OrbsCollected:Fire(recipient, amount)
			gain(recipient, amount)
		end
	end
end

local function onEnemyKilled(info: EnemySim.KillInfo)
	local swallowed = eaten[info.id] or 0 -- a Gobbler drops all it ate (B9)
	eaten[info.id] = nil
	if paused or not RunDirector.isActive() or info.xp + swallowed <= 0 then
		return
	end
	local kind = EnemyKinds.get(info.enemyId, info.elite)
	if
		swallowed <= 0
		and kind
		and not LootRules.dropsOrb(
			kind,
			RunDirector.getWave(),
			RandomService.number("Loot"),
			DangerService.orbShare() -- B11: hordes drop fewer
		)
	then
		return
	end
	local value = info.xp + swallowed
	local pulled = LootRules.bagPull(bag, value)
	if pulled > 0 then
		bag -= pulled
		value += pulled
		sendBag()
	end
	local x, z = round(info.position.X), round(info.position.Z)
	local id = field:spawn(x, z, value)
	local orbX, orbZ, orbValue = field:get(id)
	table.insert(changedOrbs, id)
	table.insert(changedOrbs, orbX or x)
	table.insert(changedOrbs, orbZ or z)
	table.insert(changedOrbs, orbValue or value)
end

-- Gobblers (kind.eat, B9) swallow the orbs they touch and walk to the nearest orb within their seek range.
local function feedEaters()
	for e = 1, EnemySim.collectEaters(eaterIds) do
		local id = eaterIds[e]
		local enemyId, elite = EnemySim.getKind(id)
		local kind = enemyId and EnemyKinds.get(enemyId, elite)
		local eat = kind and kind.eat
		local position = EnemySim.getPosition(id)
		if kind and eat and position then
			table.clear(eatenIds)
			local swallowed = field:collect(position.X, position.Z, kind.radius + eat.reach, eatenIds)
			if swallowed > 0 then
				eaten[id] = (eaten[id] or 0) + swallowed
				for _, orbId in eatenIds do
					table.insert(collectedOrbs, orbId)
					table.insert(collectedOrbs, 0) -- no player: the orb just vanishes
				end
			end
			local x, z = field:nearest(position.X, position.Z, eat.seekRange)
			EnemySim.setGoal(id, if x and z then Vector3.new(x, position.Y, z) else nil)
		end
	end
end

local function onStepped()
	if not RunDirector.isActive() then
		return
	end
	if not paused then
		feedEaters()
	end
	if not paused and field:count() > 0 then
		for _, player in RunDirector.getParticipants() do
			local position = EnemySim.getPlayerPosition(player) -- nil while down
			if position then
				local radius = Config.Player.pickupRadius * math.max(0, 1 + (pickupBonus[player] or 0))
				table.clear(collectedIds)
				table.clear(collectedValues)
				field:collect(position.X, position.Z, radius, collectedIds, collectedValues)
				local chance = doubleChance[player] or 0
				if #collectedValues > 0 then
					ExperienceService.OrbsPickedUp:Fire(player, #collectedValues)
				end
				for _, value in collectedValues do
					local doubled = chance > 0 and RandomService.number("Loot", player) < chance
					distributeMaterials(value * (if doubled then 2 else 1))
				end
				for _, id in collectedIds do
					table.insert(collectedOrbs, id)
					table.insert(collectedOrbs, player.UserId)
				end
			end
		end
	end
	flush()
end

-- End of a wave: every orb left goes into the bag (Brotato, since B6).
local function bagLeftovers()
	local total = field:total()
	clearOrbs()
	if total > 0 and not paused then
		bag += total
		sendBag()
	end
end

-- Lifecycle -------------------------------------------------------------------------

function ExperienceService.init()
	EnemySim.EnemyKilled:Connect(onEnemyKilled)
	EnemySim.Stepped:Connect(onStepped)
	RunDirector.RunStarted:Connect(function(participants)
		table.clear(progress)
		for _, player in participants do
			progress[player] = Progression.new(Config.Run.xpCurve)
		end
		nextMaterialPlayer = 1
		clearOrbs()
		table.clear(eaten)
		bag = 0
		sendBag()
		sendProgress()
	end)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Ended" or phase == "Lobby" then
			clearOrbs()
		elseif phase == "Shop" then
			bagLeftovers()
			table.clear(eaten) -- Gobblers alive at the wave end take what they ate with them
		end
	end)
	RunDirector.addCheckpoint(
		"Experience",
		function()
			local players: { [Player]: { level: number, xp: number } } = {}
			for player, personal in progress do
				players[player] = { level = personal.level, xp = personal.xp }
			end
			return { players = players, nextMaterialPlayer = nextMaterialPlayer, bag = bag }
		end,
		function(
			saved: { players: { [Player]: { level: number, xp: number } }, nextMaterialPlayer: number, bag: number }
		)
			for player, data in saved.players do
				local personal = progress[player]
				if personal then
					personal.level, personal.xp = data.level, data.xp
				end
			end
			nextMaterialPlayer = saved.nextMaterialPlayer
			bag = saved.bag
			table.clear(eaten)
			clearOrbs()
			sendBag()
			sendProgress()
		end
	)
	RunDirector.ParticipantStateChanged:Connect(sendProgress) -- a player who is out no longer counts
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
		pickupBonus[player] = nil
		xpBonus[player] = nil
		doubleChance[player] = nil
		task.defer(sendProgress) -- after RunDirector dropped the player from the participants
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		Net.fireClient("TeamProgress", requester, progressPayload(requester))
		Net.fireClient(
			"XpOrbs",
			requester,
			{ reset = true, orbs = field:flatten(), collected = {} } :: Types.XpOrbEvents
		)
		Net.fireClient("OrbBag", requester, bag)
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
function ExperienceService.addXp(amount: number, player: Player?): boolean
	if not RunDirector.isOngoing() or amount <= 0 then
		return false
	end
	if player then
		gain(player, amount)
	else
		-- Explicit administrative team grant; gameplay rewards always supply their individual recipient.
		for recipient in progress do
			gain(recipient, amount)
		end
	end
	return true
end

-- Internal completed-wave payout from ShopService, before results observers. RunFlow may already be Ended;
-- ordinary XP grants still require an ongoing run, and no remote exposes this settlement entry point.
function ExperienceService.addWaveReward(amount: number, player: Player): boolean
	if amount <= 0 or not progress[player] then
		return false
	end
	gain(player, amount)
	return true
end

-- Gives the team exactly the XP missing for the next level (admin debug command).
function ExperienceService.grantLevel(): boolean
	if not RunDirector.isOngoing() then
		return false
	end
	for player, personal in progress do
		gain(player, personal:needed(requiredMultiplier(player)) - personal.xp, false)
	end
	return true
end

-- Tests: while paused, kills drop no orbs and nobody picks any up. Stays until changed, also across runs.
function ExperienceService.setPaused(value: boolean)
	paused = value
end

-- Queries ---------------------------------------------------------------------------

function ExperienceService.getLevel(player: Player?): number
	if player then
		return if progress[player] then progress[player].level else 0
	end
	local highest = 0
	for _, personal in progress do
		highest = math.max(highest, personal.level)
	end
	return highest
end

function ExperienceService.getProgress(player: Player?): Types.TeamProgress
	if player then
		return progressPayload(player)
	end
	-- Legacy report/admin query: the most advanced participant. Clients always receive their own state.
	local leader: Player? = nil
	for candidate, personal in progress do
		if
			not leader
			or personal.level > progress[leader].level
			or (personal.level == progress[leader].level and personal.xp > progress[leader].xp)
		then
			leader = candidate
		end
	end
	return if leader
		then progressPayload(leader)
		else { level = 0, xp = 0, needed = Progression.xpForLevel(Config.Run.xpCurve, 0, 1) }
end

function ExperienceService.getOrbCount(): number
	return field:count()
end

-- XP (and Shards) waiting in the bag for the next waves (B6).
function ExperienceService.getBag(): number
	return bag
end

-- Tests: fills the bag as if orbs worth `amount` had been left at the end of a wave.
function ExperienceService.addToBag(amount: number)
	bag += math.max(0, amount)
	sendBag()
end

return ExperienceService
