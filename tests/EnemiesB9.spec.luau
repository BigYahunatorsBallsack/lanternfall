-- End-to-end test of the new enemies (B9 part 2): the debug button spawns each of them and the client draws them,
-- a Thornback sprays its ring when hit, a Brood Egg hatches into Shadelings, a Herald's buff shows on the client and
-- a Gobbler eats orbs and drops them again. Real server and client bootstraps in a simulated Roblox
-- (tests/helpers/RobloxMock), like tests/Loot.spec.luau. Look and feel: Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local EnemySim = require(Services.EnemySim)
local ExperienceService = require(Services.ExperienceService)
local LootService = require(Services.LootService)
local MapService = require(Services.MapService)
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local Types = Config.Enemies.types

local function enemyRenderer()
	return require(folderProxy("src/client", "Client").Controllers.EnemyRenderer)
end

local function click(name)
	world.click(world.gui("Debug", name))
	world.advance(0.2)
end

local function position(): Vector3
	return MapService.getRootPosition(me) :: Vector3
end

-- Ids of the living enemies of one kind.
local function idsOf(kind: string): { number }
	local ids = {}
	local list = {}
	for i = 1, EnemySim.collectIds(ids) do
		if EnemySim.getKind(ids[i]) == kind then
			table.insert(list, ids[i])
		end
	end
	return list
end

local function spawnNear(kind: string): number
	expect(SpawnDirector.spawnEnemy(kind, position())).toBe(true)
	local ids = idsOf(kind)
	return ids[#ids]
end

local function killAll()
	EnemySim.killAll()
	world.advance(0.2)
end

describe("new enemies (B9)", function()
	it("starts a run with weapons, spawning and the wave timer off", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(3.5)
		expect(RunDirector.getPhase()).toBe("Running")
		LootService.setDropsPaused(true)
		click("ToggleWeapons")
		click("ToggleSpawning")
		click("HoldWaves") -- the wave does not end during the test
		killAll()
		expect(EnemySim.getCount()).toBe(0)
	end)

	it("spawns each new enemy with the debug button, one after another, and draws it", function()
		for _, kind in Config.Admin.newEnemies do
			click("SpawnNewEnemy")
			expect(#idsOf(kind)).toBe(1)
		end
		expect(EnemySim.getCount()).toBe(#Config.Admin.newEnemies)
		world.advance(0.3)
		expect(enemyRenderer().getStats().drawn).toBe(#Config.Admin.newEnemies)
		killAll()
	end)

	it("lets a Thornback spray its ring of shots when hit", function()
		local id = spawnNear("Thornback")
		local before = EnemySim.getShotCount()
		EnemySim.damage(id, 1)
		expect(EnemySim.getShotCount()).toBe(before + (Types.Thornback.retaliate :: any).count)
		killAll()
	end)

	it("hatches a Brood Egg into Shadelings unless it is killed first", function()
		local hatch = Types.BroodEgg.hatch :: any
		spawnNear("BroodEgg")
		world.advance(hatch.seconds + 0.3)
		expect(#idsOf("BroodEgg")).toBe(0)
		expect(#idsOf(hatch.enemy)).toBe(hatch.count)
		killAll()

		local early = spawnNear("BroodEgg")
		EnemySim.damage(early, 1e6)
		world.advance(hatch.seconds + 0.3)
		expect(#idsOf(hatch.enemy)).toBe(0)
	end)

	it("shows the Herald's buff on the client", function()
		local herald = spawnNear("Herald")
		local at = EnemySim.getPosition(herald) :: Vector3
		local brute = EnemySim.spawn("Brute", at.X + 4, at.Z, 1, 1) :: number
		world.advance((Types.Herald.pulse :: any).intervalSeconds + 0.5)
		local _, _, buffed = enemyRenderer().getStatus(brute)
		expect(buffed).toBe(true)
		killAll()
	end)

	it("lets a Gobbler eat the orbs on the floor and drop them all when killed", function()
		local orbs = ExperienceService.getOrbCount()
		local gobbler = spawnNear("Gobbler")
		local at = EnemySim.getPosition(gobbler) :: Vector3
		for k = 1, 3 do
			local id = EnemySim.spawn("Shadeling", at.X + 14 + k * 2, at.Z, 1, 1) :: number -- far enough that it has to walk there
			EnemySim.damage(id, 1e6)
		end
		world.step()
		expect(ExperienceService.getOrbCount()).toBe(orbs + 3)
		world.advance(3) -- walks to the nearest orbs and eats them (also ones left from earlier tests)
		local left = ExperienceService.getOrbCount()
		expect(left < orbs + 3).toBe(true)
		EnemySim.damage(gobbler, 1e6)
		world.step()
		expect(ExperienceService.getOrbCount()).toBe(left + 1) -- one orb with everything it ate
	end)

	it("finished without any runtime error", function()
		expect(#world.errors).toBe(0)
	end)
end)
