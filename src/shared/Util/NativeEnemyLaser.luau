--!strict
-- Source static enemy-laser frame clock and oriented rectangle; NativeLaserService owns positions, targets and damage.
local Shared = script.Parent.Parent
local C = require(Shared.Config.NativeEnemyLaser)
local Pixel = require(Shared.Config.Stats).range.studsPerPoint
local Laser = {}
export type State = { pending: number, delay: number, after: number, enabled: boolean, stopped: boolean }
function Laser.new(): State
	return { pending = 0, delay = C.delaySeconds, after = C.afterSeconds, enabled = false, stopped = false }
end
function Laser.step(state: State, dt: number, hit: () -> boolean)
	local frame = 1 / C.frameRate
	state.pending += dt
	while not state.stopped and state.pending >= frame - 1e-9 do
		state.pending = math.max(0, state.pending - frame)
		if not state.enabled then
			state.delay -= frame
			if state.delay <= 1e-9 then
				state.enabled = true
			end
		end
		if state.enabled then
			state.after -= frame
			if state.after <= 1e-9 or hit() then
				state.stopped = true
			end
		end
	end
end
function Laser.contains(x: number, z: number, dx: number, dz: number, px: number, pz: number, radius: number): boolean
	local ox, oz = C.offsetPoints[1] * Pixel, C.offsetPoints[2] * Pixel
	local vx, vz = px - (x + dx * ox - dz * oz), pz - (z + dz * ox + dx * oz)
	local along = vx * dx + vz * dz
	local across = -vx * dz + vz * dx
	local ax = math.max(0, math.abs(along) - C.halfExtentsPoints[1] * Pixel)
	local az = math.max(0, math.abs(across) - C.halfExtentsPoints[2] * Pixel)
	return ax * ax + az * az <= radius * radius
end
return Laser
