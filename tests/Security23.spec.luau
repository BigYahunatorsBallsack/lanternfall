-- End-to-end test of Paket 23 (security review): the movement check in the arena (speed hack, teleport, through the
-- wall, into a ruin pillar, cheated velocity; the lobby stays unchecked; analytics and the debug button), runs changed
-- by debug commands stay off the leaderboards, server -> client remotes fired at the server are dropped, and broken
-- numbers fail validation. Real server bootstrap in a simulated Roblox (tests/helpers/RobloxMock), leaderboard scores
-- in memory. The check is off in Studio (the mock is Studio), so the spec turns it on like the debug button does.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local LeaderboardRules = require(ReplicatedStorage.Shared.Util.LeaderboardRules)
local Validate = require(ReplicatedStorage.Shared.Net.Validate)
local LeaderboardService = require(Services.LeaderboardService)
local Scores = require(Services.LeaderboardService.Scores)

local scores = Scores.memory()
LeaderboardService.useBackend(scores)

runScript(ServerScriptService.Server, "init.server.luau")
local AnalyticsService = require(Services.AnalyticsService)
local MapService = require(Services.MapService)
local RunDirector = require(Services.RunDirector)
local RunStatsService = require(Services.RunStatsService)
local SpawnDirector = require(Services.SpawnDirector)
local WeaponService = require(Services.WeaponService)

local me = world.addPlayer("Owner", 1, true)
world.step()
world.advance(0.5)

local Movement = Config.Security.movement
local week = LeaderboardRules.week(os.time())

local function root()
	return me.Character.HumanoidRootPart
end

local function walkSpeed(): number
	return me.Character.Humanoid.WalkSpeed -- the character's own speed (the Speed stat of the character counts)
end

local function moveBy(dx: number, dz: number)
	local part = root()
	part.Position = part.Position + Vector3.new(dx, 0, dz)
end

local function startRun()
	world.fireServerAs(me, "SetReady", true)
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	expect(RunDirector.getPhase()).toBe("Running")
	world.advance(1.5) -- placed in the arena, past the settle time
end

local function quiet()
	SpawnDirector.setPaused(true)
	WeaponService.setPaused(true)
	RunDirector.setHoldWaves(true)
end

local function loud()
	SpawnDirector.setPaused(false)
	WeaponService.setPaused(false)
	RunDirector.setHoldWaves(false)
end

local function backToLobby()
	world.advance(Config.Run.flow.resultsSeconds + 1)
	expect(RunDirector.getPhase()).toBe("Lobby")
	world.advance(0.5)
end

local reasons: { string } = {}
MapService.MovementCorrected:Connect(function(_player, reason: string)
	table.insert(reasons, reason)
end)

local function corrections(): number
	local count = 0
	for _, entry in AnalyticsService.getLog() do
		if string.find(entry.text, "MovementCorrected", 1, true) then
			count += 1
		end
	end
	return count
end

local function waveScore(danger: number): number?
	return scores.get(LeaderboardRules.storeName("Wave", danger, week), "1")
end

