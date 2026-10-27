-- Unit tests for the enemy simulation (EnemySim/World): chasing, crowding, obstacles, contacts, damage,
-- queries, knockback, Spitter shots, elite kinds and the 4 ms step budget with the maximum of 140 enemies; plus the
-- enemy projectiles (EnemySim/Volleys).

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local Volleys = require(game:GetService("ServerScriptService").Server.Services.EnemySim.Volleys)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)

local Sim = Config.Simulation
local Types = Config.Enemies.types
local STEP = 1 / Sim.tickRate
local HALF = Config.Map.arena.size / 2

local function newWorld(obstacles)
	return World.new({
		cellSize = Sim.spatialHashCellSize,
		maxEnemies = Config.Run.spawn.cap.max,
		playerRadius = Sim.playerRadius,
		contactMargin = Sim.contactMargin,
		separationStiffness = Sim.separationStiffness,
		separationPasses = Sim.separationPasses,
		obstacleSteerMargin = Sim.obstacleSteerMargin,
		keepDistanceTolerance = Sim.keepDistanceTolerance,
		minX = -HALF,
		maxX = HALF,
		minZ = -HALF,
		maxZ = HALF,
		obstacles = obstacles or {},
	})
end

local function spawn(world, kindId, x, z, hp)
	local kind = Types[kindId]
	return world:spawn(kind, x, z, hp or kind.hp, kind.contactDamage)
end

