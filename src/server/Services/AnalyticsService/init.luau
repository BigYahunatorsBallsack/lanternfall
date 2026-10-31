--!strict
-- Analytics events (Paket 20, DESIGN.md section 18) for Roblox's AnalyticsService (Creator Hub -> Analytics). Server
-- only, nothing comes from clients. Sends:
--   * the onboarding funnel "First start" of players without a finished run (Joined, Moved, FirstKill, FirstLevelUp,
--     Played3Minutes, FirstRunEnded, BackInLobby, SecondRun; order and rules in AnalyticsService/AnalyticsRules),
--   * progression per danger level (wave started, cleared, run lost there),
--   * the Embers economy: run rewards and achievements (PlayerDataService.onRunRecorded), quests and the login streak
--     (QuestService), Ember packs (MonetizationService) as sources, the Ember shop (EmberShopService) as sink,
--   * custom events from Config.Analytics.custom: run end (length, outcome, players), what downed a player, bosses
--     killed, level-up cards offered and picked (UpgradeService.CardPicked), shop buys (ShopService.Bought),
--     revives, "Retry wave", First Night skipped (FirstNightService), movement check corrections (Paket 23).
-- Listens to RunDirector, EnemySim, ExperienceService, MapService, PlayerDataService, ReviveService, ShopService and
-- UpgradeService; those never require this module, the services that report Embers call it. Every call goes through a
-- per-server budget (Config.Analytics.budget) and a pcall. Roblox does not record events from Studio: the last events
-- stay in a log for the debug button "Print analytics log" (AdminService) and the tests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ProgressRules = require(Shared.Util.ProgressRules)
local Types = require(Shared.Net.Types)

