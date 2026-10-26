-- End-to-end smoke test: real server and client bootstraps in a simulated Roblox (tests/helpers/RobloxMock).
-- Catches crashes, wrong module paths, broken remote payloads and flow bugs. Look and feel: Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local RunDirector = require(ServerScriptService.Server.Services.RunDirector)
local MapService = require(ServerScriptService.Server.Services.MapService)
local EnemySim = require(ServerScriptService.Server.Services.EnemySim)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local function phase()
	return RunDirector.getPhase()
end

local function inZone(player, zone)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and MapService.isInZone(root.Position, zone)
end

local function firstText(screenName, objectName)
	local object = world.gui(screenName, objectName)
	assert(object, `{screenName}/{objectName} not found`)
	return object:FindFirstChildOfClass("TextLabel").Text
end

local function enemyRenderer()
	return require(folderProxy("src/client", "Client").Controllers.EnemyRenderer)
end

-- Enemy models the client currently shows (released models are unparented).
local function drawnModels()
	local folder = workspace:FindFirstChild("LanternfallEnemies")
	return if folder then folder:GetChildren() else {}
end

local function toastTexts()
	local texts = {}
	for _, object in world.gui("Notify"):GetDescendants() do
		if object.ClassName == "TextLabel" then
			table.insert(texts, object.Text)
		end
	end
	return table.concat(texts, " | ")
end

local function teamText()
	local rows = world.gui("HUD", "Rows")
	local lines = {}
	for _, row in rows:GetChildren() do
		if row.ClassName == "TextLabel" then
			table.insert(lines, row.Text)
		end
	end
	return table.concat(lines, " | ")
end

