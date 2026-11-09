--!strict
-- Native turret wind-up, animation speed ceiling and random post-animation cooldown; StructureService advances it.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.Structures)
local Rules = require(script.Parent.Rules)
local C = Config.nativeTurret
local Timing = {}
function Timing.step(
	state: any,
	dt: number,
	definition: any,
	sheet: { [string]: number },
	improved: boolean,
	hasTarget: boolean,
	random: () -> number,
	shoot: () -> ()
)
	local cooldown = Rules.interval(definition, sheet, improved)
	local speed = state.animationSpeed or definition.animationSpeed
	if C.animationSeconds / speed > cooldown then
		speed = math.min(C.animationSeconds / cooldown, C.maximumAnimationSpeed)
	end
	state.animationSpeed = speed
	local attack = state.attack
	if attack then
		attack.elapsed += dt
		if not attack.fired and attack.elapsed >= C.shootAtSeconds / attack.speed then
			attack.fired = true
			shoot()
		end
		if attack.elapsed >= C.animationSeconds / attack.speed then
			state.attack = nil
			local minimum = math.max(C.minimumRandomFrames / Config.nativeFrameRate, cooldown * C.cooldownRandomMinimum)
			state.remaining = minimum + (cooldown * C.cooldownRandomMaximum - minimum) * random()
		end
		return
	end
	state.remaining -= dt
	if state.remaining <= 0 and hasTarget then
		state.attack = { elapsed = 0, speed = speed, fired = false }
	end
end
return Timing
