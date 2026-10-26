--!strict
-- Debug panel for admins (player attribute "LanternfallAdmin", set by AdminService): one button per
-- debug command, plus a stats panel with the server numbers (DebugStats remote) and the client's own
-- (FPS, EnemyRenderer). Values that break a budget in Config.Simulation turn red. The server checks
-- admin rights again, so this panel is only a convenience.

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
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ADMIN_ATTRIBUTE = "LanternfallAdmin"
local STATS_REFRESH_SECONDS = 0.5

local BUTTON_TEXT: { [string]: string } = {
	SkipMinute = "+1 minute",
	SkipToBoss = `Skip to {Format.time(Config.Run.durationSeconds - Config.Admin.skipToBossLeadSeconds)}`,
	DownSelf = "Knock me down",
	ReviveSelf = "Stand up again",
	WinRun = "Win the run",
	SpawnWave = `Spawn {Config.Admin.spawnWaveCount} enemies`,
	HitNearby = "Hit enemies near me",
	KillEnemies = "Kill all enemies",
	ToggleSpawning = "Pause/resume spawning",
}

local DebugController = {}

local serverStats: Types.DebugStats? = nil
local statsLines: { [string]: TextLabel } = {}
local fps = 0

local function build(): ScreenGui
	local screen = Widgets.screen("Debug", 10)
	local panel = Widgets.panel({
		Name = "Debug",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(200, 0),
		Parent = screen,
	})
	Widgets.list(4).Parent = panel

	local buttons: { TextButton } = {}
	local open = true
	local header: TextButton
	header = Widgets.button({
		Name = "Header",
		Text = "DEBUG (hide)",
		TextSize = 16,
		TextColor3 = Theme.accent,
		Size = UDim2.fromOffset(172, 32),
		LayoutOrder = 0,
		Parent = panel,
	}, function()
		open = not open
		header.Text = if open then "DEBUG (hide)" else "DEBUG"
		for _, button in buttons do
			button.Visible = open
		end
	end)

	for index, command in DebugCommands do
		local button = Widgets.button({
			Name = command,
			Text = BUTTON_TEXT[command] or command,
			TextSize = 15,
			Size = UDim2.fromOffset(172, 32),
			LayoutOrder = index,
			Parent = panel,
		}, function()
			Net.fireServer("DebugCommand", command)
		end)
		table.insert(buttons, button)
	end

	local statsPanel = Widgets.panel({
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(300, 0),
		Parent = screen,
	})
	Widgets.list(2).Parent = statsPanel
	for index, name in { "Enemies", "Spawning", "Server", "Network", "Fps" } do
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
		setLine("Enemies", `Enemies {server.enemies} / {server.cap} · drawn {client.drawn}`, false)
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
	setLine(
		"Network",
		string.format("Enemy data %.1f KB/s", client.receivedKilobytesPerSecond),
		client.receivedKilobytesPerSecond > budget.networkKilobytesPerSecond
	)
	setLine("Fps", string.format("FPS %d", fps), fps < budget.clientFps)
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

	local frames, elapsed = 0, 0
	RunService.RenderStepped:Connect(function(dt: number)
		frames += 1
		elapsed += dt
		if elapsed >= STATS_REFRESH_SECONDS then
			fps = math.round(frames / elapsed)
			frames, elapsed = 0, 0
			if screen and screen.Enabled then
				refreshStats()
			end
		end
	end)
end

return DebugController
