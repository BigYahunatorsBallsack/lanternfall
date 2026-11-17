--!strict
-- Structure and pet projectiles share the weapon sweep simulator; StructureService steps and clears both.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Enemy = require(script.Parent.Parent.EnemySim)
local Weapons = require(script.Parent.Parent.WeaponService)
local Random = require(script.Parent.Parent.RandomService)
local Projectile = require(script.Parent.Parent.WeaponService.BrotatoProjectile)
local Arsenal = require(script.Parent.Parent.WeaponService.Arsenal)
local Rules = require(script.Parent.Rules)
local PetRules = require(script.Parent.PetRules)
local PetConfig = require(Shared.Config.Pets)
local Combat = require(script.Parent.Parent.CombatService)
local Sim = {}
local volleys: { any } = {}
local function launch(
	player: Player,
	at: Vector3,
	def: any,
	sheet: { [string]: number },
	directions: { Vector3 },
	prepared: any?,
	petScaling: { [string]: number }?
)
	local stats = prepared
		or {
			damage = Rules.damage(def, sheet),
			critChance = def.critChance or 0,
			critDamage = def.critDamage or 2,
			projectileSpeed = def.projectileSpeed,
			projectileRadius = Config.Structures.trapShotRadius,
			range = def.shotRange or Rules.range(def, sheet),
			pierce = def.pierce or 0,
			pierceDamage = Rules.pierceFactor(def, sheet),
			bounce = math.max(0, math.floor(sheet.bounce or 0)),
			bounceDamage = Config.Structures.bounceFalloff,
			knockback = math.max(0, sheet.knockback or 0) * Config.Combat.knockback.studsPerPoint,
			knockbackPiercing = 0,
			nativeTiming = 1,
			nativeAccuracy = def.nativeAccuracy,
			nativeSpread = def.nativeSpread,
			count = def.count,
		}
	if not prepared then
		stats.critChance, stats.critDamage = Rules.critical(def, sheet)
		require(Shared.Util.NativeRangedStats).apply(stats, sheet)
		stats.pierce += math.max(0, math.floor(sheet.piercing or 0))
	end
	if def.radius then
		stats.explosionRadius = def.radius
			* math.max(Config.Combat.explosion.minimumSizeFactor, 1 + (sheet.explosionSize or 0) / 100)
		stats.explosionChance = 1
	end
	local fake = {
		id = "StructureShot",
		ownerId = player.UserId,
		tier = 1,
		uid = 0,
		state = {},
		stats = stats,
		config = {
			kind = if prepared then "Pet" else "Structure",
			scaling = petScaling or { engineering = def.engineering or 0 },
		},
	}
	local ctx: any = { x = at.X, z = at.Z, active = false, now = workspace:GetServerTimeNow(), slot = 1, slotCount = 1 }
	function ctx.setHitDirection(_, dx, dz)
		ctx.hitDirX, ctx.hitDirZ = dx, dz
	end
	function ctx.random()
		return Random.number("Combat", player)
	end
	function ctx.nextId()
		return Weapons.nextEffectId()
	end
	function ctx.enemyPosition(_, id)
		local p = Enemy.getPosition(id)
		return if p then p.X else nil, if p then p.Z else nil
	end
	function ctx.querySegment(_, x, z, tx, tz, r, out)
		if prepared then
			local dx, dz = tx - x, tz - z
			local length = math.sqrt(dx * dx + dz * dz)
			if length > 0 then
				local geometry = def.projectile or PetConfig.projectile
				local forward = geometry.offsetForwardPoints * Config.Stats.range.studsPerPoint
				local side = geometry.offsetSidePoints * Config.Stats.range.studsPerPoint
				local ox, oz = (dx * forward - dz * side) / length, (dz * forward + dx * side) / length
				x, z, tx, tz = x + ox, z + oz, tx + ox, tz + oz
			end
		end
		return Enemy.querySegment(Vector3.new(x, at.Y, z), Vector3.new(tx, at.Y, tz), r, out)
	end
	function ctx.queryCircle(_, x, z, r, out)
		return Enemy.queryRadius(Vector3.new(x, at.Y, z), r, out)
	end
	function ctx.emit(_, _, event)
		Weapons.emitStructureEffect(player, event)
	end
	function ctx.bounceTarget(_, x, z, visited)
		local ids = {}
		Enemy.queryRadius(Vector3.new(x, at.Y, z), Config.Structures.bounceRange, ids)
		local best, distance = nil, math.huge
		for _, id in ids do
			local pos = Enemy.getPosition(id)
			local d = if pos then (pos - Vector3.new(x, at.Y, z)).Magnitude else math.huge
			if not visited[id] and d < distance then
				best, distance = id, d
			end
		end
		return best
	end
	function ctx.hit(_, weapon, id, share, mode)
		local s = weapon.stats
		if def.vulnerabilityPercent then
			Enemy.applyWeakness(
				id,
				def.vulnerabilitySource,
				def.vulnerabilityPercent,
				def.vulnerabilitySeconds,
				def.vulnerabilityStacks
			)
		end
		local critical = s.critChance >= 1
		local amount = s.damage * (share or 1) * (if critical then s.critDamage else 1)
		if prepared then
			local kind = Enemy.getKind(id)
			local boss = Config.Enemies.bosses[kind] ~= nil or Config.Enemies.champions[kind] ~= nil
			amount =
				PetRules.hitDamage(s.damage, share, if critical then s.critDamage else 1, boss, sheet.eliteDamage or 0)
		end
		local killed = Weapons.structureHit(
			player,
			id,
			math.round(amount),
			if mode == "Explosion" then "Explosion" else nil,
			critical,
			petScaling ~= nil and petScaling.elementalDamage ~= nil,
			prepared ~= nil and def.burning ~= nil
		)
		if prepared and s.nativePetRangedOrigin == 1 and mode ~= "Explosion" and not killed then
			Enemy.retaliate(id, "Ranged") -- native Fly variants also react to projectile-shooting pets
		end
		if prepared and def.burning and not killed then
			Weapons.structureBurn(
				player,
				id,
				PetRules.burnDamage(def.burning, sheet, def.petBeastMaster),
				def.burning.ticks,
				sheet
			)
		elseif def.burnBase then
			local base = def.burnBase
				+ (def.burnEngineering or 0) * (sheet.engineering or 0)
				+ (def.burnElemental or 0) * (sheet.elementalDamage or 0)
			local burn = math.max(
				1,
				math.round(
					math.floor(base + (sheet.nativeGlobalBurnDamage or 0))
						* math.max(0, 1 + (sheet.structureDamage or 0) / 100)
				)
			)
			Weapons.structureBurn(player, id, burn, def.ticks, sheet)
		end
		if not killed and (s.knockback > 0 or (prepared and s.knockback < 0)) then
			local pos = Enemy.getPosition(id)
			if pos and (pos - at).Magnitude > 0 then
				local away = (pos - at).Unit
				local dx, dz =
					Arsenal.knockDirection(away.X, away.Z, s.petKnockX or ctx.hitDirX, s.petKnockZ or ctx.hitDirZ)
				Enemy.knock(id, dx * s.knockback, dz * s.knockback)
			end
		end
		if prepared and ctx:random() < s.lifeSteal then
			Combat.lifeSteal(player)
		end
		return killed
	end
	for _, direction in directions do
		local aim = if def.radial then 0 else (ctx:random() * 2 - 1) * (1 - stats.nativeAccuracy)
		for _ = 1, (if def.radial then 1 elseif prepared then math.max(0, stats.count) else math.max(1, stats.count)) do
			local angle = aim + (ctx:random() * 2 - 1) * stats.nativeSpread
			local c, s = math.cos(angle), math.sin(angle)
			if def.radial then
				stats.petKnockX, stats.petKnockZ = direction.X, direction.Z
			end
			Projectile.launch(
				fake,
				ctx,
				at.X,
				at.Z,
				direction.X * c - direction.Z * s,
				direction.X * s + direction.Z * c,
				stats
			)
		end
	end
	table.insert(volleys, { weapon = fake, context = ctx })
