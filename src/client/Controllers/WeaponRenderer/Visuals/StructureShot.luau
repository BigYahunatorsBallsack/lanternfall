--!strict
-- Native structure projectile feedback; shared effects never animate the player's held weapon or avatar.
local flight = require(script.Parent.Parent.B7ProjectileVisual)(Color3.fromRGB(230, 190, 110))
local Visual = { render = flight.render, clear = flight.clear }
function Visual.effect(effect)
	if effect.kind == "StructureFire" then
		effect = table.clone(effect)
		effect.kind = "Fire"
	end
	flight.effect(effect)
end
return Visual
