--!strict
-- Actual pet origin flags distinguish shieldable Catling/Bot shots from Blazemander flames; eligible shots retain their collision offsets.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Combat = require(f.S.CombatService)
local Sim = require(f.S.StructureService.Projectiles)
local Pets = require(f.Shared.Config.Pets)
local Random = require(f.S.RandomService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
local k = f.Config.Enemies.types.Ankylosaurus
local originalCharge, originalEmit, originalRandom = k.nativeCharge, f.Weapons.emitStructureEffect, Random.number
local fires = {}
f.Weapons.emitStructureEffect = function(_, event)
	if event.kind == "Fire" then
		table.insert(fires, event)
	end
end
Random.number = function(channel, player)
	return if channel == "Combat" then 0.5 else originalRandom(channel, player)
end
local function defender()
	Sim.clear()
	Enemy.killAll()
	table.clear(fires)
	k.nativeCharge = require(f.Shared.Config.JungleDeflectCharges).rule
	local id = assert(Enemy.spawn("Ankylosaurus", 20, 0, 1000, 0, nil, nil, 0))
	for _ = 1, 240 do
		f.world.step(1 / 60)
		if Enemy.isProjectileDeflecting(id) then
			break
		end
	end
	expect(Enemy.isProjectileDeflecting(id)).toBe(true)
	local center, radius = Enemy.getHurtGeometry(id)
	return id, assert(center), assert(radius)
end
local function counterRolls()
	Random.number = function(channel, player)
		return if channel == "Combat" then (if player then 0.5 else 0) else originalRandom(channel, player)
	end
end
local function flyCounter(weapon)
	Sim.clear()
	Enemy.killAll()
	counterRolls()
	local id = assert(Enemy.spawn("Thornback", 20, 0, 1000, 0, nil, nil, 0))
	local center = assert(Enemy.getHurtGeometry(id))
	local shape = weapon.projectile or Pets.projectile
	local pixel = f.Config.Stats.range.studsPerPoint
	local origin = center - Vector3.new(shape.offsetForwardPoints * pixel, 0, shape.offsetSidePoints * pixel)
	local hp, before = Enemy.getHealth(id), Enemy.getShotCount()
	Sim.launchPet(f.me, origin, weapon, {}, { Vector3.new(1, 0, 0) }, false)
	Sim.step(0.001)
	expect(Enemy.getHealth(id) < hp).toBe(true)
	return Enemy.getShotCount() - before
end
describe("Native pet projectile defense", function()
	it("intercepts a real Catling projectile before pet damage, critical effects and owner life steal", function()
		local id, center = defender()
		Combat.drainPlayer(f.me, 2)
		local hp, ownerHp = Enemy.getHealth(id), Combat.getHp(f.me)
		local side = Pets.projectile.offsetSidePoints * f.Config.Stats.range.studsPerPoint
		Sim.launchPet(
			f.me,
			center + Vector3.new(-12, 0, -side),
			Pets.kinds.CatlingGun.weapon,
			{ lifeSteal = 100, critChance = 100, rangedDamage = 10 },
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.1)
		expect(Enemy.getHealth(id)).toBe(hp)
		expect(Combat.getHp(f.me)).toBe(ownerHp)
		expect(#fires).toBe(2)
		expect(fires[2].range).toBeNear(1010)
	end)
	it("lets Blazemander flames hit because the original parent pet has shoot_projectiles=false", function()
		local id, center, hurtRadius = defender()
		local weapon = Pets.kinds.Blazemander.ranged
		local scale, shape = f.Config.Stats.range.studsPerPoint, weapon.projectile
		local forward, side = shape.offsetForwardPoints * scale, shape.offsetSidePoints * scale
		local radius = shape.radiusPoints * scale
		local start = center + Vector3.new(-(hurtRadius + radius) - forward / 2, 0, -side)
		local hp = Enemy.getHealth(id)
		Sim.launchPet(f.me, start, weapon, {}, { Vector3.new(1, 0, 0) }, false)
		Sim.step(0.001)
		expect(Enemy.getHealth(id) < hp).toBe(true)
		expect(#fires).toBe(1)
		Sim.step(0.001)
		expect(#fires).toBe(1)
	end)
	it("also intercepts the projectile-shooting Bot-O-Mine despite its structure restrictions", function()
		local id, center = defender()
		local hp = Enemy.getHealth(id)
		local geometry = Pets.kinds.BotOMine.weapon.projectile or Pets.projectile
		local side = geometry.offsetSidePoints * f.Config.Stats.range.studsPerPoint
		Sim.launchPet(
			f.me,
			center + Vector3.new(-12, 0, -side),
			Pets.kinds.BotOMine.weapon,
			{ engineering = 10, damage = 50, structureDamage = 50 },
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.1)
		expect(Enemy.getHealth(id)).toBe(hp)
		expect(#fires).toBe(2)
		expect(fires[2].range).toBeNear(1010)
	end)
	it("keeps Catling's source hitbox inside when its root lies just outside the hurt circle", function()
		local id, center, hurtRadius = defender()
		local weapon = Pets.kinds.CatlingGun.weapon
		local shape = weapon.projectile or Pets.projectile
		local scale = f.Config.Stats.range.studsPerPoint
		local side, radius = shape.offsetSidePoints * scale, shape.radiusPoints * scale
		local at = center + Vector3.new(-0.01, 0, -(hurtRadius + radius) - side / 2)
		local hp = Enemy.getHealth(id)
		Sim.launchPet(f.me, at, weapon, {}, { Vector3.new(1, 0, 0) }, false)
		Sim.step(0.001)
		expect(#fires).toBe(2)
		Sim.step(0.001)
		expect(#fires).toBe(2)
		expect(Enemy.getHealth(id)).toBe(hp)
	end)
	it("does not provoke a ranged-only Fly counter from Blazemander's false-origin flames", function()
		expect(flyCounter(Pets.kinds.Blazemander.ranged)).toBe(0)
	end)
	it("lets Bot-O-Mine provoke Fly counters because the original predicate does not exclude structure pets", function()
		expect(flyCounter(Pets.kinds.BotOMine.weapon)).toBe(f.Config.Enemies.types.Thornback.retaliate.count)
	end)
	it("does not misclassify a pet's separate explosion as another ranged-pet contact", function()
		Sim.clear()
		Enemy.killAll()
		counterRolls()
		local first = assert(Enemy.spawn("Thornback", 20, 0, 1000, 0, nil, nil, 0))
		local second = assert(Enemy.spawn("Thornback", 20, 10, 1000, 0, nil, nil, 0))
		local center = assert(Enemy.getHurtGeometry(first))
		local hp = Enemy.getHealth(second)
		local before = Enemy.getShotCount()
		local weapon = table.clone(Pets.kinds.CatlingGun.weapon)
		weapon.radius = 16 -- exercise the existing on-hit PlayerExplosion path
		local side = Pets.projectile.offsetSidePoints * f.Config.Stats.range.studsPerPoint
		Sim.launchPet(f.me, center - Vector3.new(0, 0, side), weapon, {}, { Vector3.new(1, 0, 0) }, false)
		Sim.step(0.001)
		expect(Enemy.getHealth(second) < hp).toBe(true)
		expect(Enemy.getShotCount() - before).toBe(f.Config.Enemies.types.Thornback.retaliate.count)
	end)
	for structureId, def in f.Config.Structures.kinds do
		if def.nativeProjectile and not def.petKind then
			it(
				"allows real " .. structureId .. " structure shots through the shield without a ranged-pet origin",
				function()
					local id, center = defender()
					local hp = Enemy.getHealth(id)
					Sim.launch(f.me, center, def, {}, { Vector3.new(1, 0, 0) })
					Sim.step(0.001)
					assert(Enemy.getHealth(id) < hp, structureId .. " must really damage the defender")
					expect(#fires).toBe(1)
				end
			)
		end
	end
	it("does not provoke a Fly ranged counter from an ordinary turret projectile", function()
		Sim.clear()
		Enemy.killAll()
		counterRolls()
		local id = assert(Enemy.spawn("Thornback", 20, 0, 1000, 0, nil, nil, 0))
		local center = assert(Enemy.getHurtGeometry(id))
		local hp, before = Enemy.getHealth(id), Enemy.getShotCount()
		Sim.launch(f.me, center, f.Config.Structures.kinds.BrassSentry, {}, { Vector3.new(1, 0, 0) })
		Sim.step(0.001)
		expect(Enemy.getHealth(id) < hp).toBe(true)
		expect(Enemy.getShotCount()).toBe(before)
	end)
end)
Sim.clear()
k.nativeCharge, f.Weapons.emitStructureEffect, Random.number = originalCharge, originalEmit, originalRandom
