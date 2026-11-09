--!strict
-- Original ranged attacks and on-hit projectiles for Arsenal; all weapon numbers are Config.Weapons data.
local Arsenal = require(script.Parent.Arsenal)
local Combat = require(script.Parent.BrotatoCombat)
local Rules = require(game:GetService("ReplicatedStorage").Shared.Config.Combat).originalWeapons
local WeaponPose = require(game:GetService("ReplicatedStorage").Shared.Util.WeaponPose)
local WeaponTarget = require(script.Parent.WeaponTarget)
local Sticky = require(script.Parent.StickyGrenadeShot)

type Shot = {
	id: number,
	x: number,
	z: number,
	dx: number,
	dz: number,
	flown: number,
	stats: { [string]: number },
	left: number,
	bounces: number,
	share: number,
	hit: { [number]: boolean },
	secondary: boolean,
	bounced: boolean?,
	critical: boolean?,
	slowHit: { [number]: boolean }?,
	fuseUntil: number?,
	targetId: number?,
	offsetX: number?,
	offsetZ: number?,
}
local Projectile = {}
local targets: { number } = {}
local found: { number } = {}
local ordered: { { id: number, distance: number } } = {}
local zoneFound: { number } = {}
local nativeSlow: ((number, number, boolean, number) -> ())? = nil
function Projectile.setNativeSlow(callback: (number, number, boolean, number) -> ())
	nativeSlow = callback
end

local slowAura: ((number, number, number, number, number) -> ())? = nil

function Projectile.setSlowAura(callback: (number, number, number, number, number) -> ())
	slowAura = callback
end

local function launch(weapon: Arsenal.Weapon, ctx: Arsenal.Context, shot: Shot)
	local shots = weapon.state.projectiles or {}
	weapon.state.projectiles = shots
	table.insert(shots, shot)
	ctx:emit(weapon, {
		kind = "Fire",
		uid = if shot.secondary then nil else weapon.uid,
		id = shot.id,
		x = shot.x,
		z = shot.z,
		dx = shot.dx,
		dz = shot.dz,
		speed = shot.stats.projectileSpeed,
		range = shot.stats.range,
	})
end

local function start(
	weapon: Arsenal.Weapon,
	ctx: Arsenal.Context,
	x: number,
	z: number,
	dx: number,
	dz: number,
	stats: { [string]: number },
	secondary: boolean,
	skip: number?
)
	local critical = if stats.critPierce or stats.critBounce then ctx:random() < stats.critChance else nil
	local piercing = stats.pierce or 0
	if critical then
		piercing += stats.critPierce or 0
	end
	launch(weapon, ctx, {
		id = ctx:nextId(),
		x = x,
		z = z,
		dx = dx,
		dz = dz,
		flown = 0,
		stats = table.clone(stats),
		left = if piercing < 0 then math.huge else piercing + 1,
		bounces = (stats.bounce or 0) + (if critical then stats.critBounce or 0 else 0),
		share = 1,
		hit = if skip then { [skip] = true } else {},
		slowHit = if stats.slowZoneRadius then {} else nil,
		secondary = secondary,
		critical = critical,
	})
end