describe("movement check", function()
	it("is off in Studio and the debug button switches it", function()
		expect(MapService.isMovementCheckOn()).toBe(Movement.studio)
		world.fireServerAs(me, "DebugCommand", "MovementCheck")
		expect(MapService.isMovementCheckOn()).toBe(not Movement.studio)
		world.fireServerAs(me, "DebugCommand", "MovementCheck")
		expect(MapService.isMovementCheckOn()).toBe(Movement.studio)
		MapService.setMovementCheck(true)
	end)

	it("lets a fair player walk at their walk speed", function()
		startRun()
		quiet()
		local start = root().Position
		local speed = walkSpeed()
		expect(speed > 0).toBe(true)
		for _ = 1, 30 do
			moveBy(speed * 0.1, 0)
			world.step(0.1)
		end
		expect(MapService.getMovementCorrections(me)).toBe(0)
		local position = MapService.getRootPosition(me) :: Vector3
		expect(position.X - start.X).toBeNear(speed * 3, 0.01)
	end)

	it("moves a teleporting player back and keeps the old spot for the services", function()
		local before = root().Position
		moveBy(80, 0)
		local seen = MapService.getRootPosition(me) :: Vector3
		expect(seen.X).toBeNear(before.X, 0.01)
		expect(root().Position.X).toBeNear(before.X, 0.01) -- the character itself went back
		expect(MapService.getMovementCorrections(me)).toBe(1)
		world.advance(0.5)
		expect(corrections()).toBe(1)
	end)

	it("undoes a speed hack that runs three times as fast", function()
		world.advance(Movement.strikeGapSeconds + 2.5) -- budget full again
		table.clear(reasons)
		local start = root().Position
		local speed = walkSpeed()
		for _ = 1, 60 do
			moveBy(-speed * 3 * 0.1, 0)
			world.step(0.1)
		end
		expect(table.find(reasons, "Speed") ~= nil).toBe(true)
		expect(table.find(reasons, "Outside")).toBe(nil)
		local gained = start.X - root().Position.X
		-- six seconds: the cheat gets at most the tolerance plus one full budget, not three times the walk
		local allowed = speed * Movement.speedTolerance
		expect(gained <= allowed * 6 + allowed * Movement.burstSeconds + Movement.slackStuds + 1).toBe(true)
		expect(gained < speed * 3 * 6 - 80).toBe(true)
	end)

	it("moves a player back who walks through the arena wall or into a ruin pillar", function()
		world.advance(3)
		local before = root().Position
		local arena = Config.Map.arena
		root().Position = Vector3.new(arena.center.X + arena.size / 2 + 6, before.Y, before.Z)
		world.step(0.1)
		expect(root().Position.X).toBeNear(before.X, 0.01)
		world.advance(Movement.strikeGapSeconds + 0.5)
		local pillar = arena.obstacles[1]
		local count = MapService.getMovementCorrections(me)
		root().Position = Vector3.new(arena.center.X + pillar.x, before.Y, arena.center.Z + pillar.z)
		world.step(0.1)
		expect(root().Position.X).toBeNear(before.X, 0.01)
		expect(MapService.getMovementCorrections(me)).toBe(count + 1)
	end)

	it("caps a cheated velocity at what the player can walk", function()
		root().AssemblyLinearVelocity = Vector3.new(500, -10, 0)
		local velocity = MapService.getRootVelocity(me)
		expect(velocity.X).toBeNear(walkSpeed() * Movement.speedTolerance, 0.01)
		expect(velocity.Y).toBe(-10)
		root().AssemblyLinearVelocity = Vector3.new(4, 0, 3)
		expect(MapService.getRootVelocity(me).X).toBe(4)
		root().AssemblyLinearVelocity = Vector3.zero
	end)

	it("does not check the lobby", function()
		world.fireServerAs(me, "DebugCommand", "AddShards") -- marks this run for the leaderboard test below
		RunDirector.endRun("Victory")
		backToLobby()
		loud()
		local before = root().Position
		moveBy(30, 0)
		world.step(0.1)
		expect(root().Position.X).toBeNear(before.X + 30, 0.01)
		expect((MapService.getRootPosition(me) :: Vector3).X).toBeNear(before.X + 30, 0.01)
	end)
end)

describe("debug runs and leaderboards", function()
	it("left the run with a debug command off the boards", function()
		expect(waveScore(0)).toBe(nil)
	end)

	it("puts a clean run on the boards; reading commands keep it clean", function()
		startRun()
		expect(RunStatsService.isDebugged()).toBe(false)
		world.fireServerAs(me, "DebugCommand", "PrintProfile")
		expect(RunStatsService.isDebugged()).toBe(false)
		RunDirector.endRun("Victory")
		world.advance(0.5)
		expect(waveScore(0) ~= nil).toBe(true)
		backToLobby()
	end)

	it("marks a run that starts with a debug switch still set", function()
		RunDirector.setHoldWaves(true)
		startRun()
		expect(RunStatsService.isDebugged()).toBe(true)
		RunDirector.setHoldWaves(false)
		RunDirector.endRun("Victory")
		backToLobby()
	end)
end)

describe("remotes", function()
	it("drops server -> client remotes a cheat fires at the server", function()
		world.fireServerAs(me, "RunState", { phase = "Running" })
		world.fireServerAs(me, "EnemySnapshot", "garbage")
		world.step()
		expect(RunDirector.getPhase()).toBe("Lobby")
	end)

	it("refuses broken numbers", function()
		local integer = Validate.integer(0, 2 ^ 53)
		expect(integer(5)).toBe(true)
		expect(integer(math.huge)).toBe(false)
		expect(integer(0 / 0)).toBe(false)
		expect(integer(2.5)).toBe(false)
		local number = Validate.number(0, 1)
		expect(number(0 / 0)).toBe(false)
		world.fireServerAs(me, "SwapQuest", 0 / 0)
		world.fireServerAs(me, "SellWeapon", math.huge)
		world.step()
	end)

	it("ran without script errors", function()
		expect(#world.errors).toBe(0)
	end)
end)
