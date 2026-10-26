--!strict
-- Orbit Blades (DESIGN.md section 6): `count` blades spin around the owner, each reaching from bladeInnerRadius out
-- to `radius`, and hit every enemy they sweep over; the same enemy at most once per hitCooldownPerEnemy. Angles
-- come from Util/Orbit and server time, so WeaponRenderer/Visuals/OrbitBlades draws the blades in the same place
-- without any effects. Blades rest while the owner is down. Behavior for WeaponService/Arsenal.

local Shared = game:GetService("ReplicatedStorage").Shared
local Orbit = require(Shared.Util.Orbit)

local Arsenal = require(script.Parent.Parent.Arsenal)

local MAX_CHECKS = 12 -- blade checks per step, so a long server hitch cannot turn into hundreds of queries
local PRUNE_SECONDS = 2 -- how often hit times of enemies that can be hit again are forgotten

local found: { number } = {}

local OrbitBlades = {}

function OrbitBlades.step(weapon: Arsenal.Weapon, ctx: Arsenal.Context, _dt: number)
	local state = weapon.state
	if not ctx.active then
		state.lastNow = nil -- start fresh when the owner is back up instead of sweeping the whole pause
		return
	end
	local stats = weapon.stats
	local count = stats.count
	local now = ctx.now
	local nextHitAt: { [number]: number } = state.nextHitAt or {}
	state.nextHitAt = nextHitAt

	-- Check the arc the blades covered since the last step in pieces, so fast blades cannot skip an enemy.
	local from: number = if state.lastNow and state.lastCount == count then state.lastNow else now
	local spin = math.abs(math.rad(stats.rotationSpeed) * (now - from))
	local checks = math.clamp(math.ceil(spin * stats.radius / ctx.sweepStep), 1, MAX_CHECKS)
	local inner, outer, halfWidth = stats.bladeInnerRadius, stats.radius, stats.bladeWidth / 2
	local cooldown = stats.hitCooldownPerEnemy
	for check = 1, checks do
		local at = from + (now - from) * check / checks
		for blade = 1, count do
			local angle = Orbit.bladeAngle(stats.rotationSpeed, weapon.addedAt, at, blade, count)
			local cx, cz = math.cos(angle), math.sin(angle)
			local hits = ctx:querySegment(
				ctx.x + cx * inner,
				ctx.z + cz * inner,
				ctx.x + cx * outer,
				ctx.z + cz * outer,
				halfWidth,
				found
			)
			for i = 1, hits do
				local id = found[i]
				local readyAt = nextHitAt[id]
				if readyAt == nil or readyAt <= now then
					nextHitAt[id] = now + cooldown
					ctx:hit(weapon, id)
				end
			end
		end
	end
	state.lastNow = now
	state.lastCount = count

	if now >= (state.prunedAt or 0) + PRUNE_SECONDS then
		state.prunedAt = now
		for id, readyAt in nextHitAt do
			if readyAt <= now then
				nextHitAt[id] = nil
			end
		end
	end
end

return OrbitBlades
