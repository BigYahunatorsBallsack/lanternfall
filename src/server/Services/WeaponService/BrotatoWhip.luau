--!strict
-- Animated Whip hit windows for Arsenal; neutral scene facts in CharacterWeaponData define timing and collision size.
local Arsenal = require(script.Parent.Arsenal)
local Combat = require(script.Parent.BrotatoCombat)
local Pose = require(game:GetService("ReplicatedStorage").Shared.Util.WeaponPose)
local Whip = {}
local targets: { number } = {}
local found: { number } = {}
function Whip.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	if weapon.state.swing then
		return false
	end
	local stats = weapon.stats
	if ctx:nearestEnemies(ctx.x, ctx.z, stats.range, 1, targets) == 0 then
		return false
	end
	local tx, tz = ctx:enemyPosition(targets[1])
	if not tx or not tz then
		return false
	end
	local x, z = Pose.anchor(ctx.x, ctx.z, weapon.uid, weapon.id)
	local dx, dz = tx - x, tz - z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		dx, dz, length = 1, 0, 1
	end
	dx, dz = dx / length, dz / length
	weapon.state.swing = { elapsed = 0, dx = dx, dz = dz, hit = {} }
	ctx:emit(weapon, {
		kind = "Strike",
		uid = weapon.uid,
		x = ctx.x,
		z = ctx.z,
		dx = dx,
		dz = dz,
		range = stats.range,
		targetDistance = length,
		radius = stats.width,
		duration = stats.attackLockSeconds,
		angle = 0,
	})
	return true
end
-- Godot value-track interpolation mode 2 uses a cubic curve between the opening and closing keys.
local function cubic(before: number, first: number, last: number, after: number, time: number): number
	return 0.5
		* (
			(2 * first)
			+ (-before + last) * time
			+ (2 * before - 5 * first + 4 * last - after) * time * time
			+ (-before + 3 * first - 3 * last + after) * time * time * time
		)
end

function Whip.step(weapon: Arsenal.Weapon, ctx: Arsenal.Context, dt: number)
	local swing = weapon.state.swing
	if not swing then
		return
	end
	if not ctx.active then
		weapon.state.swing = nil
		return
	end
	local before = swing.elapsed
	swing.elapsed += dt
	local stats = weapon.stats
	if before < stats.hitCloseSeconds and swing.elapsed >= stats.hitOpenSeconds then
		local x, z = Pose.anchor(ctx.x, ctx.z, weapon.uid, weapon.id)
		local time =
			math.clamp((swing.elapsed - stats.hitOpenSeconds) / (stats.hitCloseSeconds - stats.hitOpenSeconds), 0, 1)
		local forward = cubic(
			stats.whipPositionBefore,
			stats.whipPositionOpen,
			stats.whipPositionClose,
			stats.whipPositionAfter,
			time
		)
		local angle = math.rad(
			cubic(
				stats.whipRotationBefore,
				stats.whipRotationOpen,
				stats.whipRotationClose,
				stats.whipRotationAfter,
				time
			)
		)
		local c, s = math.cos(angle), math.sin(angle)
		local dx, dz = swing.dx * c - swing.dz * s, swing.dx * s + swing.dz * c
		x += swing.dx * forward + dx * stats.whipHitboxOffset
		z += swing.dz * forward + dz * stats.whipHitboxOffset
		local count = ctx:querySegment(x, z, x + dx * stats.range, z + dz * stats.range, stats.width, found)
		for i = 1, count do
			local id = found[i]
			if not swing.hit[id] then
				swing.hit[id] = true
				Combat.hit(weapon, ctx, id)
			end
		end
	end
	if swing.elapsed >= stats.attackLockSeconds then
		weapon.state.swing = nil
	end
end
return Whip
