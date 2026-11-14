--!strict
-- Native transform-offset volleys with per-projectile angle/speed; called by hostile and charmed enemy shooters.
local Volley = {}
export type Rule = {
	count: number,
	spread: number,
	constantSpread: boolean,
	offsetX: number,
	offsetZ: number,
	speedStep: number,
}
function Volley.emit(
	rule: Rule,
	x: number,
	z: number,
	tx: number,
	tz: number,
	speed: number,
	random: () -> number,
	emit: (number, number, number, number, number) -> ()
)
	local px = x + (if tx < x then -rule.offsetX else rule.offsetX)
	local pz = z + rule.offsetZ
	local base = math.atan2(tz - pz, tx - px)
	for index = 0, rule.count - 1 do
		local spread = (random() * 2 - 1) * rule.spread
		if rule.constantSpread and rule.count > 1 then
			spread = -rule.spread + index * (2 * rule.spread / (rule.count - 1))
		end
		local angle = base + spread
		emit(px, pz, math.cos(angle), math.sin(angle), speed + rule.speedStep * index)
	end
end
return Volley
