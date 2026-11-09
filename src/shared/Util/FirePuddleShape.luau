--!strict
-- Native fire-puddle spawn growth; shared by authoritative collision and cosmetic rendering.
local C = require(script.Parent.Parent.Config.Combat).nativeFirePuddles
return function(age: number): number
	local t = math.clamp(age / C.spawnSeconds, 0, 1) - 1
	return 1 + t * t * ((C.backOvershoot + 1) * t + C.backOvershoot)
end
