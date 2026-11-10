--!strict
-- Friendly enemy projectile feedback uses the native Charm hue without animating the player's avatar.
local color = require(game:GetService("ReplicatedStorage").Shared.Config.Charm).color
local flight = require(script.Parent.Parent.B7ProjectileVisual)(Color3.fromRGB(table.unpack(color)))
local Visual = { render = flight.render, clear = flight.clear }
function Visual.effect(effect)
	if effect.kind == "CharmFire" then
		effect = table.clone(effect)
		effect.kind = "Fire"
	end
	flight.effect(effect)
end
return Visual
