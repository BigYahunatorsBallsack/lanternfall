--!strict
-- Real Alamosaurus egg chains retain native attack timing, separate births, natural egg death and captured Charm ownership.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Director = require(f.S.SpawnDirector)
local World = require(f.S.EnemySim.World)
local Kinds = require(f.Shared.Util.EnemyKinds)
local Map = require(f.S.MapService)
require(f.S.SpawnDirector.SpawnRules).groupsFor = function()
	return {}
end
local spawned, requests = {}, {}
local spawn = Enemy.spawn
Enemy.spawn = function(name, x, z, ...)
	local id = spawn(name, x, z, ...)
	if name == "DinoEgg" or name == "BabyTrex" then
		table.insert(spawned, { name = name, id = id, x = x, z = z, at = workspace:GetServerTimeNow() })
	end
	return id
end
Enemy.NativeSummon:Connect(function(name, x, z, owner)
	table.insert(requests, { name = name, x = x, z = z, owner = owner, at = workspace:GetServerTimeNow() })
end)
local function start()
	f.start("WatchmanPistol")
	f.Weapons.setPaused(true)
	Map.setMovementCheck(false)
	Director.setPaused(false)
	for _, player in { f.me, f.peer } do
		require(f.S.CombatService).protect(player, 10000)
	end
	table.clear(spawned)
	table.clear(requests)
end
describe("Native Jungle spawning", function()
	it("uses original child identities, animation-method times and independent birth timing", function()
		local a = Kinds.get("Alamosaurus").nativeSpawn
		local e = Kinds.get("DinoEgg").nativeSpawn
		expect(a.enemy).toBe("DinoEgg")
		expect(a.count).toBe(3)
		expect(a.maxCount).toBe(999)
		expect(a.timing.fireAt).toBeNear(0.8)
		expect(a.timing.cooldownRandomSeconds).toBeNear(10 / 60)
		expect(e.enemy).toBe("BabyTrex")
		expect(e.timing.fireAt).toBeNear(1.6)
		expect(e.timing.animationSeconds).toBeNear(2)
		expect(e.dieOnRequest).toBe(true)
	end)
	it("makes three real eggs after the attack and warning, then hatches real Baby T-Rex bodies", function()
		start()
		local before = f.Data.get(f.me).nativeCounts.enemiesKilled
		assert(Enemy.spawn("Alamosaurus", 60, 0, 100, 0, nil, nil, 0, 1))
		f.world.advance(3.5, 1 / 60)
		expect(#requests).toBe(0)
		expect(#spawned).toBe(0)
		f.world.advance(2, 1 / 60)
		local eggs = {}
		for _, row in spawned do
			if row.name == "DinoEgg" then
				table.insert(eggs, row)
			end
		end
		expect(#eggs).toBe(3)
		expect(#requests).toBe(3)
		for _, row in eggs do
			expect(row.at - requests[1].at >= 1).toBe(true)
		end
		f.world.advance(5.5, 1 / 60)
		local babies = 0
		for _, row in spawned do
			if row.name == "BabyTrex" then
				babies += 1
			end
		end
		expect(babies >= 3).toBe(true)
		for _, row in eggs do
			expect(Enemy.isAlive(row.id)).toBe(false)
		end
		expect(f.Data.get(f.me).nativeCounts.enemiesKilled).toBe(before)
		expect(#f.world.errors).toBe(0)
	end)
	it("lets a real charmed egg die naturally and gives its delayed child to the same owner", function()
		start()
		local id = assert(Enemy.spawn("DinoEgg", 60, 0, 100, 1, nil, nil, 0, 1))
		Enemy.damage(id, 1, nil)
		expect(Enemy.tryCharm(f.me, id, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end)).toBe(true)
		table.clear(spawned)
		f.world.advance(6, 1 / 60)
		expect(Enemy.isCharmed(id)).toBe(false)
		expect(#spawned).toBe(1)
		expect(spawned[1].name).toBe("BabyTrex")
		expect(Enemy.isCharmed(spawned[1].id)).toBe(true)
		expect(Enemy.getCharmedCount(f.me.UserId)).toBe(1)
		expect(requests[1].owner).toBe(f.me.UserId)
		expect(#f.world.errors).toBe(0)
	end)
	it("stops at the native total child quota rather than treating it as a volley quota", function()
		local sim = f.Config.Simulation
		local world = World.new({
			cellSize = sim.spatialHashCellSize,
			maxEnemies = 140,
			playerRadius = sim.playerRadius,
			contactMargin = sim.contactMargin,
			separationStiffness = sim.separationStiffness,
			separationPasses = sim.separationPasses,
			obstacleSteerMargin = sim.obstacleSteerMargin,
			keepDistanceTolerance = sim.keepDistanceTolerance,
			minX = -100,
			maxX = 100,
			minZ = -100,
			maxZ = 100,
			obstacles = {},
		})
		local kind = table.clone(Kinds.get("Alamosaurus"))
		kind.nativeSpawn = table.clone(kind.nativeSpawn)
		kind.nativeSpawn.maxCount = 3
		kind.speed = 0
		kind.speedMax = 0
		local id = assert(world:spawn(kind, 0, 0, 1000, 0))
		local events = 0
		for _ = 1, 120 do
			world:step(0.1, {}, {}, 0)
			events += world.summonCount
		end
		expect(events).toBe(1)
		expect(world.nativeSpawnClocks[world.indexOf[id]].shots).toBe(1)
	end)
end)