local EnemySim = require(script.Parent.EnemySim)
local ExperienceService = require(script.Parent.ExperienceService)
local MapService = require(script.Parent.MapService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ReviveService = require(script.Parent.ReviveService)
local RunDirector = require(script.Parent.RunDirector)
local ShopService = require(script.Parent.ShopService)
local UpgradeService = require(script.Parent.UpgradeService)
local AnalyticsRules = require(script.AnalyticsRules)

local Analytics = Config.Analytics
local LOG_PREFIX = "[Lanternfall] "

export type LogEntry = { method: string, player: string, text: string }

local AnalyticsService = {}

local robloxService: any = nil
local budget = AnalyticsRules.newBudget(os.clock())
local log: { LogEntry } = {}
local dropped = 0
local funnels: { [Player]: AnalyticsRules.Funnel } = {}
local lastPositions: { [Player]: Vector3 } = {}
local walked: { [Player]: number } = {} -- studs walked since joining (onboarding "Moved")
local joinedAt: { [Player]: number } = {}
local lastHits: { [Player]: { kind: string, time: number, enemy: string } } = {}
local completedWave = 0 -- the last wave a progression "Complete" went out for in this run

local function describe(args: { any }): string
	local parts = {}
	for _, value in args do
		if type(value) == "table" then
			local keys = {}
			for key, inner in value do
				table.insert(keys, `{key}={inner}`)
			end
			table.sort(keys)
			table.insert(parts, "{" .. table.concat(keys, ", ") .. "}")
		else
			table.insert(parts, tostring(value))
		end
	end
	return table.concat(parts, " ")
end

-- Sends one event (Roblox method name and its arguments after the player) if the budget allows it.
local function send(method: string, player: Player, priority: string, ...: any)
	if not Analytics.enabled then
		return
	end
	if not AnalyticsRules.take(budget, os.clock(), #Players:GetPlayers(), priority) then
		dropped += 1
		return
	end
	local args = table.pack(...)
	local entry = { method = method, player = player.Name, text = describe({ table.unpack(args, 1, args.n) }) }
	table.insert(log, entry)
	while #log > Analytics.logSize do
		table.remove(log, 1)
	end
	if Analytics.printInStudio and RunService:IsStudio() then
		print(`{LOG_PREFIX}Analytics {method} {entry.player} {entry.text}`)
	end
	if robloxService then
		local ok, err = pcall(robloxService[method], robloxService, player, ...)
		if not ok then
			warn(`{LOG_PREFIX}Analytics {method} failed: {err}`)
		end
	end
end

-- Funnel ------------------------------------------------------------------------------

local function reach(player: Player, step: string)
	local funnel = funnels[player]
	if not funnel then
		return
	end
	for _, entry in AnalyticsRules.reach(funnel, step) do
		send("LogOnboardingFunnelStepEvent", player, "high", entry.step, entry.name)
	end
end

local function reachAll(players: { Player }, step: string)
	for _, player in players do
		reach(player, step)
	end
end

local function hasFinishedFirstRun(player: Player): boolean
	local funnel = funnels[player]
	return funnel ~= nil and funnel.logged >= (AnalyticsRules.stepIndex("FirstRunEnded") or math.huge)
end

local function onLoaded(player: Player, data: any)
	if funnels[player] then
		return
	end
	local start = AnalyticsRules.startStep(data.stats.runs)
	if start == nil then
		return
	end
	funnels[player] = AnalyticsRules.newFunnel(start)
	joinedAt[player] = os.clock()
	reach(player, "Joined")
	if hasFinishedFirstRun(player) and RunDirector.getPhase() == "Lobby" then
		reach(player, "BackInLobby") -- came back to a lobby (the hub) after the first run
	end
end

-- "Moved" and "Played3Minutes", checked every Config.Analytics.onboarding.checkSeconds.
local function checkFunnels()
	local onboarding = Analytics.onboarding
	local now = os.clock()
	for player, funnel in funnels do
		if funnel.logged >= #onboarding.steps then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local last = lastPositions[player]
			lastPositions[player] = root.Position
			local step = if last then (root.Position - last).Magnitude else 0
			if step < onboarding.teleportStuds then -- a bigger step is a teleport (into the arena), not walking
				walked[player] = (walked[player] or 0) + step
			end
			if walked[player] and walked[player] >= onboarding.movedStuds then
				reach(player, "Moved")
			end
		end
		if now - (joinedAt[player] or now) >= onboarding.playedSeconds then
			reach(player, "Played3Minutes")
		end
	end
end

-- Progression and run events -------------------------------------------------------------------

local function pathName(): string
	return AnalyticsRules.pathName(RunDirector.getRunOptions())
end

local function dangerField(): string
	return AnalyticsRules.dangerField(RunDirector.getRunOptions())
end

local function customEvent(player: Player, name: string, value: number?, values: { any }?)
	local definition = Analytics.custom[name]
	assert(definition, `Unknown analytics event {name}`)
	send("LogCustomEvent", player, definition.priority, name, value or 1, AnalyticsRules.fields(values or {}))
end

local function onPhaseChanged(phase: Types.Phase, previous: Types.Phase)
	local wave = RunDirector.getWave()
	if phase == "Running" and previous ~= "Running" then
		completedWave = math.min(completedWave, wave - 1) -- a retried wave can be cleared again
		for _, player in RunDirector.getParticipants() do
			send("LogProgressionStartEvent", player, "high", pathName(), wave, `Wave {wave}`)
		end
	elseif phase == "Shop" and wave > completedWave then
		completedWave = wave
		for _, player in RunDirector.getParticipants() do
			send("LogProgressionCompleteEvent", player, "high", pathName(), wave, `Wave {wave}`)
		end
	elseif phase == "Lobby" or phase == "Countdown" then -- the results are over ("Play again" skips the lobby)
		for player in funnels do
			if hasFinishedFirstRun(player) then
				reach(player, "BackInLobby")
			end
		end
	end
end

local function onRunStarted(participants: { Player })
	completedWave = 0
	for _, player in participants do
		if hasFinishedFirstRun(player) then
			reach(player, "BackInLobby") -- a run that starts without a lobby phase (run place, quick restarts)
			reach(player, "SecondRun")
		end
	end
end

local function onRunEnded(results: Types.Results)
	local wave = results.wave or RunDirector.getWave()
	local path, danger = pathName(), dangerField()
	for _, entry in results.players do
		local player = Players:GetPlayerByUserId(entry.userId)
		if not player then
			continue
		end
		if results.outcome == "Victory" then
			if wave > completedWave then
				send("LogProgressionCompleteEvent", player, "high", path, wave, `Wave {wave}`)
			end
		else
			send("LogProgressionFailEvent", player, "high", path, wave, `Wave {wave}`)
		end
		customEvent(
			player,
			"RunEnded",
			math.floor(results.survivedSeconds),
			{ results.outcome, danger, #results.players }
		)
		reach(player, "FirstRunEnded")
	end
	if results.outcome == "Victory" then
		completedWave = math.max(completedWave, wave)
	end
end

-- The kind of the enemy nearest to the player (Config.Analytics.down.enemyRange), "None" without one.
local function nearestEnemy(player: Player): string
	local position = EnemySim.getPlayerPosition(player)
	local id = position and EnemySim.nearest(position, Analytics.down.enemyRange)
	return (id and EnemySim.getKind(id)) or "None"
end

-- Notes a contact or shot (with the enemy nearest to the player then) for the cause of a "PlayerDown".
local function noteHit(player: Player, kind: string)
	lastHits[player] = { kind = kind, time = os.clock(), enemy = nearestEnemy(player) }
end

-- What downed the player: deferred, so the hit that downed them is already noted (signals run in any order).
local function onParticipantState(player: Player, state: Types.ParticipantState)
	if state ~= "Down" then
		return
	end
	local time = os.clock()
	local wave = RunDirector.getWave()
	task.defer(function()
		local hit = lastHits[player]
		local cause = AnalyticsRules.downCause(hit, time)
		local enemy = if hit and cause ~= "Other" then hit.enemy else nearestEnemy(player)
		customEvent(player, "PlayerDown", nil, { cause, enemy, wave })
	end)
end

local function onEnemyKilled(info: EnemySim.KillInfo)
	if not RunDirector.isActive() then
		return
	end
	if info.killer then
		reach(info.killer, "FirstKill")
	end
	if Config.Enemies.bosses[info.enemyId] or Config.Enemies.champions[info.enemyId] then
		for _, player in RunDirector.getParticipants() do
			customEvent(player, "BossKilled", RunDirector.getWave(), { info.enemyId, dangerField() })
		end
	end
end

local function onCardPicked(player: Player, card: Types.UpgradeCard, offered: { Types.UpgradeCard }, auto: boolean)
	for _, shown in offered do
		customEvent(player, "CardOffered", nil, { shown.stat, shown.tier })
	end
	customEvent(player, "CardPicked", nil, { card.stat, card.tier, if auto then "Auto" else "Player" })
end

-- Embers from a recorded run: the run's own Embers and the achievements it completed (quests report themselves).
local function onRunRecorded(player: Player, data: any, run: any, rewards: Types.RunRewards)
	local runEmbers = ProgressRules.runEmbers({
		seconds = run.seconds,
		champions = run.champions or 0,
		bosses = run.bossKills,
		danger = run.danger,
		players = run.players or 1,
		bonuses = run.bonuses,
	})
	local achievementEmbers = 0
	for _, id in rewards.achievements do
		local achievement = ProgressRules.get(id) :: any
		achievementEmbers += if achievement then achievement.embers else 0
	end
	local balance = data.embers
	if achievementEmbers > 0 then
		send(
			"LogEconomyEvent",
			player,
			"high",
			Enum.AnalyticsEconomyFlowType.Source,
			Analytics.economy.currency,
			achievementEmbers,
			balance,
			Enum.AnalyticsEconomyTransactionType[Analytics.economy.sources.Achievement].Name,
			"Achievement"
		)
	end
	if runEmbers > 0 then
		send(
			"LogEconomyEvent",
			player,
			"high",
			Enum.AnalyticsEconomyFlowType.Source,
			Analytics.economy.currency,
			runEmbers,
			balance - achievementEmbers,
			Enum.AnalyticsEconomyTransactionType[Analytics.economy.sources.RunReward].Name,
			AnalyticsRules.dangerField({ danger = run.danger, endless = false, firstNight = run.firstNight } :: any)
		)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function AnalyticsService.init()
	local ok, service = pcall(function()
		return game:GetService("AnalyticsService")
	end)
	robloxService = if ok then service else nil

	PlayerDataService.Loaded:Connect(onLoaded)
	PlayerDataService.onRunRecorded(onRunRecorded)
	RunDirector.PhaseChanged:Connect(onPhaseChanged)
	RunDirector.RunStarted:Connect(onRunStarted)
	RunDirector.RunEnded:Connect(onRunEnded)
	RunDirector.ParticipantStateChanged:Connect(onParticipantState)
	RunDirector.WaveRetried:Connect(function(wave: number)
		for _, player in RunDirector.getParticipants() do
			customEvent(player, "RetryWave", wave, { wave, dangerField() })
		end
	end)
	EnemySim.EnemyKilled:Connect(onEnemyKilled)
	EnemySim.Contact:Connect(function(player: Player)
		noteHit(player, "Contact")
	end)
	EnemySim.ShotHit:Connect(function(player: Player)
		noteHit(player, "Shot")
	end)
	ExperienceService.LevelGained:Connect(function()
		if RunDirector.isActive() then
			reachAll(RunDirector.getParticipants(), "FirstLevelUp")
		end
	end)
	ReviveService.Revived:Connect(function(reviver: Player)
		customEvent(reviver, "Revived", nil, { RunDirector.getWave() })
	end)
	ShopService.Bought:Connect(function(player: Player, kind: string, itemId: string)
		customEvent(player, "ItemBought", nil, { kind, itemId, RunDirector.getWave() })
	end)
	-- Paket 23: how often the movement check moves someone back (many on fair players = it is too strict)
	MapService.MovementCorrected:Connect(function(player: Player, reason: string, distance: number)
		local studs = if distance == math.huge then 0 else math.floor(distance + 0.5)
		customEvent(player, "MovementCorrected", studs, { reason, RunDirector.getWave() })
	end)
	UpgradeService.CardPicked:Connect(onCardPicked)
	Players.PlayerRemoving:Connect(function(player)
		funnels[player] = nil
		lastPositions[player] = nil
		walked[player] = nil
		joinedAt[player] = nil
		lastHits[player] = nil
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(dt: number)
		sinceCheck += dt
		if sinceCheck >= Analytics.onboarding.checkSeconds then
			sinceCheck = 0
			checkFunnels()
		end
	end)
end

-- Reports --------------------------------------------------------------------------

-- Embers the player got (`source` = key of Config.Analytics.economy.sources). Call after adding them to the data;
-- `sku` names what paid (e.g. the quest kind or the product key).
function AnalyticsService.embersEarned(player: Player, source: string, amount: number, sku: string?)
	local transaction = Analytics.economy.sources[source]
	assert(transaction, `Unknown Ember source {source}`)
	local data = PlayerDataService.get(player)
	if amount <= 0 or not data then
		return
	end
	send(
		"LogEconomyEvent",
		player,
		"high",
		Enum.AnalyticsEconomyFlowType.Source,
		Analytics.economy.currency,
		amount,
		data.embers,
		Enum.AnalyticsEconomyTransactionType[transaction].Name,
		sku or source
	)
end

-- Embers the player spent (`sink` = key of Config.Analytics.economy.sinks). Call after taking them from the data.
function AnalyticsService.embersSpent(player: Player, sink: string, amount: number, sku: string)
	local transaction = Analytics.economy.sinks[sink]
	assert(transaction, `Unknown Ember sink {sink}`)
	local data = PlayerDataService.get(player)
	if amount <= 0 or not data then
		return
	end
	send(
		"LogEconomyEvent",
		player,
		"high",
		Enum.AnalyticsEconomyFlowType.Sink,
		Analytics.economy.currency,
		amount,
		data.embers,
		Enum.AnalyticsEconomyTransactionType[transaction].Name,
		sku
	)
end

-- A custom event from Config.Analytics.custom with its value and fields (in the config's order).
function AnalyticsService.custom(player: Player, name: string, value: number?, values: { any }?)
	customEvent(player, name, value, values)
end

-- The last events (oldest first) and how many the budget dropped, for the debug button and the tests.
function AnalyticsService.getLog(): ({ LogEntry }, number)
	return table.clone(log), dropped
end

-- Tests: forget the log.
function AnalyticsService.clearLog()
	table.clear(log)
	dropped = 0
end

return AnalyticsService
