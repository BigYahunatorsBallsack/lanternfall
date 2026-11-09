--!strict
-- Arsenal, afflictions and performance regressions; original weapon parity is in BrotatoWeapons.spec.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Services = game:GetService("ServerScriptService").Server.Services
local World = require(Services.EnemySim.World)
local Arsenal = require(Services.WeaponService.Arsenal)
local EnemyKinds = require(Shared.Util.EnemyKinds)

local Sim = Config.Simulation
local STEP = 1 / Sim.tickRate
local HALF_X = Config.Map.arena.width / 2
local HALF_Z = Config.Map.arena.depth / 2
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
		minX = -HALF_X,
		maxX = HALF_X,
		minZ = -HALF_Z,
		maxZ = HALF_Z,
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

-- Spawns an enemy `distance` studs from the origin in direction `degrees`.
local function spawnAt(scene, kindId, distance, degrees, hp)
	local angle = math.rad(degrees)
	return spawn(scene, kindId, math.cos(angle) * distance, math.sin(angle) * distance, hp)
end

describe("Arsenal", function()
	it("gives weapons, copies of one too, up to the slot limit, each with its own uid", function()
		local some =
			{ OrbitBlades = behaviors.OrbitBlades, SparkBolt = behaviors.SparkBolt, Shockwave = behaviors.Shockwave }
		local scene = setup({ maxWeapons = 3, behaviors = some })
		local arsenal = scene.arsenal
		local ok, _, first = arsenal:addWeapon(OWNER, "OrbitBlades", 0)
		expect(ok).toBe(true)
		local _, _, second = arsenal:addWeapon(OWNER, "OrbitBlades", 0, 2)
		expect(second ~= first).toBe(true)
		expect(arsenal:getWeapon(OWNER, second).tier).toBe(2)
		expect(select(2, arsenal:addWeapon(OWNER, "ChainLightning", 0))).toBe("NotImplemented") -- no behavior here
		expect(select(2, arsenal:addWeapon(OWNER, "Nope", 0))).toBe("UnknownWeapon")
		expect(select(2, arsenal:addWeapon(OWNER, "SparkBolt", 0, 5))).toBe("BadTier")
		expect(arsenal:addWeapon(OWNER, "SparkBolt", 0)).toBe(true)
		expect(select(2, arsenal:addWeapon(OWNER, "Shockwave", 0))).toBe("SlotsFull")
		expect(select(2, arsenal:addWeapon(2, "Shockwave", 0))).toBe("NotParticipant")
		expect(#arsenal:getWeapons(OWNER)).toBe(3)
		expect(arsenal:removeWeapon(OWNER, first)).toBe(true)
		expect(arsenal:getWeapons(OWNER)[1].uid).toBe(second)
	end)

	it("lists the weapons that have a behavior", function()
		local implemented = setup().arsenal:getImplemented()
		expect(#implemented).toBe(81)
		for _, id in implemented do
			expect(Config.Weapons[id] ~= nil).toBe(true)
		end
	end)

	it("raises tiers up to the max and recomputes the stats", function()
		local scene = setup()
		local uid = give(scene, "SparkBolt")
		local weapon = scene.arsenal:getWeapons(OWNER)[1]
		expect(weapon.stats.count).toBe(1)
		expect(scene.arsenal:raiseTier(OWNER, uid)).toBe(true)
		expect(weapon.stats.burnDamage).toBe(5)
		for _ = 3, Config.Player.maxWeaponTier do
			scene.arsenal:raiseTier(OWNER, uid)
		end
		expect(weapon.tier).toBe(Config.Player.maxWeaponTier)
		expect(select(2, scene.arsenal:raiseTier(OWNER, uid))).toBe("MaxTier")
		expect(select(2, scene.arsenal:raiseTier(OWNER, uid + 99))).toBe("NotOwned")
	end)

	it("merges two copies of the same tier into one of the next tier", function()
		local scene = setup()
		local a = give(scene, "SparkBolt")
		local other = give(scene, "OrbitBlades")
		expect(select(2, scene.arsenal:merge(OWNER, a))).toBe("NoPartner")
		local higher = give(scene, "SparkBolt", 2)
		expect(scene.arsenal:findMergePartner(OWNER, a)).toBe(nil) -- different tier
		local b = give(scene, "SparkBolt")
		expect(scene.arsenal:findMergePartner(OWNER, a).uid).toBe(b)
		scene.arsenal:getWeapon(OWNER, b).kills = 3
		expect(scene.arsenal:merge(OWNER, a)).toBe(true)
		expect(scene.arsenal:getWeapon(OWNER, b)).toBe(nil)
		local merged = scene.arsenal:getWeapon(OWNER, a)
		expect(merged.tier).toBe(2)
		expect(merged.kills).toBe(3)
		expect(merged.stats.burnDamage).toBe(5)
		expect(scene.arsenal:merge(OWNER, higher)).toBe(true) -- now a has a partner of tier II
		expect(scene.arsenal:getWeapon(OWNER, higher).tier).toBe(3)
		expect(#scene.arsenal:getWeapons(OWNER)).toBe(2)
		expect(scene.arsenal:getWeapon(OWNER, other).tier).toBe(1)

		local top = setup()
		local x = give(top, "OrbitBlades", Config.Player.maxWeaponTier)
		give(top, "OrbitBlades", Config.Player.maxWeaponTier)
		expect(select(2, top.arsenal:merge(OWNER, x))).toBe("NoPartner") -- tier IV is the end
	end)

	it("applies the owner's stats to every weapon", function()
		local scene = setup({ bonuses = { attackSpeed = 10 } }) -- +10 % Attack Speed
		give(scene, "SparkBolt")
		local weapon = scene.arsenal:getWeapons(OWNER)[1]
		expect(weapon.stats.cooldown).toBeNear(W.SparkBolt.base.cooldown / 1.1)
		scene.arsenal:setBonuses(OWNER, { damage = 50 })
		expect(weapon.stats.cooldown).toBeNear(W.SparkBolt.base.cooldown)
		expect(weapon.stats.damage).toBeNear(W.SparkBolt.base.damage * 1.5)
	end)

	it("evolves only a max-tier weapon into its own evolution", function()
		local scene = setup()
		local uid = give(scene, "SparkBolt", 4)
		expect(scene.arsenal:evolve(OWNER, uid, "Starfire")).toBe(false)
		expect(next(Config.Evolutions)).toBe(nil)
	end)

	it("heals the owner through life steal on hits", function()
		local steals = 0
		local scene = setup({
			bonuses = { lifeSteal = 100 },
			onLifeSteal = function(ownerId)
				expect(ownerId).toBe(OWNER)
				steals += 1
			end,
		})
		give(scene, "SparkBolt")
		spawn(scene, "Brute", 10, 0)
		run(scene, 0.5)
		expect(steals).toBe(1)
	end)

	it("deals more damage to elites with Damage vs Elites and reports every hit", function()
		local hits = {}
		local scene = setup({
			bonuses = { eliteDamage = 50 },
			onHit = function(ownerId, weapon, id, dealt, crit, killed, source)
				expect(ownerId).toBe(OWNER)
				table.insert(hits, { id = id, dealt = dealt, crit = crit, killed = killed, weapon = weapon.id })
				expect(source).toBe("Weapon")
			end,
		})
		give(scene, "SparkBolt")
		local elite = spawn(scene, "Brute", 10, 0)
		scene.elites[elite] = true
		run(scene, 0.5)
		local damage = W.SparkBolt.base.damage
		expect(lost(scene, elite, Types.Brute.hp)).toBeNear(damage * 1.5)
		expect(#hits).toBe(1)
		expect(hits[1].id).toBe(elite)
		expect(hits[1].dealt).toBeNear(damage * 1.5)
		expect(hits[1].crit).toBe(false)
		expect(hits[1].killed).toBe(false)
		expect(hits[1].weapon).toBe("SparkBolt")
	end)

	it("rolls crits on hits", function()
		local scene = setup({ bonuses = { critChance = 100 } })
		give(scene, "SparkBolt")
		local brute = spawn(scene, "Brute", 10, 0)
		run(scene, 0.5)
		local crit = W.SparkBolt.base.damage * W.SparkBolt.base.critDamage -- each weapon its own multiplier (B5)
		expect(lost(scene, brute, Types.Brute.hp)).toBeNear(crit)
		local stats = scene.arsenal:getDamageStats(OWNER).SparkBolt
		expect(stats.damage).toBeNear(crit)
		expect(stats.kills).toBe(0)
	end)

	it("knocks enemies straight away from the owner, resistant ones less and elites not at all", function()
		for _, kindId in { "Shadeling", "Brute" } do
			local scene = setup({ bonuses = { knockback = 20 } })
			give(scene, "ThornTrail")
			local id = spawn(scene, kindId, 10, 0, TOUGH)
			run(scene, STEP)
			local x = scene.world:getPosition(id)
			local share = World.knockbackShare(Types[kindId])
			expect(x).toBeNear(10 + 22 * Config.Combat.knockback.studsPerPoint * share)
		end
	end)

	it("bounds attack catch-up per simulation step", function()
		local scene = setup({ bonuses = { attackSpeed = 100000 } })
		give(scene, "SparkBolt")
		spawn(scene, "Brute", 10, 0, TOUGH)
		run(scene, 1)
		local fired = #effectsOf(scene, "Fire")
		expect(fired >= 50 and fired <= 65).toBe(true)
	end)
end)

describe("afflictions", function()
	it("burns an enemy from an item effect for its ticks, without stacking", function()
		local hits = {}
		local scene = setup({
			bonuses = { elementalDamage = 2 },
			onHit = function(_, weapon, id, dealt, crit, killed, source)
				table.insert(hits, { weapon = weapon, id = id, dealt = dealt, crit = crit, source = source })
			end,
		})
		local enemy = spawn(scene, "Brute", 30, 0, TOUGH)
		scene.arsenal:queueBurn(OWNER, enemy, 1, { elementalDamage = 1 }, 3)
		run(scene, STEP)
		expect(scene.arsenal:isBurning(enemy)).toBe(true)
		expect(select(2, scene.world:getStatus(enemy))).toBe(true)
		scene.arsenal:queueBurn(OWNER, enemy, 1, { elementalDamage = 1 }, 2) -- weaker: no change
		run(scene, 5)
		expect(lost(scene, enemy, TOUGH)).toBeNear(3 * 3) -- 3 ticks of 1 + 2 Elemental
		expect(#hits).toBe(3)
		expect(hits[1].source).toBe("Burn")
		expect(hits[1].crit).toBe(false)
		expect(hits[1].weapon).toBe(nil)
		expect(scene.arsenal:isBurning(enemy)).toBe(false)
		expect(select(2, scene.world:getStatus(enemy))).toBe(false)
	end)

	it("ticks faster with Burning Speed and spreads to the nearest enemy with Burning Spread", function()
		local scene = setup({ bonuses = { burnSpeed = 50, burnSpread = 1 } })
		local enemy = spawn(scene, "Brute", 30, 0, TOUGH)
		local near = spawn(scene, "Brute", 30, 6, TOUGH)
		local far = spawn(scene, "Brute", 30, 30, TOUGH)
		scene.arsenal:queueBurn(OWNER, enemy, 4, nil, 2)
		run(scene, STEP)
		run(scene, 0.5)
		expect(lost(scene, enemy, TOUGH)).toBeNear(4) -- first tick after 0.5 s instead of 1 s
		expect(scene.arsenal:isBurning(near)).toBe(true)
		expect(scene.arsenal:isBurning(far)).toBe(false)
		run(scene, 2)
		expect(lost(scene, near, TOUGH)).toBeNear(8)
	end)

	it("blows up around a point from an item effect, with Explosion Size and Damage", function()
		local hits = {}
		local scene = setup({
			bonuses = { explosionSize = 100, explosionDamage = 50, meleeDamage = 4 },
			onHit = function(_, _, id, dealt, _, _, source)
				table.insert(hits, { id = id, dealt = dealt, source = source })
			end,
		})
		local radius = Config.Combat.explosion.baseRadius * 0.5 * 2
		local inside = spawn(scene, "Brute", 30 + radius - 1, 0, TOUGH)
		local outside = spawn(scene, "Brute", 30 + radius + Types.Brute.radius + 1, 0, TOUGH)
		scene.arsenal:queueExplosion(OWNER, 30, 0, 10, { meleeDamage = 0.5 }, 0.5)
		run(scene, STEP)
		expect(lost(scene, inside, TOUGH)).toBeNear((10 + 2) * 1.5)
		expect(lost(scene, outside, TOUGH)).toBe(0)
		expect(hits[1].source).toBe("Explosion")
		local blasts = effectsOf(scene, "Blast")
		expect(#blasts).toBe(1)
		expect(blasts[1].weapon).toBe("Explosion")
		expect(blasts[1].radius).toBeNear(radius)
	end)

	it("puts out every burn when the combat is cleared", function()
		local scene = setup()
		local enemy = spawn(scene, "Brute", 30, 0, TOUGH)
		scene.arsenal:queueBurn(OWNER, enemy, 5, nil, 5)
		run(scene, STEP)
		scene.arsenal:clearCombat()
		run(scene, 3)
		expect(lost(scene, enemy, TOUGH)).toBe(0)
	end)
end)

describe("weapon budget", function()
	it("steps 4 players with six max-tier weapons each among 140 enemies within the 4 ms step budget", function()
		local scene = setup()
		local owners = { { -10, 0 }, { 10, 0 }, { 0, 15 }, { 30, -20 } }
		local implemented = scene.arsenal:getImplemented()
		for id = 1, #owners do
			scene.arsenal:addOwner(id)
			for k = 0, Config.Player.maxWeapons - 1 do -- each player a different set, together all six
				local weaponId = implemented[(id + k) % #implemented + 1]
				local _, _, uid = scene.arsenal:addWeapon(id, weaponId, scene.now, Config.Player.maxWeaponTier)
				for evolutionId, evolution in Config.Evolutions do
					if evolution.weapon == weaponId then
						scene.arsenal:evolve(id, uid, evolutionId) -- evolved weapons do the most work
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
			`  enemies + 24 max-tier weapons: {string.format("%.3f", total)} ms, weapons alone {string.format(
				"%.3f",
				weapons
			)} ms`
		)
		expect(total < Sim.budget.stepMilliseconds).toBe(true)
	end)
end)
