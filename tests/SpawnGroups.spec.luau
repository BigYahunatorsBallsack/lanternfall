-- End-to-end test of Brotato's spawn groups: a wave's groups fire on their own, red markers show on the client
-- where each enemy will appear, the enemies come once the markers run out, away from the player, and pausing the
-- spawning drops enemies that are still announced. Real server and client bootstraps in a simulated Roblox
-- (tests/helpers/RobloxMock), like tests/Loot.spec.luau. Look and feel: Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local EnemySim = require(Services.EnemySim)
local LootService = require(Services.LootService)
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local function markers(): number
	return require(folderProxy("src/client", "Client").Controllers.SpawnMarkerRenderer).getCount()
end

local function click(name)
	world.click(world.gui("Debug", name))
	world.advance(0.2)
end

local function positions(): { Vector3 }
	local ids = {}
	local list = {}
	for i = 1, EnemySim.collectIds(ids) do
		table.insert(list, EnemySim.getPosition(ids[i]) :: Vector3)
	end
	return list
end

local spawn = Config.Run.spawn
local firstGroup = Config.EnemyWaves.waves[1].groups[1] -- 4-5 Shadelings at 1 s, then every 3 s

describe("spawn groups", function()
	it("starts a run with weapons off", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(3.5)
		expect(RunDirector.getPhase()).toBe("Running")
		LootService.setDropsPaused(true)
		click("ToggleWeapons")
		-- without weapons the crowd would end the run before these tests are done (100 HP on the default character)
		require(Services.CombatService).protect(me, 10000)
		expect(EnemySim.getCount()).toBe(0)
	end)

	it("shows red markers before the first group appears", function()
		local waited = 0
		while markers() == 0 and waited < firstGroup.timing + 1 do
			world.advance(0.1)
			waited += 0.1
		end
		expect(markers() > 0).toBe(true)
		expect(EnemySim.getCount()).toBe(0) -- the enemies only come when the markers run out
		expect(#workspace:FindFirstChild("LanternfallSpawnMarkers"):GetChildren()).toBe(markers()) -- one floor canvas each
	end)

	it("brings the marked enemies when the markers run out, away from the player", function()
		world.advance(spawn.markerSeconds + 0.5)
		expect(EnemySim.getCount() >= firstGroup.units[1].min).toBe(true)
		local root = me.Character.HumanoidRootPart.Position
		local away = spawn.layout.minPlayerDistance * spawn.layout.studsPerPixel
		for _, spot in positions() do
			local flat = Vector3.new(spot.X - root.X, 0, spot.Z - root.Z)
			-- born at least `away` from the player; the first ones have walked towards them for up to a second since
			expect(flat.Magnitude >= away / 2).toBe(true)
		end
		expect(markers()).toBe(0)
	end)

	it("keeps firing groups of the same kind through the wave", function()
		world.advance(firstGroup.interval * 2)
		expect(EnemySim.getCount() > firstGroup.units[1].max).toBe(true)
	end)

	it("drops announced groups when spawning is paused", function()
		local waited = 0
		while markers() == 0 and waited < firstGroup.interval + 0.5 do
			world.advance(0.1)
			waited += 0.1
		end
		expect(markers() > 0).toBe(true)
		local before = EnemySim.getCount()
		click("ToggleSpawning")
		expect(SpawnDirector.isPaused()).toBe(true)
		world.advance(spawn.markerSeconds + 0.5)
		expect(EnemySim.getCount()).toBe(before)
	end)

	it("finished without any runtime error", function()
		expect(#world.errors).toBe(0)
	end)
end)
