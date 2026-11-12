--!strict
-- Reconstructs the native fixed-physics sinusoidal velocity sum; shared by server collision and enemy-shot rendering.
local Shared = script.Parent.Parent
local C = require(Shared.Config.NativeBulletHell).rules
local Types = require(Shared.Net.Types)
local Motion = {}
local function axis(time: number, amplitude: number, frequency: number): number
	local step = 1 / C.physicsRate
	local frames = math.floor(time / step + 1e-8)
	local remainder = math.max(0, time - frames * step)
	local halfAngle = frequency * step / 2
	local denominator = math.sin(halfAngle)
	local sum = if math.abs(denominator) < 1e-12
		then 0
		else math.sin(frames * halfAngle) * math.sin((frames + 1) * halfAngle) / denominator
	return amplitude / C.motionDivisor * (step * sum + remainder * math.sin((frames + 1) * frequency * step))
end
function Motion.offset(
	time: number,
	dx: number,
	dz: number,
	speed: number,
	motion: Types.EnemyShotMotion
): (number, number)
	return dx * speed * time + axis(time, motion.amplitudeX, motion.frequencyX),
		dz * speed * time + axis(time, motion.amplitudeZ, motion.frequencyZ)
end
return Motion
