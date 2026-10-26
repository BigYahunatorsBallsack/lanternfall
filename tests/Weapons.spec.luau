-- Unit tests for the weapon framework (WeaponService/Arsenal) and the prototype weapons (WeaponService/Behaviors)
-- against a real enemy World: slots and levels, targeting, hits, pierce, cooldowns, knockback, crits, down owners,
-- all six weapons and both evolutions, and the step budget with four fully armed players among 140 enemies.

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
	local scene = { world = world, kills = {}, now = 1000, x = 0, z = 0 }
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
		},
		behaviors = options.behaviors or behaviors,
		maxWeapons = options.maxWeapons or Config.Player.maxWeapons,
		maxLevel = Config.Player.maxItemLevel,
		critChance = options.critChance or 0,
		critMultiplier = Config.Player.critMultiplier,
		minCooldown = Config.Player.minWeaponCooldown,
		sweepStep = Sim.weaponSweepStep,
		random = function()
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

local function give(scene, weaponId, level)
	local ok, reason = scene.arsenal:addWeapon(OWNER, weaponId, scene.now)
	assert(ok, reason)
	for _ = 2, level or 1 do
		assert(scene.arsenal:levelUp(OWNER, weaponId))
	end
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

-- Spawns an enemy `distance` studs from the origin in direction `degrees`.
local function spawnAt(scene, kindId, distance, degrees, hp)
	local angle = math.rad(degrees)
	return spawn(scene, kindId, math.cos(angle) * distance, math.sin(angle) * distance, hp)
end

