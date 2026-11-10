--!strict
-- Charmed actors move and attack hostiles without entering hostile queries, preserve timers, stop burning and expire once.
loadHelper("tests/helpers/RobloxMock.luau")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.EnemySim
local World, Friends = require(S.World), require(S.CharmedWorld)
local function setup()
	local serial = 0
	local sim = Config.Simulation
	local params = {
		cellSize = sim.spatialHashCellSize,
		maxEnemies = 140,
		playerRadius = sim.playerRadius,
		contactMargin = 0,
		separationStiffness = sim.separationStiffness,
		separationPasses = sim.separationPasses,
		obstacleSteerMargin = sim.obstacleSteerMargin,
		keepDistanceTolerance = sim.keepDistanceTolerance,
		minX = -100,
		maxX = 100,
		minZ = -100,
		maxZ = 100,
		obstacles = {},
		allocateId = function()
			serial += 1
			return serial
		end,
	}
	local hostile = World.new(params)
	local hits, expired = {}, {}
	local friends = Friends.new(params, {
		damage = function(id, amount, source)
			table.insert(hits, { id = id, amount = amount, source = source })
		end,
		expired = function(member, x, z)
			table.insert(expired, { member = member, x = x, z = z })
		end,
	})
	return hostile, friends, hits, expired
end
describe("Charmed faction runtime", function()
	it(
		"preserves identity and AI timers, resets damage to unboosted base plus200%, stops burning and adds100 speed points",
		function()
			local hostile, friends = setup()
			local id = assert(hostile:spawn(Config.Enemies.types.Shadeling, 0, 0, 100, 10, 5))
			local index = hostile.indexOf[id]
			hostile.burning[index] = true
			hostile.shotCooldown[index] = 0.25
			assert(friends:convert(hostile, id, 17, 0, { contact = 4, shot = 2 }))
			expect(friends:count(17)).toBe(1)
			expect(friends:count(18)).toBe(0)
			local actor = friends.world.indexOf[id]
			expect(friends.world.burning[actor]).toBe(false)
			expect(friends.world.contactDamage[actor]).toBe(12)
			expect(friends.world.shotDamage[actor]).toBe(6)
			expect(friends.world.shotCooldown[actor]).toBe(0.25)
			expect(friends.world.speedBonuses[actor]).toBe(10)
			expect(hostile:isAlive(id)).toBe(false)
		end
	)
	it("attacks hostile targets using their own collision radii", function()
		local hostile, friends, hits = setup()
		local id = assert(hostile:spawn(Config.Enemies.types.Shadeling, 0, 0, 100, 10))
		assert(friends:convert(hostile, id, 17, 0, { contact = 4, shot = 0 }))
		local target = assert(hostile:spawn(Config.Enemies.types.Brute, 2, 0, 100, 10))
		friends:step(0.1, 0.1, hostile)
		expect(#hits).toBe(1)
		expect(hits[1].id).toBe(target)
		expect(hits[1].source).toBe(id)
		expect(hits[1].amount).toBe(12)
		expect(friends.world.nativeSlows:active(id)).toBe(true)
	end)
	it("expires at eight seconds without reverting and clears without deaths on wave reset", function()
		local hostile, friends, _, expired = setup()
		local id = assert(hostile:spawn(Config.Enemies.types.Shadeling, 0, 0, 100, 10))
		assert(friends:convert(hostile, id, 17, 0, { contact = 4, shot = 0 }))
		friends:step(0.1, 7.99, hostile)
		expect(#expired).toBe(0)
		friends:step(0.1, 8, hostile)
		expect(#expired).toBe(1)
		expect(friends:count(17)).toBe(0)
		expect(hostile:isAlive(id)).toBe(false)
		friends:clear()
		expect(#expired).toBe(1)
	end)
	it("keeps ranged shots friendly after their shooter expires and resolves their native base damage", function()
		local hostile, friends, hits = setup()
		local shooter = assert(hostile:spawn(Config.Enemies.types.Spitter, 0, 0, 100, 1, 2))
		assert(friends:convert(hostile, shooter, 17, 0, { contact = 1, shot = 2 }))
		local target = assert(hostile:spawn(Config.Enemies.types.Brute, 15, 0, 100, 1))
		friends.world.shotCooldown[friends.world.indexOf[shooter]] = 0
		friends:step(0.01, 7.99, hostile)
		expect(friends.shots:getCount()).toBe(1)
		friends:step(0.5, 8, hostile)
		expect(friends.world:isAlive(shooter)).toBe(false)
		expect(#hits).toBe(1)
		expect(hits[1].id).toBe(target)
		expect(hits[1].amount).toBe(6)
	end)
	it("keeps charge-side projectiles friendly with the source angle and boosted enemy damage", function()
		local hostile, friends = setup()
		local id = assert(hostile:spawn(Config.Enemies.types.Hookfang, 0, 0, 100, 1, 2))
		assert(friends:convert(hostile, id, 17, 0, { contact = 1, shot = 2 }))
		assert(hostile:spawn(Config.Enemies.types.Brute, 40, 0, 100, 1))
		local index = friends.world.indexOf[id]
		friends.world.modes[index] = World.MODE_RUSH
		friends.world.rushXs[index], friends.world.rushZs[index], friends.world.rushLeft[index] = 1, 0, 37.5
		friends:step(0.1, 0.1, hostile)
		expect(friends.shots:getCount()).toBe(2)
		for _, shot in friends.shots.shots do
			expect(shot.dx).toBeNear(math.cos(1))
			expect(math.abs(shot.dz)).toBeNear(math.sin(1))
			expect(shot.damage).toBe(6)
		end
	end)
end)
