--!strict
-- Native structure projectiles reuse the weapon sweep simulator with a structure-only hit context; StructureService steps them.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Enemy = require(script.Parent.Parent.EnemySim)
local Weapons = require(script.Parent.Parent.WeaponService)
local Random = require(script.Parent.Parent.RandomService)
local Projectile = require(script.Parent.Parent.WeaponService.BrotatoProjectile)
local Rules = require(script.Parent.Rules)
local Sim = {}
local volleys: { any } = {}
function Sim.launch(player: Player, at: Vector3, def: any, sheet: { [string]: number }, directions: { Vector3 })
	local stats = {
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
	require(Shared.Util.NativeRangedStats).apply(stats, sheet)
	stats.pierce += math.max(0, math.floor(sheet.piercing or 0))
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
		config = { kind = "Structure", scaling = { engineering = def.engineering or 0 } },
	}
	local ctx: any = { x = at.X, z = at.Z, active = false, now = workspace:GetServerTimeNow(), slot = 1, slotCount = 1 }
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
		local critical = s.critChance >= 1
		local amount = s.damage * (share or 1) * (if critical then s.critDamage else 1)
		local killed = Weapons.structureHit(
			player,
			id,
			math.round(amount),
			if mode == "Explosion" then "Explosion" else nil,
			critical,
			false
		)
		if def.burnBase then
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
		if not killed and s.knockback > 0 then
			local pos = Enemy.getPosition(id)
			if pos and (pos - at).Magnitude > 0 then
				Enemy.push(id, (pos - at).Unit * s.knockback)
			end
		end
		return killed
	end
	for _, direction in directions do
		local aim = (ctx:random() * 2 - 1) * (1 - stats.nativeAccuracy)
		for _ = 1, math.max(1, stats.count) do
			local angle = aim + (ctx:random() * 2 - 1) * stats.nativeSpread
			local c, s = math.cos(angle), math.sin(angle)
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
function Sim.step(dt: number)
	for i = #volleys, 1, -1 do
		local v = volleys[i]
		v.context.now = workspace:GetServerTimeNow()
		Projectile.step(v.weapon, v.context, dt)
		if not v.weapon.state.projectiles or #v.weapon.state.projectiles == 0 then
			table.remove(volleys, i)
		end
	end
end
function Sim.clear()
	table.clear(volleys)
end
return Sim
