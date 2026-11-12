--!strict
-- Pure native fog visibility, animation and fade rules; consumed by the server state and client mask renderer.
local C = require(script.Parent.Parent.Config.NativeFog)
local Rules = {}
function Rules.waveScale(wave: number): number
	return C.rules.waveScaleBase - C.rules.waveScaleLoss * math.min(wave, C.rules.waveCap) / C.rules.waveCap
end
function Rules.visibility(value: number): number
	return 1 + math.clamp(value, C.rules.visibilityMin, C.rules.visibilityMax) / 100
end
-- Source data for the later permanent-fog character; that character's wave penalty is not enabled here.
function Rules.permanentLoss(wave: number): number
	return math.clamp(C.rules.permanentLossBase + C.rules.permanentLossPerWave * wave, 0, C.rules.permanentLossMax)
end
function Rules.pulse(animation: any, age: number): number
	local at = age % animation.length
	for i = 2, #animation.times do
		if at <= animation.times[i] then
			local t = (at - animation.times[i - 1]) / (animation.times[i] - animation.times[i - 1])
			-- The source's looped cubic keys alternate minimum/maximum; both endpoint tangents are zero.
			t = t * t * (3 - 2 * t)
			return animation.values[i - 1] + (animation.values[i] - animation.values[i - 1]) * t
		end
	end
	return animation.values[1]
end
function Rules.transientFade(age: number, hold: number): number
	return 1 - math.clamp((age - hold) / C.rules.fadeSeconds, 0, 1)
end
return Rules