function Projectile.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	local stats = weapon.stats
	if (weapon.state.reloadLeft or 0) > 0 then
		return false
	end
	local count = math.max(1, math.floor(stats.count or 1))
	local targetCount = WeaponTarget.pick(
		weapon,
		ctx,
		stats.range,
		if stats.fan or stats.nativeSpread ~= nil then 1 else count,
		targets,
		stats.minimumRange
	)
	if targetCount == 0 and stats.shootWithoutTarget ~= 1 then
		return false
	end
	weapon.state.volleyCount = (weapon.state.volleyCount or 0) + 1
	if stats.cycleEvery and weapon.state.volleyCount % stats.cycleEvery == 0 then
		stats = table.clone(stats)
		stats.critChance = stats.cycleCritChance
	end
	if stats.shotAnimationSeconds then
		weapon.state.shootingUntil = ctx.now + stats.shotAnimationSeconds
	end
	local heldX, heldZ = WeaponPose.anchor(ctx.x, ctx.z, ctx.slot, ctx.slotCount, weapon.id)
	for k = 1, count do
		local tx: number?, tz: number? = nil, nil
		if targetCount > 0 then
			tx, tz = ctx:enemyPosition(targets[math.min(k, targetCount)])
		end
		local dx = if tx then tx - heldX else weapon.state.aimDx or 1
		local dz = if tz then tz - heldZ else weapon.state.aimDz or 0
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1e-6 then
			dx, dz, length = 1, 0, 1
		end
		dx, dz = dx / length, dz / length
		weapon.state.aimDx, weapon.state.aimDz = dx, dz
		if stats.nativeSpread ~= nil then
			-- Native accuracy rotates the weapon once; each pellet then gets independent random spread in radians.
			if k == 1 then
				weapon.state.accuracyAngle = (ctx:random() * 2 - 1) * (1 - stats.nativeAccuracy)
			end
			local angle = weapon.state.accuracyAngle + (ctx:random() * 2 - 1) * stats.nativeSpread
			local c, s = math.cos(angle), math.sin(angle)
			dx, dz = dx * c - dz * s, dx * s + dz * c
		end
		if stats.fan then
			local angle = math.rad(stats.spreadDegrees) * (k - (count + 1) / 2)
			local c, s = math.cos(angle), math.sin(angle)
			dx, dz = dx * c - dz * s, dx * s + dz * c
		end
		local x, z = WeaponPose.muzzle(ctx.x, ctx.z, ctx.slot, ctx.slotCount, weapon.id, dx, dz, length)
		start(weapon, ctx, x, z, dx, dz, stats, false, nil)
	end
	if stats.magazine then
		weapon.state.shots = (weapon.state.shots or 0) + 1
		if weapon.state.shots >= stats.magazine then
			weapon.state.shots = 0
			-- The source reload replaces this attack's usual interval.
			weapon.state.reloadLeft = stats.reloadSeconds
		end
	end
	return true
end

local function secondaryShots(weapon: Arsenal.Weapon, ctx: Arsenal.Context)
	local pending = weapon.state.secondaryShots
	if not pending then
		return
	end
	weapon.state.secondaryShots = nil
	for _, p in pending do
		local stats = table.clone(p.stats)
		local count = stats.secondaryCount
		stats.damage = stats.secondaryDamage
		stats.range = stats.secondaryRangeStuds
		stats.projectileSpeed = stats.secondarySpeed
		stats.projectileRadius = stats.secondaryRadius
		stats.pierce = 0
		stats.bounce = stats.secondaryBounce or 0
		stats.bounceDamage = 1
		stats.slow = stats.secondarySlow
		stats.slowSeconds = stats.secondarySlowSeconds
		stats.burnDamage, stats.explosionRadius, stats.executeChance = nil, nil, nil
		stats.critPierce, stats.critBounce, stats.engineeringSlow = nil, nil, nil
		for k = 1, count do
			local angle = k / count * math.pi * 2
			local dx, dz = math.cos(angle), math.sin(angle)
			if stats.secondaryElemental then
				local target = ctx:bounceTarget(p.x, p.z, { [p.skip] = true })
				local tx: number?, tz: number? = nil, nil
				if target then
					tx, tz = ctx:enemyPosition(target)
				end
				if tx and tz then
					local length = math.sqrt((tx - p.x) ^ 2 + (tz - p.z) ^ 2)
					if length > 1e-6 then
						dx, dz = (tx - p.x) / length, (tz - p.z) / length
					end
				end
			end
			start(weapon, ctx, p.x, p.z, dx, dz, stats, true, p.skip)
		end
	end
end