describe("smoke", function()
	it("boots server and client without errors", function()
		expect(#world.errors).toBe(0)
		expect(world.gui("Lobby").Enabled).toBe(true)
		expect(world.gui("HUD").Enabled).toBe(false)
		expect(world.gui("Results").Enabled).toBe(false)
		expect(world.gui("Debug").Enabled).toBe(true)
		expect(firstText("Lobby", "Status")).toBe("Pick a class and press READY")
	end)

	it("builds the map and spawns the player in the lobby", function()
		expect(workspace:FindFirstChild("LanternfallMap") ~= nil).toBe(true)
		expect(inZone(me, "Lobby")).toBe(true)
	end)

	it("switches class from the lobby", function()
		world.click(world.gui("Lobby", "SparkMage"))
		world.advance(0.5)
		expect(world.gui("Lobby", "SparkMage").BackgroundColor3 == world.gui("Lobby", "Ready").TextColor3).toBe(false)
		local rows = world.gui("Lobby", "Rows"):GetChildren()
		local found = false
		for _, row in rows do
			if row.ClassName == "TextLabel" and string.find(row.Text, "Spark Mage", 1, true) then
				found = true
			end
		end
		expect(found).toBe(true)
	end)

	it("starts a run after READY", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(0.2)
		expect(phase()).toBe("Countdown")
		expect(string.find(firstText("Lobby", "Status"), "Run starts in", 1, true) ~= nil).toBe(true)
		world.advance(3.2)
		expect(phase()).toBe("Running")
		expect(world.gui("HUD").Enabled).toBe(true)
		expect(world.gui("Lobby").Enabled).toBe(false)
		expect(inZone(me, "Arena")).toBe(true)
	end)

	it("counts the run timer up", function()
		world.advance(5)
		expect(firstText("HUD", "Timer")).toBe("00:05")
		expect(teamText()).toBe("Owner · alive")
	end)

	it("spawns enemies on a ring around the player and draws them", function()
		expect(EnemySim.getCount() >= 5).toBe(true)
		local root = me.Character.HumanoidRootPart.Position
		for _, enemyId in { 1, 2, 3 } do
			local position = EnemySim.getPosition(enemyId)
			local distance = (position - root).Magnitude
			-- spawned 45-60 studs away and walked towards the player since
			expect(position.Y).toBe(Config.Map.arena.center.Y)
			expect(distance < Config.Run.spawn.ringMax + 1).toBe(true)
		end
		world.advance(0.5)
		local models = drawnModels()
		expect(#models).toBe(enemyRenderer().getStats().drawn)
		expect(#models >= EnemySim.getCount() - 2 and #models <= EnemySim.getCount()).toBe(true)
		for _, model in models do
			expect(model.Name).toBe("Shadeling") -- only Shadelings before minute 2
			expect(
				math.abs(model.Body.Position.Y - Config.Map.arena.center.Y - Config.Enemies.types.Shadeling.radius) < 1
			).toBe(true)
		end
		expect(world.bulkMoves > 0).toBe(true)
	end)

	it("chases the player until it touches them", function()
		local contacts = 0
		local connection = EnemySim.Contact:Connect(function(player, damage)
			expect(player).toBe(me)
			expect(damage).toBe(Config.Enemies.types.Shadeling.contactDamage)
			contacts += 1
		end)
		world.advance(5)
		connection:Disconnect()
		expect(contacts > 0).toBe(true)
		local root = me.Character.HumanoidRootPart.Position
		local id, distance = EnemySim.nearest(root)
		expect(id ~= nil).toBe(true)
		expect(distance).toBeNear(Config.Enemies.types.Shadeling.radius + Config.Simulation.playerRadius, 0.6)
	end)

	it("hits and kills enemies with the debug buttons", function()
		local kills = 0
		local connection = EnemySim.EnemyKilled:Connect(function(info)
			expect(info.killer).toBe(me)
			expect(info.xp).toBe(Config.Enemies.types.Shadeling.xp)
			kills += 1
		end)
		local before = EnemySim.getCount()
		world.click(world.gui("Debug", "HitNearby"))
		world.advance(0.2)
		expect(string.find(toastTexts(), "Hit ", 1, true) ~= nil).toBe(true)
		expect(kills).toBe(0) -- a Shadeling survives one hit
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.5)
		connection:Disconnect()
		expect(kills >= before).toBe(true)
		expect(EnemySim.getCount() <= 1).toBe(true) -- one may have spawned since
		expect(#drawnModels() <= 1).toBe(true)
	end)

	it("pauses spawning and spawns a test wave up to the cap", function()
		world.click(world.gui("Debug", "ToggleSpawning"))
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(3)
		expect(EnemySim.getCount()).toBe(0)
		world.click(world.gui("Debug", "SpawnWave"))
		world.click(world.gui("Debug", "SpawnWave"))
		world.click(world.gui("Debug", "SpawnWave"))
		world.advance(0.5)
		expect(EnemySim.getCount()).toBe(Config.Run.spawn.cap.base)
		expect(#drawnModels()).toBe(Config.Run.spawn.cap.base)
		expect(string.find(toastTexts(), "The enemy limit is reached", 1, true) ~= nil).toBe(true)
		world.click(world.gui("Debug", "ToggleSpawning"))
		world.advance(0.2)
	end)

	it("shows enemy and performance numbers to admins", function()
		world.advance(1.2)
		local stats = world.gui("Debug", "Stats")
		expect(stats ~= nil).toBe(true)
		expect(stats.Enemies.Text).toBe(
			`Enemies {Config.Run.spawn.cap.base} / {Config.Run.spawn.cap.base} · drawn {Config.Run.spawn.cap.base}`
		)
		expect(string.find(stats.Server.Text, "Server step", 1, true) ~= nil).toBe(true)
		expect(string.find(stats.Network.Text, "KB/s", 1, true) ~= nil).toBe(true)
	end)

	it("puts a respawned participant back into the arena", function()
		world.spawnCharacter(me)
		world.advance(0.5)
		expect(inZone(me, "Arena")).toBe(true)
	end)

	it("skips to the boss phase, which counts as a victory for now", function()
		world.click(world.gui("Debug", "SkipToBoss"))
		world.advance(0.2)
		expect(RunDirector.getElapsed() >= 710).toBe(true)
		expect(phase()).toBe("Running")
		world.advance(10.5)
		expect(phase()).toBe("Ended")
		expect(world.gui("Results").Enabled).toBe(true)
		expect(world.gui("HUD").Enabled).toBe(false)
		expect(firstText("Results", "Results")).toBe("VICTORY")
		world.advance(0.2)
		expect(EnemySim.getCount()).toBe(0)
		expect(#drawnModels()).toBe(0)
	end)

	it("starts the next run with Play again", function()
		world.click(world.gui("Results", "PlayAgain"))
		world.advance(0.2)
		expect(phase()).toBe("Countdown")
		expect(inZone(me, "Lobby")).toBe(true)
		world.advance(3.2)
		expect(phase()).toBe("Running")
		expect(RunDirector.getElapsed() < 1).toBe(true)
	end)

	it("ends in defeat when the only player is knocked down", function()
		world.click(world.gui("Debug", "DownSelf"))
		world.advance(0.2)
		expect(phase()).toBe("Ended")
		expect(firstText("Results", "Results")).toBe("DEFEAT")
	end)

	it("returns to the lobby after the results", function()
		world.advance(15.5)
		expect(phase()).toBe("Lobby")
		expect(world.gui("Lobby").Enabled).toBe(true)
		expect(world.gui("Results").Enabled).toBe(false)
		expect(inZone(me, "Lobby")).toBe(true)
	end)

	local friend, late
	it("runs with two players and keeps late joiners in the lobby", function()
		friend = world.addPlayer("Friend", 2, false)
		world.advance(0.5)
		world.click(world.gui("Lobby", "Ready"))
		world.advance(1)
		expect(phase()).toBe("Countdown")
		-- friend is not ready yet, so the long countdown runs
		world.advance(3)
		expect(phase()).toBe("Countdown")
		world.fireServerAs(friend, "SelectClass", "SparkMage")
		world.fireServerAs(friend, "SetReady", true)
		world.advance(3.2)
		expect(phase()).toBe("Running")
		expect(#RunDirector.getParticipants()).toBe(2)
		expect(inZone(friend, "Arena")).toBe(true)

		late = world.addPlayer("Late", 3, false)
		world.advance(0.5)
		expect(inZone(late, "Lobby")).toBe(true)
		expect(RunDirector.getParticipantState(late)).toBe(nil)
	end)

	it("keeps running while one of two is down, and enemies go for the one still standing", function()
		world.click(world.gui("Debug", "DownSelf"))
		world.advance(0.2)
		expect(phase()).toBe("Running")
		expect(teamText()).toBe("Owner · DOWN | Friend · alive")
		world.advance(8)
		local friendRoot = friend.Character.HumanoidRootPart.Position
		local _, distance = EnemySim.nearest(friendRoot)
		expect(distance < 5).toBe(true)
		world.click(world.gui("Debug", "ReviveSelf"))
		world.advance(0.2)
		expect(teamText()).toBe("Owner · alive | Friend · alive")
	end)

	it("ends when the last alive player leaves", function()
		world.click(world.gui("Debug", "DownSelf"))
		world.advance(0.2)
		world.removePlayer(friend)
		world.advance(0.2)
		expect(phase()).toBe("Ended")
		expect(firstText("Results", "Results")).toBe("DEFEAT")
	end)

	it("rejects locked classes with a message", function()
		local RunStateController = require(folderProxy("src/client", "Client").Controllers.RunStateController)
		world.fireServerAs(late, "SelectClass", "Trapper")
		world.fireServerAs(me, "SelectClass", "Trapper")
		world.advance(0.2)
		expect(RunStateController.getPlayer(3).classId).toBe("BladeWarden")
		local toasts = {}
		for _, object in world.gui("Notify"):GetDescendants() do
			if object.ClassName == "TextLabel" then
				table.insert(toasts, object.Text)
			end
		end
		expect(table.find(toasts, "This class is not unlocked yet") ~= nil).toBe(true)
	end)

	it("finished without any runtime error", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n\n"))
		end
	end)
end)
