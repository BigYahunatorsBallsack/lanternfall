--!strict
-- Unit tests for the weapon framework (WeaponService/Arsenal) and the prototype weapons (WeaponService/Behaviors)
-- against a real enemy World: slots, tiers and merging, targeting, hits, pierce, cooldowns, knockback, crits, down owners,
-- all six weapons and both evolutions, and the step budget with four fully armed players among 140 enemies. Since B5
-- also Brotato's combat: per weapon crits, knockback away from the owner, pierce falloff, bounces, slows, burns
-- (WeaponService/Afflictions), item burns and explosions and the 12 attacks per second cap.

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

-- Gives the owner a weapon of `tier` (default I); returns its uid.
local function give(scene, weaponId, tier)
	local ok, reason, uid = scene.arsenal:addWeapon(OWNER, weaponId, scene.now, tier)
	assert(ok, reason)
	return uid
end

local function lost(scene, id, startHp)
	local hp = scene.world:getHealth(id)
	return startHp - hp
end

local function effectsOf(scene, kind)
	local list = {}
	for _, effect in scene.effects do
		if effect.kind == kind then
			table.insert(list, effect)
		end
	end
	return list
end

describe("B7 weapons", function()
	it("runs every new weapon at each supported tier through real collision", function()
		for id, config in W do
			if not config.minTier then
				continue
			end
			for tier = config.minTier, 4 do
				local scene = setup()
				give(scene, id, tier)
				local enemy = spawn(scene, "Shadeling", 5, 0, TOUGH)
				run(scene, 0.5)
				expect(lost(scene, enemy, TOUGH) > 0).toBe(true)
				expect(#scene.effects > 0).toBe(true)
			end
		end
	end)
	it("sweeps hit multiple forward enemies but not a rear enemy", function()
		local scene = setup()
		give(scene, "WraithHatchet")
		local a = spawn(scene, "Shadeling", 5, 0, TOUGH)
		local b = spawn(scene, "Shadeling", 5, 3, TOUGH)
		local rear = spawn(scene, "Shadeling", -6, 0, TOUGH)
		run(scene, STEP)
		expect(lost(scene, a, TOUGH) > 0).toBe(true)
		expect(lost(scene, b, TOUGH) > 0).toBe(true)
		expect(lost(scene, rear, TOUGH)).toBe(0)
	end)
	it("shotgun pellets fan symmetrically at one target instead of auto-targeting separately", function()
		local scene = setup()
		give(scene, "ScatterBell")
		spawn(scene, "Shadeling", 15, 0, TOUGH)
		spawn(scene, "Shadeling", 0, 16, TOUGH)
		run(scene, STEP)
		local shots = effectsOf(scene, "Fire")
		expect(#shots).toBe(4)
		expect(shots[1].dz < 0 and shots[4].dz > 0).toBe(true)
		for _, shot in shots do
			expect(shot.dx > 0.9).toBe(true)
		end
	end)
	it("magazines count volleys, reload, then resume without consuming ammo on empty aim", function()
		local scene = setup()
		give(scene, "CathedralEngine", 4)
		local weapon = scene.arsenal:getWeapons(OWNER)[1]
		run(scene, 1)
		expect(weapon.state.shots or 0).toBe(0)
		spawn(scene, "Shadeling", 20, 0, TOUGH)
		weapon.stats.knockback = 0
		scene.world:step(STEP, {}, {}, 0)
		for _ = 1, 100 do
			scene.arsenal:place(OWNER, 0, 0, 0, 0)
			scene.arsenal.context.x = 0
			scene.arsenal.context.z = 0
			expect(weapon.behavior.fire(weapon, scene.arsenal.context)).toBe(true)
		end
		expect(weapon.state.reloadLeft).toBeNear(2.04)
		expect(weapon.behavior.fire(weapon, scene.arsenal.context)).toBe(false)
		run(scene, 2.2)
		expect((weapon.state.shots or 0) > 0).toBe(true)
	end)
	it("tier values match the source including scaling, prices and crit progression", function()
		local Stats = require(Services.WeaponService.WeaponStats)
		local ShopRules = require(Services.ShopService.ShopRules)
		local knife = Stats.compute(W.RitualDirk, 4, { meleeDamage = 10 }, nil, 1 / 12)
		expect(knife.damage).toBeNear(33)
		expect(knife.critDamage).toBe(4)
		expect(knife.critChance).toBeNear(0.5)
		local smg = Stats.compute(W.RattleRepeater, 4, { rangedDamage = 10 }, nil, 1 / 12)
		expect(smg.damage).toBeNear(2.5 * (1 + 1 / 3 + 1 / 3 + 1) + 10 * 0.4) -- playtest after Paket 24 (was 16)
		expect(ShopRules.weaponPrice("RitualDirk", 4, 1)).toBe(101)
	end)
	it("shop never promotes a common roll to a restricted weapon", function()
		local ShopRules = require(Services.ShopService.ShopRules)
		local scene = setup()
		for seed = 1, 30 do
			local offers = ShopRules.roll({
				wave = 1,
				luck = 0,
				weapons = scene.arsenal:getImplemented(),
				ownedWeapons = {},
				maxWeapons = 6,
				maxTier = 4,
				ownedItems = {},
				nextId = function()
					return "test"
				end,
				random = function()
					return seed / 31
				end,
			})
			for _, offer in offers do
				if offer.kind == "Weapon" then
					expect(offer.tier >= (W[offer.itemId].minTier or 1)).toBe(true)
					expect(offer.tier).toBe(1)
				end
			end
		end
	end)
	it("flames burn survivors and rocket blasts exclude the direct target", function()
		local scene = setup()
		give(scene, "CinderBreath", 2)
		local enemy = spawn(scene, "Shadeling", 5, 0, TOUGH)
		run(scene, 0.5)
		expect(scene.arsenal:isBurning(enemy)).toBe(true)
		scene = setup()
		give(scene, "MortarLantern", 2)
		local target = spawn(scene, "Shadeling", 5, 0, TOUGH)
		local neighbor = spawn(scene, "Shadeling", 5, 4, TOUGH)
		run(scene, 0.3)
		expect(lost(scene, target, TOUGH)).toBeNear(W.MortarLantern.base.damage)
		expect(lost(scene, neighbor, TOUGH)).toBeNear(W.MortarLantern.base.damage)
	end)
end)
