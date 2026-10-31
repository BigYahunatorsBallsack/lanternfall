-- Playtest after Paket 24 ("no weapon should be useless at the start and others extremely good"): every weapon
-- at tier I against a real World, standing among enemies, so its damage per second can be compared. Shares the
-- setup of tests/WeaponsB7.spec.luau (copied). Prints the table; the checks keep the outliers from coming back.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Services = game:GetService("ServerScriptService").Server.Services
local World = require(Services.EnemySim.World)
local Arsenal = require(Services.WeaponService.Arsenal)

local Sim = Config.Simulation
local STEP = 1 / Sim.tickRate
local HALF = Config.Map.arena.size / 2
local Types = Config.Enemies.types
local W = Config.Weapons
local OWNER = 1
local TOUGH = 1e6 -- HP for enemies that must survive every hit

local behaviors = {}
for _, module in Services.WeaponService.Behaviors:GetChildren() do
	behaviors[module.Name] = require(module)
end

local function newWorld()
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
		obstacles = {},
	})
end

-- An arena with a fresh world, an arsenal around it and one owner at (0, 0).
local function setup(options)
	options = options or {}
	local world = newWorld()
	local scene = { world = world, kills = {}, now = 1000, x = 0, z = 0, elites = {} }
	scene.arsenal = Arsenal.new({
		enemies = {
			queryCircle = function(x, z, radius, out)
				return world:queryRadius(x, z, radius, out)
			end,
			querySegment = function(x0, z0, x1, z1, radius, out)
				return world:querySegment(x0, z0, x1, z1, radius, out)
			end,
			getPosition = function(id)
				return world:getPosition(id)
			end,
			damage = function(id, amount)
				local killed, dealt = world:damage(id, amount)
				if killed then
					table.insert(scene.kills, id)
				end
				return killed, dealt
			end,
			push = function(id, dx, dz)
				world:push(id, dx, dz)
			end,
			isAlive = function(id)
				return world:isAlive(id)
			end,
			isElite = function(id)
				return scene.elites[id] == true
			end,
			slow = function(id, factor, seconds)
				world:slow(id, factor, seconds)
			end,
			setBurning = function(id, on)
				world:setBurning(id, on)
			end,
		},
		behaviors = options.behaviors or behaviors,
		maxWeapons = options.maxWeapons or Config.Player.maxWeapons,
		maxTier = Config.Player.maxWeaponTier,
		critChance = options.critChance or 0,
		critMultiplier = Config.Player.critMultiplier,
		minCooldown = Config.Player.minWeaponCooldown,
		onLifeSteal = options.onLifeSteal,
		onHit = options.onHit,
		sweepStep = Sim.weaponSweepStep,
		random = options.random or function()
			return 0.5
		end,
	})
	scene.arsenal:addOwner(OWNER, options.bonuses)
	scene.effects = {}
	return scene
end

local function spawn(scene, kindId, x, z, hp)
	local kind = Types[kindId]
	return scene.world:spawn(kind, x, z, hp or kind.hp, kind.contactDamage)
end

-- Like EnemySim + WeaponService: enemies step (standing still, no targets), then the weapons. The owner is
-- placed at (scene.x, scene.z) unless `down`.
local function run(scene, seconds, down)
	for _ = 1, math.ceil(seconds / STEP - 1e-9) do
		scene.world:step(STEP, {}, {}, 0)
		scene.now += STEP
		if not down then
			scene.arsenal:place(OWNER, scene.x, scene.z, 0, 0)
		end
		scene.arsenal:step(STEP, scene.now)
		for _, effect in scene.arsenal:drainEffects() do
			table.insert(scene.effects, effect)
		end
	end
end

local function measure(weaponId, bonuses, scenario)
	local scene = setup({ bonuses = bonuses, random = math.random })
	local total = 0
	local kills = 0
	-- wrap damage to count what weapons deal
	local world = scene.world
	local origDamage = world.damage
	world.damage = function(self, id, amount, ...)
		local killed, dealt = origDamage(self, id, amount, ...)
		total += dealt
		if killed then
			kills += 1
		end
		return killed, dealt
	end
	local ok, reason = scene.arsenal:addWeapon(OWNER, weaponId, scene.now, 1)
	assert(ok, reason)
	local hp = if scenario == "swarm" then 40 else 1e6
	local count = if scenario == "single" then 1 elseif scenario == "swarm" then 30 else 12
	local function refill()
		local alive = world.alive
		for k = alive + 1, count do
			local angle = math.random() * math.pi * 2
			local r = if scenario == "single" then 8 else 14 + math.random() * 16
			world:spawn(Types.Shadeling, math.cos(angle) * r, math.sin(angle) * r, hp, 0)
		end
	end
	refill()
	local seconds = 15
	for step = 1, math.ceil(seconds / STEP) do
		world:step(STEP, { 0 }, { 0 }, 1)
		scene.now += STEP
		scene.arsenal:place(OWNER, 0, 0, 0, 0)
		scene.arsenal:step(STEP, scene.now)
		scene.arsenal:drainEffects()
		if scenario == "swarm" and step % 15 == 0 then
			refill()
		end
	end
	return total / seconds, kills / seconds
end

local SKIP = { TithePalm = true, CathedralEngine = true } -- Harvesting weapon; a tier IV-only structure weapon

describe("weapon balance at tier I", function()
	it("keeps every weapon within a band of single target damage and keeps the Rattle Repeater in line", function()
		math.randomseed(3)
		local ids = {}
		for id, w in W do
			if type(w) == "table" and w.base and Config.Shop.weaponPrices[id] and not SKIP[id] then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		for _, id in ids do
			local single = measure(id, {}, "single")
			print(string.format("  %-16s %5.1f damage/s on one enemy", id, single))
			expect(single >= 5 and single <= 30).toBe(true)
		end
		local rattle = measure("RattleRepeater", { rangedDamage = 10, damage = 30 }, "crowd")
		local pistol = measure("WatchmanPistol", { rangedDamage = 10, damage = 30 }, "crowd")
		expect(rattle <= pistol * 1.5).toBe(true)
	end)
end)