describe("Arsenal", function()
	it("gives each weapon once, up to the slot limit", function()
		local some =
			{ OrbitBlades = behaviors.OrbitBlades, SparkBolt = behaviors.SparkBolt, Shockwave = behaviors.Shockwave }
		local scene = setup({ maxWeapons = 2, behaviors = some })
		local arsenal = scene.arsenal
		expect(arsenal:addWeapon(OWNER, "OrbitBlades", 0)).toBe(true)
		expect(select(2, arsenal:addWeapon(OWNER, "OrbitBlades", 0))).toBe("AlreadyOwned")
		expect(select(2, arsenal:addWeapon(OWNER, "ChainLightning", 0))).toBe("NotImplemented") -- no behavior here
		expect(select(2, arsenal:addWeapon(OWNER, "Nope", 0))).toBe("UnknownWeapon")
		expect(arsenal:addWeapon(OWNER, "SparkBolt", 0)).toBe(true)
		expect(select(2, arsenal:addWeapon(OWNER, "Shockwave", 0))).toBe("SlotsFull")
		expect(select(2, arsenal:addWeapon(2, "Shockwave", 0))).toBe("NotParticipant")
		expect(#arsenal:getWeapons(OWNER)).toBe(2)
		expect(arsenal:removeWeapon(OWNER, "OrbitBlades")).toBe(true)
		expect(arsenal:getWeapons(OWNER)[1].id).toBe("SparkBolt")
	end)

	it("lists the weapons that have a behavior", function()
		local implemented = setup().arsenal:getImplemented()
		expect(table.concat(implemented, ",")).toBe(
			"BoomerangAxe,ChainLightning,OrbitBlades,Shockwave,SparkBolt,ThornTrail"
		)
	end)

	it("levels up to the max and recomputes the stats", function()
		local scene = setup()
		give(scene, "SparkBolt")
		local weapon = scene.arsenal:getWeapons(OWNER)[1]
		expect(weapon.stats.count).toBe(1)
		expect(scene.arsenal:levelUp(OWNER, "SparkBolt")).toBe(true)
		expect(weapon.stats.count).toBe(2)
		for _ = 3, Config.Player.maxItemLevel do
			scene.arsenal:levelUp(OWNER, "SparkBolt")
		end
		expect(weapon.level).toBe(Config.Player.maxItemLevel)
		expect(select(2, scene.arsenal:levelUp(OWNER, "SparkBolt"))).toBe("MaxLevel")
		expect(select(2, scene.arsenal:levelUp(OWNER, "Shockwave"))).toBe("NotOwned")
	end)

	it("applies owner bonuses to every weapon", function()
		local bonus = Config.Classes.SparkMage.bonus -- -10 % cooldown
		local scene = setup({ bonuses = { [bonus.stat] = bonus.value } })
		give(scene, "SparkBolt")
		local weapon = scene.arsenal:getWeapons(OWNER)[1]
		expect(weapon.stats.cooldown).toBeNear(W.SparkBolt.base.cooldown * (1 + bonus.value))
		scene.arsenal:setBonuses(OWNER, { damage = 0.5 })
		expect(weapon.stats.cooldown).toBeNear(W.SparkBolt.base.cooldown)
		expect(weapon.stats.damage).toBeNear(W.SparkBolt.base.damage * 1.5)
	end)

	it("evolves only a max-level weapon into its own evolution", function()
		local scene = setup()
		give(scene, "OrbitBlades")
		expect(select(2, scene.arsenal:evolve(OWNER, "OrbitBlades", "BladeStorm"))).toBe("NotMaxLevel")
		for _ = 2, Config.Player.maxItemLevel do
			scene.arsenal:levelUp(OWNER, "OrbitBlades")
		end
		expect(select(2, scene.arsenal:evolve(OWNER, "OrbitBlades", "Starfire"))).toBe("WrongEvolution")
		expect(scene.arsenal:evolve(OWNER, "OrbitBlades", "BladeStorm")).toBe(true)
		local weapon = scene.arsenal:getWeapons(OWNER)[1]
		expect(weapon.evolution).toBe("BladeStorm")
		expect(weapon.stats.count).toBe(Config.Evolutions.BladeStorm.stats.count)
		expect(select(2, scene.arsenal:evolve(OWNER, "OrbitBlades", "BladeStorm"))).toBe("AlreadyEvolved")
	end)

	it("rolls crits on hits", function()
		local scene = setup({ critChance = 1 })
		give(scene, "SparkBolt")
		local brute = spawn(scene, "Brute", 10, 0)
		run(scene, 0.5)
		expect(lost(scene, brute, Types.Brute.hp)).toBeNear(W.SparkBolt.base.damage * Config.Player.critMultiplier)
		local stats = scene.arsenal:getDamageStats(OWNER).SparkBolt
		expect(stats.damage).toBeNear(W.SparkBolt.base.damage * Config.Player.critMultiplier)
		expect(stats.kills).toBe(0)
	end)
end)

describe("Orbit Blades", function()
	local base = W.OrbitBlades.base
	local enemyRadius = Types.Shadeling.radius
	local reach = base.radius + base.bladeWidth / 2 + enemyRadius

	it("hits enemies around the owner, also those touching them, about once per pass", function()
		local scene = setup()
		give(scene, "OrbitBlades")
		local touching = spawnAt(scene, "Shadeling", enemyRadius + Sim.playerRadius, 0)
		local middle = spawnAt(scene, "Shadeling", 5, 90, TOUGH)
		local edge = spawnAt(scene, "Shadeling", reach - 0.2, 180, TOUGH)
		local outside = spawnAt(scene, "Shadeling", reach + 0.5, 270, TOUGH)
		-- one full turn: every angle is passed once per blade
		run(scene, 360 / base.rotationSpeed + 0.05)
		expect(scene.world:isAlive(touching)).toBe(false) -- 12 damage beats a Shadeling's 10 HP
		expect(lost(scene, middle, TOUGH)).toBeNear(base.damage * base.count)
		expect(lost(scene, edge, TOUGH)).toBeNear(base.damage * base.count)
		expect(lost(scene, outside, TOUGH)).toBe(0)
		expect(#scene.effects).toBe(0) -- clients draw the blades themselves
	end)

	it("hits the same enemy at most once per hit cooldown, however many blades pass", function()
		local scene = setup()
		give(scene, "OrbitBlades", Config.Player.maxItemLevel)
		scene.arsenal:evolve(OWNER, "OrbitBlades", "BladeStorm") -- 8 blades: one passes every 0.25 s
		local weapon = scene.arsenal:getWeapons(OWNER)[1]
		local target = spawnAt(scene, "Shadeling", 5, 45, TOUGH)
		local seconds = 2
		run(scene, seconds)
		local hits = lost(scene, target, TOUGH) / weapon.stats.damage
		expect(math.abs(hits - math.round(hits)) < 1e-6).toBe(true)
		expect(hits >= seconds / base.hitCooldownPerEnemy - 1).toBe(true)
		expect(hits <= seconds / base.hitCooldownPerEnemy + 1).toBe(true)
	end)

	it("follows the owner and rests while they are down", function()
		local scene = setup()
		give(scene, "OrbitBlades")
		local target = spawn(scene, "Shadeling", 40 + 5, 0, TOUGH)
		run(scene, 2.1)
		expect(lost(scene, target, TOUGH)).toBe(0)
		scene.x = 40
		run(scene, 2.1, true)
		expect(lost(scene, target, TOUGH)).toBe(0)
		run(scene, 2.1)
		expect(lost(scene, target, TOUGH) > 0).toBe(true)
	end)
end)

describe("Spark Bolt", function()
	local base = W.SparkBolt.base

	it("shoots the nearest enemy and kills a Shadeling with one hit", function()
		local scene = setup()
		give(scene, "SparkBolt")
		local near = spawn(scene, "Shadeling", 20, 0)
		local far = spawn(scene, "Shadeling", -30, 0)
		run(scene, 0.6)
		expect(scene.world:isAlive(near)).toBe(false)
		expect(scene.world:isAlive(far)).toBe(true)
		local fired = effectsOf(scene, "Fire")
		expect(#fired).toBe(1)
		expect(fired[1].weapon).toBe("SparkBolt")
		expect(fired[1].userId).toBe(OWNER)
		expect(fired[1].dx).toBeNear(1)
		expect(fired[1].speed).toBe(base.projectileSpeed)
		expect(#effectsOf(scene, "End")).toBe(0) -- pierce 1: it flies on after the kill
	end)

	it("flies through one enemy and stops at the next", function()
		local scene = setup()
		give(scene, "SparkBolt")
		local first = spawn(scene, "Brute", 10, 0, TOUGH)
		local second = spawn(scene, "Brute", 16, 0, TOUGH)
		local third = spawn(scene, "Brute", 22, 0, TOUGH)
		run(scene, 0.8) -- one shot (cooldown 0.9 s)
		expect(lost(scene, first, TOUGH)).toBeNear(base.damage)
		expect(lost(scene, second, TOUGH)).toBeNear(base.damage)
		expect(lost(scene, third, TOUGH)).toBe(0)
		local ended = effectsOf(scene, "End")
		expect(#ended).toBe(1)
		expect(ended[1].id).toBe(effectsOf(scene, "Fire")[1].id)
		expect(ended[1].distance > 10 and ended[1].distance <= 16).toBe(true) -- stops inside the second Brute
	end)

	it("waits for an enemy in range and keeps its cooldown", function()
		local scene = setup()
		give(scene, "SparkBolt")
		local far = spawn(scene, "Brute", base.range + 10, 0, TOUGH)
		run(scene, 1)
		expect(#scene.effects).toBe(0)
		expect(lost(scene, far, TOUGH)).toBe(0)
		spawn(scene, "Brute", 0, 10, TOUGH)
		run(scene, 2 * base.cooldown + 0.05)
		expect(#effectsOf(scene, "Fire")).toBe(3) -- right away, after one and after two cooldowns
	end)

	it("shoots one bolt per target from level 2 and fans out without enough targets", function()
		local scene = setup()
		give(scene, "SparkBolt", 2)
		local a = spawn(scene, "Shadeling", 20, 0)
		local b = spawn(scene, "Shadeling", 0, 25)
		run(scene, 0.6)
		expect(scene.world:isAlive(a)).toBe(false)
		expect(scene.world:isAlive(b)).toBe(false)

		local single = setup()
		give(single, "SparkBolt", 2)
		spawn(single, "Brute", 20, 0, TOUGH)
		run(single, STEP)
		local fired = effectsOf(single, "Fire")
		expect(#fired).toBe(2)
		local angle = math.deg(math.acos(fired[1].dx * fired[2].dx + fired[1].dz * fired[2].dz))
		expect(angle).toBeNear(base.spreadDegrees, 1e-3)
	end)

	it("lets bolts in flight hit even after the owner went down", function()
		local scene = setup()
		give(scene, "SparkBolt")
		local target = spawn(scene, "Brute", 30, 0, TOUGH)
		run(scene, STEP)
		expect(#effectsOf(scene, "Fire")).toBe(1)
		run(scene, 1.5, true)
		expect(lost(scene, target, TOUGH)).toBeNear(base.damage)
		expect(#effectsOf(scene, "Fire")).toBe(1) -- but no new shots
	end)
end)

describe("Shockwave", function()
	local base = W.Shockwave.base

	it("blasts every enemy in its radius and pushes the survivors away, heavy ones less", function()
		local scene = setup()
		give(scene, "Shockwave")
		local light = spawn(scene, "Shadeling", 6, 0, TOUGH)
		local heavy = spawn(scene, "Brute", -9, 0, TOUGH)
		local outside = spawn(scene, "Shadeling", 0, base.radius + Types.Shadeling.radius + 0.5, TOUGH)
		run(scene, STEP)
		expect(lost(scene, light, TOUGH)).toBeNear(base.damage)
		expect(lost(scene, heavy, TOUGH)).toBeNear(base.damage)
		expect(lost(scene, outside, TOUGH)).toBe(0)
		expect(scene.world:getPosition(light)).toBeNear(6 + base.knockback)
		expect(scene.world:getPosition(heavy)).toBeNear(-9 - base.knockback / Types.Brute.mass)
		local pulses = effectsOf(scene, "Pulse")
		expect(#pulses).toBe(1)
		expect(pulses[1].radius).toBe(base.radius)
	end)

	it("waits for an enemy in the radius and then keeps its cooldown", function()
		local scene = setup()
		give(scene, "Shockwave")
		run(scene, 1)
		expect(#scene.effects).toBe(0)
		spawn(scene, "Brute", 4, 0, TOUGH)
		run(scene, base.cooldown - 0.1)
		expect(#effectsOf(scene, "Pulse")).toBe(1)
		run(scene, 0.2)
		expect(#effectsOf(scene, "Pulse")).toBe(2)
	end)
end)

describe("Chain Lightning", function()
	local base = W.ChainLightning.base

	it("strikes the nearest enemy in range and jumps on to the nearest ones not hit yet", function()
		local scene = setup()
		give(scene, "ChainLightning")
		local first = spawn(scene, "Brute", 10, 0, TOUGH)
		local second = spawn(scene, "Brute", 18, 0, TOUGH)
		local third = spawn(scene, "Brute", 18, 9, TOUGH)
		local fourth = spawn(scene, "Brute", 10, 9, TOUGH) -- in reach, but three hits are used up
		local far = spawn(scene, "Brute", 18 + base.jumpRange + 5, 30, TOUGH)
		run(scene, STEP)
		expect(lost(scene, first, TOUGH)).toBeNear(base.damage)
		expect(lost(scene, second, TOUGH)).toBeNear(base.damage)
		expect(lost(scene, third, TOUGH)).toBeNear(base.damage)
		expect(lost(scene, fourth, TOUGH)).toBe(0)
		expect(lost(scene, far, TOUGH)).toBe(0)
		local chains = effectsOf(scene, "Chain")
		expect(#chains).toBe(1)
		expect(#chains[1].points).toBe(2 * (1 + base.jumps)) -- the owner plus every hit enemy
		expect(chains[1].points[3]).toBeNear(10)
	end)

	it("stops early without a next enemy in jump range and gains a jump per level", function()
		local scene = setup()
		give(scene, "ChainLightning", 2)
		local near = spawn(scene, "Brute", 10, 0, TOUGH)
		local alone = spawn(scene, "Brute", 10 + base.jumpRange + 5, 0, TOUGH)
		run(scene, STEP)
		expect(lost(scene, near, TOUGH) > 0).toBe(true)
		expect(lost(scene, alone, TOUGH)).toBe(0)
		expect(scene.arsenal:getWeapons(OWNER)[1].stats.jumps).toBe(base.jumps + 1)
	end)

	it("waits for an enemy in range and then keeps its cooldown", function()
		local scene = setup()
		give(scene, "ChainLightning")
		spawn(scene, "Brute", base.range + 5, 0, TOUGH)
		run(scene, 1)
		expect(#scene.effects).toBe(0)
		spawn(scene, "Brute", 0, 8, TOUGH)
		run(scene, base.cooldown + 0.05)
		expect(#effectsOf(scene, "Chain")).toBe(2)
	end)
end)

describe("Thorn Trail", function()
	local base = W.ThornTrail.base

	it("drops patches behind a moving owner that hurt every tick until they are gone", function()
		local scene = setup()
		give(scene, "ThornTrail")
		local behind = spawn(scene, "Brute", 0, 0, TOUGH)
		for step = 1, 10 do
			scene.x = step * 1 -- 15 studs/s, like a running player
			run(scene, STEP)
		end
		local drops = effectsOf(scene, "Drop")
		expect(#drops >= 4 and #drops <= 6).toBe(true) -- one every dropSpacing studs
		expect(drops[1].radius).toBe(base.radius)
		expect(drops[1].duration).toBe(base.duration)
		scene.x = 60 -- far away, so only the old patches can hit
		run(scene, base.duration + 0.5)
		local ticks = lost(scene, behind, TOUGH) / base.damage
		expect(math.abs(ticks - math.round(ticks)) < 1e-6).toBe(true)
		expect(ticks >= base.duration / base.tickInterval - 1).toBe(true)
		expect(ticks <= base.duration / base.tickInterval + 1).toBe(true)
		local before = lost(scene, behind, TOUGH)
		run(scene, 1)
		expect(lost(scene, behind, TOUGH)).toBe(before) -- patches near it are gone
	end)

	it("hits an enemy on several patches once per tick and keeps a patch under a standing owner", function()
		local scene = setup()
		give(scene, "ThornTrail")
		local target = spawn(scene, "Brute", 1, 0, TOUGH)
		run(scene, 2 * base.duration - 0.05)
		expect(lost(scene, target, TOUGH)).toBeNear(
			base.damage * math.floor((2 * base.duration - 0.05) / base.tickInterval)
		)
		expect(#effectsOf(scene, "Drop")).toBe(2) -- a new patch when the old one is gone
	end)

	it("drops nothing while the owner is down", function()
		local scene = setup()
		give(scene, "ThornTrail")
		run(scene, 3 * base.duration, true)
		expect(#scene.effects).toBe(0)
	end)
end)

describe("Boomerang Axe", function()
	local base = W.BoomerangAxe.base

	it("flies out through everything, turns at its range and hits again on the way back", function()
		local scene = setup()
		give(scene, "BoomerangAxe")
		local a = spawn(scene, "Brute", 6, 0, TOUGH)
		local b = spawn(scene, "Brute", 12, 0, TOUGH)
		local c = spawn(scene, "Brute", 17, 0, TOUGH)
		local beyond = spawn(scene, "Brute", base.range + 6, 0, TOUGH)
		run(scene, 2 * base.range / base.projectileSpeed + 0.3)
		for _, id in { a, b, c } do
			expect(lost(scene, id, TOUGH)).toBeNear(2 * base.damage)
		end
		expect(lost(scene, beyond, TOUGH)).toBe(0)
		local ended = effectsOf(scene, "End")
		expect(#effectsOf(scene, "Fire")).toBe(1)
		expect(#ended).toBe(1)
		expect(math.abs(ended[1].x) <= base.catchRadius + 0.1).toBe(true) -- caught at the owner
	end)

	it("comes back to where the owner moved and throws one axe per target from level 3", function()
		local scene = setup()
		give(scene, "BoomerangAxe", 3)
		spawn(scene, "Brute", 10, 0, TOUGH)
		spawn(scene, "Brute", 0, -10, TOUGH)
		run(scene, STEP)
		expect(#effectsOf(scene, "Fire")).toBe(2)
		scene.x, scene.z = -10, 10
		run(scene, 1.6)
		local ended = effectsOf(scene, "End")
		expect(#ended).toBe(2)
		for _, effect in ended do
			expect(math.sqrt((effect.x + 10) ^ 2 + (effect.z - 10) ^ 2) <= base.catchRadius + 0.1).toBe(true)
		end
	end)

	it("vanishes after maxFlightSeconds if it cannot catch up", function()
		local scene = setup()
		give(scene, "BoomerangAxe")
		spawn(scene, "Brute", 10, 0, TOUGH)
		run(scene, STEP)
		local fired = scene.now
		local ended = nil
		for _ = 1, math.ceil((base.maxFlightSeconds + 1) / STEP) do
			scene.x -= base.projectileSpeed * STEP * 1.5 -- runs away faster than the axe
			run(scene, STEP)
			ended = ended or effectsOf(scene, "End")[1]
		end
		expect(ended ~= nil).toBe(true)
		expect(ended.at - fired).toBeNear(base.maxFlightSeconds, STEP * 1.5)
	end)
end)

describe("evolutions", function()
	it("Blade Storm spins 8 longer blades with double damage", function()
		local scene = setup()
		give(scene, "OrbitBlades", Config.Player.maxItemLevel)
		local weapon = scene.arsenal:getWeapons(OWNER)[1]
		local before = weapon.stats.damage
		expect(scene.arsenal:evolve(OWNER, "OrbitBlades", "BladeStorm")).toBe(true)
		expect(weapon.stats.count).toBe(8)
		expect(weapon.stats.radius).toBe(10)
		expect(weapon.stats.damage).toBeNear(2 * before)
		local far = spawnAt(scene, "Shadeling", 9, 30, TOUGH) -- beyond the normal 7 studs
		run(scene, 0.4)
		expect(lost(scene, far, TOUGH) > 0).toBe(true)
	end)

	it("Starfire bolts explode and hurt the enemies around every hit", function()
		local evolution = Config.Evolutions.Starfire.stats
		local scene = setup()
		give(scene, "SparkBolt", Config.Player.maxItemLevel)
		scene.arsenal:evolve(OWNER, "SparkBolt", "Starfire")
		local weapon = scene.arsenal:getWeapons(OWNER)[1]
		weapon.stats.count = 1 -- one bolt, so only the blast can reach the other enemies
		local target = spawn(scene, "Brute", 15, 0, TOUGH)
		local beside = spawn(scene, "Brute", 15, 4, TOUGH) -- off the bolt's path, inside the blast
		local outside = spawn(scene, "Brute", 15, -(evolution.explosionRadius + 3), TOUGH)
		run(scene, STEP)
		run(scene, 0.3)
		expect(lost(scene, target, TOUGH) >= weapon.stats.damage - 1e-6).toBe(true)
		expect(lost(scene, beside, TOUGH) >= weapon.stats.damage * evolution.explosionDamage - 1e-6).toBe(true)
		expect(lost(scene, outside, TOUGH)).toBe(0)
		local blasts = effectsOf(scene, "Blast")
		expect(#blasts >= 1).toBe(true)
		expect(blasts[1].radius).toBe(evolution.explosionRadius)
	end)
end)

describe("weapon budget", function()
	it("steps 4 players with four max-level weapons each among 140 enemies within the 4 ms step budget", function()
		local scene = setup()
		local owners = { { -10, 0 }, { 10, 0 }, { 0, 15 }, { 30, -20 } }
		local implemented = scene.arsenal:getImplemented()
		for id = 1, #owners do
			scene.arsenal:addOwner(id)
			for k = 0, Config.Player.maxWeapons - 1 do -- each player a different set, together all six
				local weaponId = implemented[(id + k) % #implemented + 1]
				scene.arsenal:addWeapon(id, weaponId, scene.now)
				for _ = 2, Config.Player.maxItemLevel do
					scene.arsenal:levelUp(id, weaponId)
				end
				for evolutionId, evolution in Config.Evolutions do
					if evolution.weapon == weaponId then
						scene.arsenal:evolve(id, weaponId, evolutionId) -- evolved weapons do the most work
					end
				end
			end
		end
		local seed = 4242
		local function random()
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		for i = 1, 140 do
			local angle = random() * 2 * math.pi
			local distance = 45 + random() * 15
			local kindId = if i % 5 == 0 then "Brute" elseif i % 5 == 1 then "Spitter" else "Shadeling"
			spawn(scene, kindId, math.cos(angle) * distance, math.sin(angle) * distance, TOUGH)
		end
		local xs, zs = {}, {}
		for index, position in owners do
			xs[index], zs[index] = position[1], position[2]
		end
		local function frame()
			scene.world:step(STEP, xs, zs, #owners)
			scene.now += STEP
			for id, position in owners do
				scene.arsenal:place(id, position[1], position[2], 0, 0)
			end
			local started = os.clock()
			scene.arsenal:step(STEP, scene.now)
			scene.arsenal:drainEffects()
			return os.clock() - started
		end
		for _ = 1, 10 / STEP do
			frame() -- let the crowd form around the players first
		end
		local steps = 150
		local weaponSeconds = 0
		local started = os.clock()
		for _ = 1, steps do
			weaponSeconds += frame()
		end
		for id = 1, #owners do
			for weaponId, stats in scene.arsenal:getDamageStats(id) do
				assert(stats.damage > 0, `{weaponId} of player {id} never hit`) -- the benchmark really fights
			end
		end
		local total = (os.clock() - started) * 1000 / steps
		local weapons = weaponSeconds * 1000 / steps
		print(
			`  enemies + 16 max-level weapons: {string.format("%.3f", total)} ms, weapons alone {string.format(
				"%.3f",
				weapons
			)} ms`
		)
		expect(total < Sim.budget.stepMilliseconds).toBe(true)
	end)
end)