end
-- Existing structure callers retain their five-argument contract and their structure-only scaling.
function Sim.launch(player: Player, at: Vector3, def: any, sheet: { [string]: number }, directions: { Vector3 })
	launch(player, at, def, sheet, directions)
end
-- Trusted server pet actors supply original weapon definitions; ranged modifiers are applied exactly once.
function Sim.launchPet(
	player: Player,
	at: Vector3,
	weapon: any,
	sheet: { [string]: number },
	directions: { Vector3 },
	beastMaster: boolean
)
	local stats = PetRules.compute(weapon, sheet, beastMaster)
	stats.nativeTiming = 1
	stats.nativeIntegerFalloff = 1
	stats.nativePetRangedOrigin = if weapon.petSourceShootsProjectiles then 1 else 0
	local geometry = weapon.projectile or PetConfig.projectile
	local pixel = Config.Stats.range.studsPerPoint
	stats.projectileRadius = geometry.radiusPoints * pixel
	stats.nativeProjectileOffsetForward = geometry.offsetForwardPoints * pixel
	stats.nativeProjectileOffsetSide = geometry.offsetSidePoints * pixel
	stats.range += PetConfig.projectile.autoRangeBonusPoints * Config.Stats.range.studsPerPoint
	stats.knockbackPiercing = 0
	local definition = table.clone(weapon)
	definition.petBeastMaster = beastMaster
	launch(player, at, definition, sheet, directions, stats, PetRules.weaponScaling(weapon, sheet, beastMaster))
end
function Sim.step(dt: number)
	for i = #volleys, 1, -1 do
		local v = volleys[i]
		if not v then
			break
		end
		v.context.now = workspace:GetServerTimeNow()
		Projectile.step(v.weapon, v.context, dt)
		if volleys[i] ~= v then
			break
		end -- Terminal hits clear the queue during Projectile.step.
		if not v.weapon.state.projectiles or #v.weapon.state.projectiles == 0 then
			table.remove(volleys, i)
		end
	end
end
function Sim.clear()
	table.clear(volleys)
end
return Sim