local function run(world, seconds, targetXs, targetZs)
	local contacts
	for _ = 1, math.ceil(seconds / STEP) do
		contacts = world:step(STEP, targetXs, targetZs, #targetXs)
	end
	return contacts
end

local function distance(world, id, x, z)
	local ex, ez = world:getPosition(id)
	return math.sqrt((ex - x) ^ 2 + (ez - z) ^ 2)
end

-- deterministic pseudo random numbers for reproducible crowds
local seed = 12345
local function random()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function ringSpawn(world, count, kindId)
	for _ = 1, count do
		local angle = random() * 2 * math.pi
		local radius = 45 + random() * 15
		spawn(world, kindId or "Shadeling", math.cos(angle) * radius, math.sin(angle) * radius)
	end
end

describe("EnemyWorld", function()
	it("gives every enemy its own id and stops at the cap", function()
		local world = newWorld()
		local seen = {}
		for _ = 1, Config.Run.spawn.cap.max do
			local id = spawn(world, "Shadeling", 0, 0)
			expect(id ~= nil and seen[id] == nil).toBe(true)
			seen[id] = true
		end
		expect(spawn(world, "Shadeling", 0, 0)).toBe(nil)
		expect(world:getAliveCount()).toBe(Config.Run.spawn.cap.max)
	end)

	it("walks straight to the player and stops at the edge", function()
		local world = newWorld()
		local id = spawn(world, "Shadeling", 50, 0)
		run(world, 1, { 0 }, { 0 })
		expect(distance(world, id, 0, 0)).toBeNear(50 - Types.Shadeling.speed, 0.01)
		run(world, 4, { 0 }, { 0 })
		expect(distance(world, id, 0, 0)).toBeNear(Types.Shadeling.radius + Sim.playerRadius, 0.01)
	end)

	it("chases the nearest of several players", function()
		local world = newWorld()
		local id = spawn(world, "Shadeling", 20, 0)
		run(world, 3, { -40, 40 }, { 0, 0 })
		expect(distance(world, id, 40, 0)).toBeNear(Types.Shadeling.radius + Sim.playerRadius, 0.01)
	end)

	it("stands still without players", function()
		local world = newWorld()
		local id = spawn(world, "Brute", 10, 10)
		run(world, 1, {}, {})
		local x, z = world:getPosition(id)
		expect(x).toBe(10)
		expect(z).toBe(10)
	end)

	it("keeps ranged enemies at their distance", function()
		local world = newWorld()
		local keep = Types.Spitter.ranged.keepDistance
		local far = spawn(world, "Spitter", 0, 60)
		local near = spawn(world, "Spitter", 0, -8)
		run(world, 5, { 0 }, { 0 })
		expect(math.abs(distance(world, far, 0, 0) - keep) <= Sim.keepDistanceTolerance + 0.01).toBe(true)
		expect(math.abs(distance(world, near, 0, 0) - keep) <= Sim.keepDistanceTolerance + 0.01).toBe(true)
	end)

	it("forms a calm crowd of 140 without overlaps or enemies inside the player", function()
		local world = newWorld()
		ringSpawn(world, 140)
		run(world, 30, { 0 }, { 0 })
		local before = {}
		for i = 1, world.count do
			before[i] = { world.xs[i], world.zs[i] }
		end
		run(world, 1, { 0 }, { 0 })
		local moved, worstOverlap, insidePlayer = 0, 0, 0
		local radius = Types.Shadeling.radius
		for i = 1, world.count do
			moved += math.sqrt((world.xs[i] - before[i][1]) ^ 2 + (world.zs[i] - before[i][2]) ^ 2)
			local fromPlayer = math.sqrt(world.xs[i] ^ 2 + world.zs[i] ^ 2)
			if fromPlayer < radius + Sim.playerRadius - 0.01 then
				insidePlayer += 1
			end
			for j = i + 1, world.count do
				local gap = math.sqrt((world.xs[i] - world.xs[j]) ^ 2 + (world.zs[i] - world.zs[j]) ^ 2)
				worstOverlap = math.max(worstOverlap, 2 * radius - gap)
			end
		end
		local averageMoved = moved / world.count
		print(
			`  crowd: worst overlap {string.format("%.2f", worstOverlap)} studs, moved {string.format(
				"%.2f",
				averageMoved
			)} studs/s`
		)
		expect(insidePlayer).toBe(0)
		expect(worstOverlap < radius / 2).toBe(true) -- at most a quarter of a body on top of each other
		expect(averageMoved < 0.5).toBe(true) -- settled, not jittering
	end)

	it("lets a Brute push Shadelings aside", function()
		local world = newWorld()
		local brute = spawn(world, "Brute", 0, 0)
		local shadeling = spawn(world, "Shadeling", 1, 0)
		run(world, STEP, {}, {})
		local bx = world:getPosition(brute)
		local sx = world:getPosition(shadeling)
		expect(math.abs(sx - 1) > 4 * math.abs(bx)).toBe(true)
	end)

	it("walks around an obstacle in the way", function()
		local world = newWorld({ { x = 0, z = 20, radius = 6 } })
		local id = spawn(world, "Shadeling", 0, 40)
		local closest = math.huge
		for _ = 1, 6 / STEP do
			world:step(STEP, { 0 }, { 0 }, 1)
			local x, z = world:getPosition(id)
			closest = math.min(closest, math.sqrt(x * x + (z - 20) ^ 2))
		end
		expect(distance(world, id, 0, 0)).toBeNear(Types.Shadeling.radius + Sim.playerRadius, 0.01)
		expect(closest >= 6 + Types.Shadeling.radius - 0.01).toBe(true)
	end)

	it("keeps enemies inside the arena", function()
		local world = newWorld()
		local id = spawn(world, "Brute", HALF + 20, 0)
		run(world, STEP, { HALF + 40 }, { 0 })
		local x = world:getPosition(id)
		expect(x).toBeNear(HALF - Types.Brute.radius, 0.01)
	end)

	it("reports the strongest contact damage per player", function()
		local world = newWorld()
		spawn(world, "Shadeling", 3, 0)
		spawn(world, "Brute", -4, 0)
		spawn(world, "Spitter", 0, 30) -- no contact damage
		local contacts = run(world, 1, { 0, 100 }, { 0, 0 })
		expect(contacts[1]).toBe(Types.Brute.contactDamage)
		expect(contacts[2]).toBe(0)
	end)

	it("kills once, hides the dead from queries and frees the slot on the next step", function()
		local world = newWorld()
		local id = spawn(world, "Shadeling", 5, 5)
		local other = spawn(world, "Shadeling", 40, 40)
		expect(world:damage(id, 4)).toBe(false)
		expect(world:getHealth(id)).toBe(Types.Shadeling.hp - 4)
		expect(world:damage(id, 100)).toBe(true)
		expect(world:damage(id, 100)).toBe(false)
		expect(world:isAlive(id)).toBe(false)
		expect(world:getAliveCount()).toBe(1)
		expect(world:getPosition(id)).toBe(5) -- still readable for the kill event
		expect(world:queryRadius(5, 5, 3, {})).toBe(0)
		expect(world:nearest(0, 0)).toBe(other)
		world:step(STEP, {}, {}, 0)
		expect(world.count).toBe(1)
		expect(world:getPosition(id)).toBe(nil)
		expect(world:isAlive(other)).toBe(true)
		local again = spawn(world, "Shadeling", 0, 0)
		expect(again ~= id).toBe(true)
	end)

	it("finds the same enemies as a brute-force search", function()
		local world = newWorld()
		for _ = 1, 120 do
			spawn(
				world,
				if random() < 0.3 then "Brute" else "Shadeling",
				(random() - 0.5) * 200,
				(random() - 0.5) * 200
			)
		end
		world:step(STEP, {}, {}, 0)
		local out = {}
		for _ = 1, 50 do
			local x, z, radius = (random() - 0.5) * 200, (random() - 0.5) * 200, random() * 30
			local found = world:queryRadius(x, z, radius, out)
			local expected = 0
			for i = 1, world.count do
				local reach = radius + world.kinds[i].radius
				if (world.xs[i] - x) ^ 2 + (world.zs[i] - z) ^ 2 <= reach * reach then
					expected += 1
				end
			end
			expect(found).toBe(expected)
		end
	end)

	it("finds the same enemies along a segment as a brute-force search", function()
		local world = newWorld()
		for _ = 1, 120 do
			spawn(
				world,
				if random() < 0.3 then "Brute" else "Shadeling",
				(random() - 0.5) * 200,
				(random() - 0.5) * 200
			)
		end
		world:step(STEP, {}, {}, 0)
		local out = {}
		for _ = 1, 50 do
			local x0, z0 = (random() - 0.5) * 200, (random() - 0.5) * 200
			local x1, z1 = x0 + (random() - 0.5) * 40, z0 + (random() - 0.5) * 40
			local radius = random() * 2
			local found = world:querySegment(x0, z0, x1, z1, radius, out)
			local expected = 0
			local sx, sz = x1 - x0, z1 - z0
			for i = 1, world.count do
				local t = math.clamp(((world.xs[i] - x0) * sx + (world.zs[i] - z0) * sz) / (sx * sx + sz * sz), 0, 1)
				local reach = radius + world.kinds[i].radius
				if (world.xs[i] - x0 - sx * t) ^ 2 + (world.zs[i] - z0 - sz * t) ^ 2 <= reach * reach then
					expected += 1
				end
			end
			expect(found).toBe(expected)
		end
		expect(world:querySegment(1000, 1000, 1000, 1000, 1, out)).toBe(0) -- a point works too
	end)

	it("pushes enemies less the heavier they are, never into obstacles or out of the arena", function()
		local world = newWorld({ { x = 20, z = 0, radius = 4 } })
		local light = spawn(world, "Shadeling", 0, 0)
		local heavy = spawn(world, "Brute", 0, 30)
		local blocked = spawn(world, "Shadeling", 14, 0)
		local wall = spawn(world, "Shadeling", HALF - 3, 0)
		world:push(light, 3, 0)
		world:push(heavy, 0, 3)
		world:push(blocked, 3, 0)
		world:push(wall, 10, 0)
		expect(world:getPosition(light)).toBeNear(3)
		expect(select(2, world:getPosition(heavy))).toBeNear(30 + 3 / Types.Brute.mass)
		expect(20 - world:getPosition(blocked) >= 4 + Types.Shadeling.radius - 1e-6).toBe(true)
		expect(world:getPosition(wall)).toBeNear(HALF - Types.Shadeling.radius)
		world:damage(light, 100)
		world:push(light, 5, 0)
		expect(world:getPosition(light)).toBeNear(3) -- the dead stay put
	end)

	it("reports the HP a hit actually took", function()
		local world = newWorld()
		local id = spawn(world, "Shadeling", 0, 0)
		expect(select(2, world:damage(id, 4))).toBe(4)
		expect(select(2, world:damage(id, 100))).toBe(Types.Shadeling.hp - 4)
		expect(select(2, world:damage(id, 100))).toBe(0)
	end)

	it("clears without leftovers", function()
		local world = newWorld()
		ringSpawn(world, 20)
		world:clear()
		expect(world:getAliveCount()).toBe(0)
		expect(world.count).toBe(0)
		expect(world:queryRadius(0, 0, 100, {})).toBe(0)
	end)

	it("steps 140 enemies with 4 players inside the 4 ms budget", function()
		local world = newWorld(Config.Map.arena.obstacles)
		for i = 1, 140 do
			local angle = random() * 2 * math.pi
			local radius = 45 + random() * 15
			local kind = if i % 5 == 0 then "Brute" elseif i % 5 == 1 then "Spitter" else "Shadeling"
			spawn(world, kind, math.cos(angle) * radius, math.sin(angle) * radius)
		end
		local xs, zs = { -10, 10, 0, 30 }, { 0, 0, 15, -20 }
		run(world, 10, xs, zs) -- let the crowd form first: dense crowds are the expensive case
		local steps = 150
		local started = os.clock()
		run(world, steps * STEP, xs, zs)
		local milliseconds = (os.clock() - started) * 1000 / steps
		print(`  step with 140 enemies: {string.format("%.3f", milliseconds)} ms`)
		expect(milliseconds < Sim.budget.stepMilliseconds).toBe(true)
	end)
end)

describe("lag-corrected contacts", function()
	it("checks contacts at the given contact positions instead of the targets", function()
		local world = newWorld()
		local touchAt = Types.Shadeling.radius + Sim.playerRadius
		spawn(world, "Shadeling", touchAt, 0)
		-- player standing still: contact
		local contacts = world:step(STEP, { 0 }, { 0 }, 1, { 0 }, { 0 })
		expect(contacts[1]).toBe(Types.Shadeling.contactDamage)
		-- player running away from the enemy: on their screen they are already out of reach
		contacts = world:step(STEP, { 0 }, { 0 }, 1, { -3 }, { 0 })
		expect(contacts[1]).toBe(0)
	end)

	it("lets Spitters shoot at the nearest target in fire range every fireInterval", function()
		local world = newWorld()
		local ranged = Types.Spitter.ranged
		local id = spawn(world, "Spitter", 30, 0)
		local shots = 0
		local steps = math.ceil(ranged.fireInterval * 3 / STEP)
		for _ = 1, steps do
			world:step(STEP, { 0 }, { 0 }, 1)
			for k = 0, world.shotCount - 1 do
				expect(world.shots[k * 5 + 1]).toBe(id)
				expect(world.shots[k * 5 + 4]).toBe(1)
				expect(world.shots[k * 5 + 5]).toBe(ranged.projectileDamage)
				shots += 1
			end
		end
		expect(shots >= 2 and shots <= 3).toBe(true)

		-- out of fire range: no shots
		local far = newWorld()
		spawn(far, "Spitter", ranged.fireRange + 30, 0)
		far:step(STEP, { 0 }, { 0 }, 1) -- moves at most a few studs per step
		local farShots = far.shotCount
		expect(farShots).toBe(0)

		-- enemies without `ranged` never shoot
		local melee = newWorld()
		spawn(melee, "Brute", 10, 0)
		run(melee, 5, { 0 }, { 0 })
		expect(melee.shotCount).toBe(0)
	end)

	it("builds bigger, slower and tougher elite kinds with their own typeId", function()
		local elite = Config.Enemies.elite
		for id, base in Types do
			local kind = EnemyKinds.get(id, true)
			expect(kind ~= nil).toBe(true)
			if kind then
				expect(kind.elite).toBe(true)
				expect(kind.typeId).toBe(base.typeId + elite.typeIdOffset)
				expect(kind.hp).toBeNear(base.hp * elite.hpMultiplier)
				expect(kind.speed).toBeNear(base.speed * elite.speedMultiplier)
				expect(kind.radius).toBeNear(base.radius * elite.sizeMultiplier)
				expect(kind.contactDamage).toBeNear(base.contactDamage * elite.damageMultiplier)
				expect(kind.xp).toBe(elite.xp)
				expect(EnemyKinds.byTypeId(kind.typeId)).toBe(kind)
				expect(EnemyKinds.byTypeId(base.typeId)).toBe(base)
				if base.ranged and kind.ranged then
					expect(kind.ranged.projectileDamage).toBeNear(base.ranged.projectileDamage * elite.damageMultiplier)
				end
			end
		end
		expect(EnemyKinds.get("Shadeling")).toBe(Types.Shadeling)
	end)
end)

describe("Volleys", function()
	local function newVolleys(obstacles)
		return Volleys.new({
			playerRadius = Sim.playerRadius,
			minX = -HALF,
			maxX = HALF,
			minZ = -HALF,
			maxZ = HALF,
			obstacles = obstacles or {},
		})
	end

	local function flyAll(volleys, seconds, xs, zs)
		local hits, ended = {}, {}
		for _ = 1, math.ceil(seconds / STEP) do
			volleys:step(STEP, xs, zs, #xs)
			for k = 1, volleys.hitCount * 2 do
				table.insert(hits, volleys.hits[k])
			end
			for k = 1, volleys.endedCount * 2 do
				table.insert(ended, volleys.ended[k])
			end
		end
		return hits, ended
	end

	it("hits the first target in its path once and ends there", function()
		local volleys = newVolleys()
		local id = volleys:fire(0, 0, 1, 0, 30, 50, 0.6, 8)
		local hits, ended = flyAll(volleys, 2, { 20, 30 }, { 0, 0 })
		expect(#hits).toBe(2)
		expect(hits[1]).toBe(1) -- the closer target
		expect(hits[2]).toBe(8)
		expect(ended[1]).toBe(id)
		expect(ended[2]).toBeNear(20 - Sim.playerRadius - 0.6, 0.01)
		expect(volleys:getCount()).toBe(0)
	end)

	it("misses a target beside its path and fades at its range", function()
		local volleys = newVolleys()
		volleys:fire(0, 0, 1, 0, 30, 25, 0.6, 8)
		local hits, ended = flyAll(volleys, 2, { 15 }, { 3 })
		expect(#hits).toBe(0)
		expect(#ended).toBe(0) -- reaching the range is not an "ended" event
		expect(volleys:getCount()).toBe(0)
	end)

	it("stops at obstacles and the arena edge", function()
		local volleys = newVolleys({ { x = 10, z = 0, radius = 2 } })
		volleys:fire(0, 0, 1, 0, 30, 50, 0.6, 8)
		local hits, ended = flyAll(volleys, 2, { 20 }, { 0 })
		expect(#hits).toBe(0)
		expect(ended[2]).toBeNear(8, 0.01)

		local edge = newVolleys()
		edge:fire(HALF - 5, 0, 1, 0, 30, 50, 0.6, 8)
		local _, edgeEnded = flyAll(edge, 2, {}, {})
		expect(#edgeEnded).toBe(2)
		expect(edge:getCount()).toBe(0)
	end)
end)
