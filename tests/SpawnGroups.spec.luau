-- End-to-end test of the spawn groups (B9 part 1): a wave's groups fire on their own, red markers show on the
-- client where a group will appear, the enemies come together once the markers run out, and pausing the spawning
-- drops groups that are still announced. Real server and client bootstraps in a simulated Roblox
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

world.addPlayer("Owner", 1, true)
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
local firstGroup = spawn.groups[1].groups[1]

describe("spawn groups", function()
	it("starts a run with weapons off", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(3.5)
		expect(RunDirector.getPhase()).toBe("Running")
		LootService.setDropsPaused(true)
		click("ToggleWeapons")
		expect(EnemySim.getCount()).toBe(0)
	end)

	it("shows red markers before the first group appears", function()
		local waited = 0
		while markers() == 0 and waited < firstGroup.every do
			world.advance(0.1)
			waited += 0.1
		end
		expect(markers() > 0).toBe(true)
		expect(EnemySim.getCount()).toBe(0) -- the enemies only come when the markers run out
		expect(#workspace:FindFirstChild("LanternfallSpawnMarkers"):GetChildren()).toBe(markers() * 2) -- two bars each
	end)

	it("brings the whole group together at one spot when the markers run out", function()
		local shown = markers()
		world.advance(spawn.markerSeconds + 0.1)
		expect(EnemySim.getCount()).toBe(shown)
		local spots = positions()
		local reach = spawn.groupSpread * math.sqrt(#spots) * 2 + 1 -- two offsets apart, plus a push
		for _, a in spots do
			for _, b in spots do
				expect((a - b).Magnitude <= reach).toBe(true)
			end
		end
		expect(markers()).toBe(0)
	end)

	it("keeps firing groups of the same kind through the wave", function()
		world.advance(firstGroup.every * 2)
		expect(EnemySim.getCount() > firstGroup.size).toBe(true)
	end)

	it("drops announced groups when spawning is paused", function()
		local waited = 0
		while markers() == 0 and waited < firstGroup.every + 0.5 do
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