function Projectile.step(weapon: Arsenal.Weapon, ctx: Arsenal.Context, dt: number)
	weapon.state.reloadLeft = math.max(0, (weapon.state.reloadLeft or 0) - dt)
	if ctx.active and weapon.config.kind == "Ranged" and weapon.stats.cooldown < dt then
		for _ = 1, Rules.maxCatchupAttacks do
			if weapon.cooldownLeft - dt > -weapon.stats.cooldown or not Projectile.fire(weapon, ctx) then
				break
			end
			weapon.cooldownLeft += weapon.stats.cooldown
		end
	end
	secondaryShots(weapon, ctx)
	local shots = weapon.state.projectiles :: { Shot }?
	if not shots then
		return
	end
	for index = #shots, 1, -1 do
		local shot = shots[index]
		local stats = shot.stats
		if stats.stickyFuse then
			if Sticky.step(weapon, ctx, shot, dt) then
				table.remove(shots, index)
			end
			continue
		end
		local move = math.min(stats.projectileSpeed * dt, stats.range - shot.flown)
		local x1, z1 = shot.x + shot.dx * move, shot.z + shot.dz * move
		if slowAura and stats.slowRadius then
			slowAura(x1, z1, stats.slowRadius, 1 - stats.slow, stats.slowSeconds)
		end
		if stats.slowZoneRadius and nativeSlow and shot.slowHit then
			local ox = shot.dx * stats.slowZoneOffsetX - shot.dz * stats.slowZoneOffsetZ
			local oz = shot.dz * stats.slowZoneOffsetX + shot.dx * stats.slowZoneOffsetZ
			local count = ctx:querySegment(shot.x + ox, shot.z + oz, x1 + ox, z1 + oz, stats.slowZoneRadius, zoneFound)
			for index = 1, count do
				local id = zoneFound[index]
				if not shot.slowHit[id] then
					shot.slowHit[id] = true
					nativeSlow(id, stats.slowZonePoints, false, 0)
				end
			end
		end
		local n = ctx:querySegment(shot.x, shot.z, x1, z1, stats.projectileRadius, found)
		table.clear(ordered)
		for i = 1, n do
			local id = found[i]
			if not shot.hit[id] then
				local x, z = ctx:enemyPosition(id)
				if x and z then
					table.insert(
						ordered,
						{ id = id, distance = math.clamp((x - shot.x) * shot.dx + (z - shot.z) * shot.dz, 0, move) }
					)
				end
			end
		end
		table.sort(ordered, function(a, b)
			return a.distance < b.distance
		end)
		local stopped = false
		for _, entry in ordered do
			local id = entry.id
			shot.hit[id] = true
			Combat.hit(weapon, ctx, id, shot.share, stats, shot.critical, shot.secondary, shot.bounced)
			local x, z = ctx:enemyPosition(id)
			local bounce = if x and z and shot.bounces > 0 then ctx:bounceTarget(x, z, shot.hit) else nil
			if bounce and x and z then
				local tx, tz = ctx:enemyPosition(bounce)
				if tx and tz then
					local length = math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2)
					if length > 1e-6 then
						ctx:emit(
							weapon,
							{ kind = "End", id = shot.id, x = x, z = z, distance = shot.flown + entry.distance }
						)
						shot.id = ctx:nextId()
						shot.x, shot.z, shot.dx, shot.dz, shot.flown = x, z, (tx - x) / length, (tz - z) / length, 0
						shot.bounces -= 1
						shot.bounced = true
						shot.share *= stats.bounceDamage or 1
						ctx:emit(weapon, {
							kind = "Fire",
							id = shot.id,
							x = x,
							z = z,
							dx = shot.dx,
							dz = shot.dz,
							speed = stats.projectileSpeed,
							range = stats.range,
						})
						stopped = true
						break
					end
				end
			end
			shot.left -= 1
			if shot.left <= 0 then
				ctx:emit(weapon, {
					kind = "End",
					id = shot.id,
					x = shot.x + shot.dx * entry.distance,
					z = shot.z + shot.dz * entry.distance,
					distance = shot.flown + entry.distance,
				})
				table.remove(shots, index)
				stopped = true
				break
			end
			shot.share *= stats.pierceDamage or 1
		end
		if not stopped then
			shot.x, shot.z = x1, z1
			shot.flown += move
			if shot.flown >= stats.range - 1e-6 then
				table.remove(shots, index)
			end
		end
	end
end

return Projectile
