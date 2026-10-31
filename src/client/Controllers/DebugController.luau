--!strict
-- Debug panel for admins (player attribute "LanternfallAdmin", set by AdminService): one button per
-- debug command, plus a stats panel with the server numbers (DebugStats remote) and the client's own
-- (FPS, EnemyRenderer). Values that break a budget in Config.Simulation turn red. The server checks
-- admin rights again, so this panel is only a convenience. Since Paket 22 the panel also shows the frame time (average
-- and worst), all data this client receives (Roblox's Stats service), memory, instances, enemies off the screen and the
-- graphics level (GraphicsController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DebugCommands = require(Shared:WaitForChild("Net"):WaitForChild("DebugCommands"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local EnemyRenderer = require(script.Parent.EnemyRenderer)
local GraphicsController = require(script.Parent.GraphicsController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ADMIN_ATTRIBUTE = "LanternfallAdmin"
local STATS_REFRESH_SECONDS = 0.5

local BUTTON_TEXT: { [string]: string } = {
	SkipWave = "End this wave",
	HoldWaves = "Stop/run wave timer",
	AddShards = `+{Config.Admin.addShards} Shards`,
	SkipToBoss = `Skip to {Format.time(Config.Run.durationSeconds - Config.Admin.skipToBossLeadSeconds)}`,
	DownSelf = "Knock me down",
	ReviveSelf = "Stand up again",
	HurtSelf = `Hurt me ({Config.Admin.hurtSelfDamage})`,
	HealSelf = "Heal me",
	WinRun = "Win the run",
	SpawnWave = `Spawn {Config.Admin.spawnWaveCount} enemies`,
	SpawnElite = "Spawn an elite",
	HitNearby = "Hit enemies near me",
	KillEnemies = "Kill all enemies",
	ToggleSpawning = "Pause/resume spawning",
	AddWeapon = "Add a weapon",
	NextWeapon = "Only the next weapon",
	TierUpWeapons = "Weapons +1 tier",
	EvolveWeapons = "Evolve weapons",
	ToggleWeapons = "Weapons on/off",
	GainLevel = "Team +1 level",
	AddEffectItem = "Next effect item",
	AddCombatItem = "Next combat item",
	SpawnLooter = "Spawn a looter",
	SpawnTree = "Spawn a tree",
	DropCrate = "Drop a crate",
	AddNewItem = "Next new item",
	SpawnNewEnemy = "Spawn next new enemy",
	SpawnBoss = "Spawn next boss",
	HurtBoss = `Boss -{math.round(Config.Admin.hurtBossShare * 100)}% HP`,
	DropLegendaryCrate = "Legendary crate",
	SpawnChampion = "Spawn next champion",
	PrintProfile = "Print my saved data",
	ResetProfile = "Reset my saved data",
	UnlockAll = "Unlock everything",
	FakePurchase = "Fake purchase: next product",
	ToggleFakePasses = "Fake passes on/off",
	AddEmbers = `+{Config.Admin.addEmbers} Embers`,
	NextDay = "Next day (quests)",
	StartFirstNight = "Start First Night",
	PrintAnalytics = "Print analytics log",
}

local BUTTON_SIZE = Vector2.new(150, 30)
local BUTTON_GAP = 4

local DebugController = {}

local serverStats: Types.DebugStats? = nil
local statsLines: { [string]: TextLabel } = {}
local fps = 0
local worstFrameMilliseconds = 0

-- Roblox's Stats service (network, memory); missing in the test runner.
local robloxStats: any = nil
do
	local ok, service = pcall(function()
		return game:GetService("Stats")
	end)
	robloxStats = if ok then service else nil
end

-- Reads a number from the Stats service, nil where it cannot.
local function readStat(read: (any) -> number): number?
	if not robloxStats then
		return nil
	end
	local ok, value = pcall(read, robloxStats)
	return if ok and type(value) == "number" then value else nil
end

local function build(): ScreenGui
	local screen = Widgets.screen("Debug", 10)
	-- Two columns of buttons, so the panel stays clear of the team list above it.
	local gridWidth = 2 * BUTTON_SIZE.X + BUTTON_GAP
	local panel = Widgets.panel({
		Name = "Debug",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(gridWidth + 28, 0),
		Parent = screen,
	})
	Widgets.list(BUTTON_GAP).Parent = panel

	local grid = Widgets.create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(gridWidth, 0),
		LayoutOrder = 1,
		Parent = panel,
	})
	Widgets.create("UIGridLayout", {
		CellSize = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
		CellPadding = UDim2.fromOffset(BUTTON_GAP, BUTTON_GAP),
		FillDirectionMaxCells = 2,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local open = true
	local header: TextButton
	header = Widgets.button({
		Name = "Header",
		Text = "DEBUG (hide)",
		TextSize = 16,
		TextColor3 = Theme.accent,
		Size = UDim2.fromOffset(gridWidth, BUTTON_SIZE.Y),
		LayoutOrder = 0,
		Parent = panel,
	}, function()
		open = not open
		header.Text = if open then "DEBUG (hide)" else "DEBUG"
		grid.Visible = open
	end)

	for index, command in DebugCommands do
		Widgets.button({
			Name = command,
			Text = BUTTON_TEXT[command] or command,
			TextSize = 14,
			LayoutOrder = index,
			Parent = grid,
		}, function()
			Net.fireServer("DebugCommand", command)
		end)
	end

	local statsPanel = Widgets.panel({
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(400, 0),
		Parent = screen,
	})
	Widgets.list(2).Parent = statsPanel
	for index, name in { "Enemies", "Spawning", "Server", "Network", "Fps", "Memory", "Graphics" } do
		statsLines[name] = Widgets.label({
			Name = name,
			Text = "",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = index,
			Parent = statsPanel,
		})
	end
	return screen
end

local function setLine(name: string, text: string, overBudget: boolean)
	local label = statsLines[name]
	if label then
		label.Text = text
		label.TextColor3 = if overBudget then Theme.danger else Theme.text
	end
end

local function refreshStats()
	local budget = Config.Simulation.budget
	local client = EnemyRenderer.getStats()
	local server = serverStats
	if server then
		setLine(
			"Enemies",
			`Enemies {server.enemies} / {server.cap} · drawn {client.drawn} ({client.culled} off screen) · shots {server.shots}`,
			false
		)
		setLine(
			"Spawning",
			if server.paused
				then "Spawning paused"
				elseif server.spawning then string.format("Spawning %.1f per second", server.spawnRate)
				else "Spawning off",
			server.paused
		)
		setLine(
			"Server",
			string.format(
				"Server step %.2f ms (max %.2f), %d/s",
				server.stepMilliseconds,
				server.stepMaxMilliseconds,
				math.round(server.stepsPerSecond)
			),
			server.stepMaxMilliseconds > budget.stepMilliseconds
		)
	else
		setLine("Enemies", `Enemies ? · drawn {client.drawn}`, false)
		setLine("Spawning", "Waiting for server stats", false)
		setLine("Server", "", false)
	end
	local received = readStat(function(service)
		return service.DataReceiveKbps
	end)
	if received then
		setLine(
			"Network",
			string.format("Data in %.1f KB/s (enemies %.1f)", received, client.receivedKilobytesPerSecond),
			received > budget.networkKilobytesPerSecond
		)
	else
		setLine(
			"Network",
			string.format("Enemy data %.1f KB/s", client.receivedKilobytesPerSecond),
			client.receivedKilobytesPerSecond > budget.networkKilobytesPerSecond
		)
	end
	local frameMilliseconds = if fps > 0 then 1000 / fps else 0
	setLine(
		"Fps",
		string.format("FPS %d · frame %.1f ms (worst %.1f)", fps, frameMilliseconds, worstFrameMilliseconds),
		fps < budget.clientFps
	)
	local memory = readStat(function(service)
		return service:GetTotalMemoryUsageMb()
	end)
	local instances = readStat(function(service)
		return service.InstanceCount
	end)
	setLine(
		"Memory",
		string.format(
			"Memory %s MB · instances %s",
			if memory then tostring(math.round(memory)) else "?",
			if instances then tostring(instances) else "?"
		),
		memory ~= nil and memory > budget.clientMemoryMegabytes
	)
	local level, reason = GraphicsController.getLevel()
	setLine("Graphics", `Graphics {level} ({reason})`, false)
end

function DebugController.init()
	Net.onClient("DebugStats", function(stats: Types.DebugStats)
		serverStats = stats
	end)
end

function DebugController.start()
	local player = Players.LocalPlayer
	local screen: ScreenGui? = nil
	local function update()
		local isAdmin = player:GetAttribute(ADMIN_ATTRIBUTE) == true
		if isAdmin and not screen then
			screen = build()
		end
		if screen then
			screen.Enabled = isAdmin
		end
	end
	player:GetAttributeChangedSignal(ADMIN_ATTRIBUTE):Connect(update)
	update()

	local frames, elapsed, worst = 0, 0, 0
	RunService.RenderStepped:Connect(function(dt: number)
		frames += 1
		elapsed += dt
		worst = math.max(worst, dt)
		if elapsed >= STATS_REFRESH_SECONDS then
			fps = math.round(frames / elapsed)
			worstFrameMilliseconds = worst * 1000
			frames, elapsed, worst = 0, 0, 0
			if screen and screen.Enabled then
				refreshStats()
			end
		end
	end)
end

return DebugController
