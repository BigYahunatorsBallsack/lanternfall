--!strict
-- Native Boomerang phase flight, unlimited per-leg hits and return-locked cooldown; Arsenal calls fire and step.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.Combat).nativeBoomerang
local Combat = require(script.Parent.Parent.BrotatoCombat)
local Target = require(script.Parent.Parent.WeaponTarget)
local Pose = require(Shared.Util.WeaponPose)
local Boomerang = {}
local targets, found = {}, {}
local function emit(weapon, ctx, shot, kind)
	ctx:emit(
		weapon,
		{ kind = kind, id = shot.id, x = shot.x, z = shot.z, duration = C.maximumFlightSeconds - shot.age }
	)
end
function Boomerang.fire(weapon, ctx): boolean
	if weapon.state.boomerangs and #weapon.state.boomerangs > 0 then
		return false
	end
	local stats = weapon.stats
	if Target.pick(weapon, ctx, stats.range, 1, targets) == 0 then
		return false
	end
	local tx, tz = ctx:enemyPosition(targets[1])
	if not tx or not tz then
		return false
	end
	local dx, dz = tx - ctx.x, tz - ctx.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-6 then
		dx, dz, distance = 1, 0, 1
	end
	dx, dz = dx / distance, dz / distance
	weapon.state.aimDx, weapon.state.aimDz = dx, dz
	local accuracy = (ctx:random() * 2 - 1) * (1 - stats.nativeAccuracy)
	local shots = {}
	weapon.state.boomerangs = shots
	for _ = 1, math.max(0, stats.count) do
		local angle = accuracy + (ctx:random() * 2 - 1) * stats.nativeSpread
		local c, s = math.cos(angle), math.sin(angle)
		local vx, vz = dx * c - dz * s, dx * s + dz * c
		local x, z = Pose.muzzle(ctx.x, ctx.z, ctx.slot, ctx.slotCount, weapon.id, vx, vz, distance)
		local reach = math.max(stats.range, math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2))
		local speed = math.max(C.minimumSpeed, stats.projectileSpeed)
		local shot = {
			id = ctx:nextId(),
			x = x,
			z = z,
			startX = x,
			startZ = z,
			dx = vx,
			dz = vz,
			reach = reach,
			speed = speed,
			outSeconds = reach / speed * C.outDurationFactor,
			phase = "Out",
			phaseTime = 0,
			age = 0,
			hit = {},
			stats = table.clone(stats),
		}
		table.insert(shots, shot)
		emit(weapon, ctx, shot, "Drop")
	end
	return true
end
function Boomerang.step(weapon, ctx, dt)
	local shots = weapon.state.boomerangs
	if not shots or #shots == 0 then
		return
	end
	-- Weapon._current_cooldown does not advance while any projectile of this attack is still in flight.
	local alive = Combat.ownerAlive(weapon.ownerId, ctx.active)
	if alive then
		weapon.cooldownLeft += dt
	end
	for i = #shots, 1, -1 do
		local shot = shots[i]
		shot.age += dt
		shot.phaseTime += dt
		local stop = not alive or shot.age >= C.maximumFlightSeconds
		local oldX, oldZ = shot.x, shot.z
		if not stop then
			if shot.phase == "Out" then
				local u = math.min(1, shot.phaseTime / shot.outSeconds)
				local t = 1 - (1 - u) ^ 2
				shot.x, shot.z = shot.startX + shot.dx * shot.reach * t, shot.startZ + shot.dz * shot.reach * t
				if u >= 1 then
					shot.phase, shot.phaseTime = "Apex", 0
				end
			elseif shot.phase == "Apex" then
				shot.x += shot.dx * shot.speed * C.apexSpeedFactor * dt
				shot.z += shot.dz * shot.speed * C.apexSpeedFactor * dt
				if shot.phaseTime >= C.apexSeconds then
					table.clear(shot.hit)
					shot.phase, shot.phaseTime = "Back", 0
				end
			else
				local dx, dz = ctx.x - shot.x, ctx.z - shot.z
				local length = math.sqrt(dx * dx + dz * dz)
				if length <= C.catchDistance then
					stop = true
				else
					local speed = math.min(
						shot.speed * C.backMaxSpeedFactor,
						shot.speed * (C.apexSpeedFactor + C.backAccelerationFactor * shot.phaseTime)
					)
					local travel = math.min(speed * dt, length)
					shot.x += dx / length * travel
					shot.z += dz / length * travel
				end
			end
		end
		if stop then
			emit(weapon, ctx, shot, "End")
			table.remove(shots, i)
		else
			local angle = math.atan2(shot.dz, shot.dx) + math.rad(C.hitRotationDegreesPerSecond * shot.age)
			local ox = C.hitOffsetX * math.cos(angle) - C.hitOffsetZ * math.sin(angle)
			local oz = C.hitOffsetX * math.sin(angle) + C.hitOffsetZ * math.cos(angle)
			local n = ctx:querySegment(oldX + ox, oldZ + oz, shot.x + ox, shot.z + oz, C.radius, found)
			for k = 1, n do
				local id = found[k]
				if not shot.hit[id] then
					shot.hit[id] = true
					ctx:setHitDirection(shot.dx, shot.dz)
					Combat.hit(weapon, ctx, id, 1, shot.stats)
					ctx:setHitDirection(nil, nil)
				end
			end
			emit(weapon, ctx, shot, "Drop")
		end
	end
end
return Boomerang
