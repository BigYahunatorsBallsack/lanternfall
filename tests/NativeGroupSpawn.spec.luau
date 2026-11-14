--!strict
-- Native Jungle grouped births use one edge point and one delayed queue entry, with source player-overlap behavior.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Rules = require(f.S.SpawnDirector.SpawnRules)
local Enemy = require(f.S.EnemySim)
local Random = require(f.S.RandomService)
local Director = require(f.S.SpawnDirector)
local Map = require(f.S.MapService)
local bounds = { minX = -100, maxX = 100, minZ = -100, maxZ = 100 }

local function runGroups(groups, afterMarker)
	local groupsFor, number, spawn = Rules.groupsFor, Random.number, Enemy.spawn
	Rules.groupsFor = function()
		return groups
	end
	Random.number = function(stream, ...)
		return if stream == "Spawns" then 0.999 else number(stream, ...)
	end
	f.start("WatchmanPistol")
	f.Weapons.setPaused(true)
	Map.setMovementCheck(false)
	for _, player in { f.me, f.peer } do
		require(f.S.CombatService).protect(player, 10000)
	end
	local spawned, markers = {}, {}
	Enemy.spawn = function(name, x, z, ...)
		table.insert(spawned, { name = name, x = x, z = z, at = workspace:GetServerTimeNow() })
		return spawn(name, x, z, ...)
	end
	local connection = f.world.getRemote("SpawnMarkers").OnClientEvent:Connect(function(batch)
		table.insert(markers, batch)
	end)
	Director.setPaused(false)
	f.world.advance(1, 1 / 60)
	if afterMarker then
		afterMarker(markers)
	end
	f.world.advance(1.15, 1 / 60)
	local early = #spawned
	f.world.advance(1, 1 / 60)
	local later = #spawned
	if afterMarker then
		f.me.Character.HumanoidRootPart.Position = Vector3.new(0, 100, 0)
		f.world.advance(2, 1 / 60)
	end
	connection:Disconnect()
	Enemy.spawn = spawn
	Rules.groupsFor = groupsFor
	Random.number = number
	return spawned, markers, early, later
end
local function group(name, count, together)
	local out = table.clone(f.Config.EnemyWaves.waves[1].groups[1])
	out.units = { { enemy = name, min = count, max = count, chance = 1, neutral = false, extraDistance = 0 } }
	out.repeating = 0
	out.edgeTogether = together
	out.atPlayerVertically = together
	return out
end

describe("Native group edge births", function()
	it("lets a later queued ordinary birth pass an earlier grouped request with a longer warning", function()
		local spawned, _, early = runGroups({ group("Shadeling", 1, false), group("Brute", 3, true) })
		expect(early).toBe(1)
		expect(spawned[1].name).toBe("Shadeling")
		expect(#spawned).toBe(4)
		for i = 2, 4 do
			expect(spawned[i].name).toBe("Brute")
			expect(spawned[i].at).toBe(spawned[2].at)
		end
	end)
	it("restarts the entire group warning when a player's body overlaps the birth", function()
		local spawned, markers, _, later = runGroups({ group("Brute", 3, true) }, function(markers)
			local point = markers[1].points
			-- Native player body is12px above the root on the top-down axis.
			f.me.Character.HumanoidRootPart.Position = Vector3.new(point[1], 100, point[2] + 1.2)
		end)
		expect(later).toBe(0)
		expect(#markers >= 2).toBe(true)
		expect(markers[2].spawnsAt - markers[1].spawnsAt >= 85 / 60).toBe(true)
		expect(#spawned).toBe(3)
	end)
	it("selects the side from the group center and shares a selected player's height before source jitter", function()
		local draws = { 0.25, 0.99, 0, 1 }
		local index = 0
		local x, z = Rules.groupEdgePoint(function()
			index += 1
			return draws[index]
		end, bounds, -50, { Vector3.new(0, 100, -20), Vector3.new(0, 100, 20) }, true)
		expect(x).toBeNear(-96.1)
		expect(z).toBeNear(25)
		expect(index).toBe(4)
	end)
	it("tests native birth/player body circles using the player's original local offset", function()
		expect(Rules.groupBirthBlocked(0, 0, { Vector3.new(0, 100, 1.2) })).toBe(true)
		expect(Rules.groupBirthBlocked(0, 0, { Vector3.new(9.61, 100, 1.2) })).toBe(false)
		expect(Rules.groupBirthBlocked(0, 0, {})).toBe(false)
	end)
	it("emits a single marker and spawns every group member at the same instant and position", function()
		local group = table.clone(f.Config.EnemyWaves.waves[1].groups[1])
		group.units = { { enemy = "Shadeling", min = 3, max = 3, chance = 1, neutral = false, extraDistance = 0 } }
		group.edgeTogether = true
		group.atPlayerVertically = true
		group.repeating = 0
		local groupsFor = Rules.groupsFor
		Rules.groupsFor = function()
			return { group }
		end
		local number = Random.number
		Random.number = function(stream, ...)
			return if stream == "Spawns" then 0.999 else number(stream, ...)
		end
		f.start("WatchmanPistol")
		f.Weapons.setPaused(true)
		Map.setMovementCheck(false)
		for _, player in { f.me, f.peer } do
			require(f.S.CombatService).protect(player, 10000)
		end
		local spawned, markers = {}, {}
		local spawn = Enemy.spawn
		Enemy.spawn = function(name, x, z, ...)
			if name == "Shadeling" then
				table.insert(spawned, { x = x, z = z, at = workspace:GetServerTimeNow() })
			end
			return spawn(name, x, z, ...)
		end
		local connection = f.world.getRemote("SpawnMarkers").OnClientEvent:Connect(function(batch)
			table.insert(markers, batch)
		end)
		Director.setPaused(false)
		f.world.advance(1.6, 1 / 60)
		expect(#spawned).toBe(0)
		f.world.advance(1, 1 / 60)
		connection:Disconnect()
		Enemy.spawn = spawn
		Rules.groupsFor = groupsFor
		Random.number = number
		expect(#markers).toBe(1)
		expect(#markers[1].points).toBe(2)
		expect(#spawned).toBe(3)
		for _, row in spawned do
			expect(row.at).toBe(spawned[1].at)
			expect(row.x).toBe(spawned[1].x)
			expect(row.z).toBe(spawned[1].z)
		end
		expect(f.Run.getNativeZoneId()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
