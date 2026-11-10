--!strict
-- High-speed rushes must hit along their swept path, even when both tick endpoints miss the target, and stop at obstacles.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local Sim = Config.Simulation
local kind = Config.Enemies.types.Charger
local step = 1 / Sim.tickRate

local function rushing(obstacles)
	local world = World.new({
		cellSize = Sim.spatialHashCellSize,
		maxEnemies = 140,
		playerRadius = Sim.playerRadius,
		contactMargin = Sim.contactMargin,
		separationStiffness = Sim.separationStiffness,
		separationPasses = Sim.separationPasses,
		obstacleSteerMargin = Sim.obstacleSteerMargin,
		keepDistanceTolerance = Sim.keepDistanceTolerance,
		minX = -80,
		maxX = 80,
		minZ = -80,
		maxZ = 80,
		obstacles = obstacles or {},
	})
	local distance = kind.charge.speed * step
	local id = world:spawn(kind, -distance / 2, 0, kind.hp, kind.contactDamage)
	local i = world.indexOf[id]
	world.modes[i] = World.MODE_RUSH
	world.rushXs[i], world.rushZs[i] = 1, 0
	world.rushLeft[i] = kind.charge.maxDistance
	return world, id, distance
end

describe("Fast rush collisions", function()
	it("hits a player between the endpoints and rushes on through them", function()
		local world, id = rushing()
		local contacts = world:step(step, { 0 }, { 0 }, 1)
		expect(contacts[1]).toBe(kind.contactDamage)
		-- Brotato: enemies do not collide with players, the rush goes on for its whole time
		expect(world:getMode(id)).toBe(World.MODE_RUSH)
		assert((world:getPosition(id) :: number) > 0)
	end)
	it("hits every player along the path", function()
		local world, id = rushing()
		world:setSpeedFactor(id, 3) -- high enemy-speed modifiers still use one continuous collision path
		local contacts = world:step(step, { 0, 7 }, { 0, 0 }, 2)
		expect(contacts[1]).toBe(kind.contactDamage)
		expect(contacts[2]).toBe(kind.contactDamage)
	end)
	it("stops at a thin obstacle between endpoints without hurting the player behind it", function()
		local world, id = rushing({ { x = 0, z = 0, radius = 0.1 } })
		local contacts = world:step(step, { 6 }, { 0 }, 1)
		expect(contacts[1]).toBe(0)
		expect(world:getMode(id)).toBe(World.MODE_RECOVER)
		assert(world:getPosition(id) <= -kind.radius - 0.1 + 1e-5)
	end)
	it("misses a player outside the swept circle", function()
		local world, id, distance = rushing()
		local contacts = world:step(step, { 0 }, { kind.radius + Sim.playerRadius + Sim.contactMargin + 0.1 }, 1)
		expect(contacts[1]).toBe(0)
		expect(world:getMode(id)).toBe(World.MODE_RUSH)
		expect(world:getPosition(id)).toBeNear(distance / 2)
	end)
end)
