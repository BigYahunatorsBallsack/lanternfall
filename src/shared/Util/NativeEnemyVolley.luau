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
	scaleWithCount: boolean?,
	minimumScale: number?,
	specificDegrees: { number }?,
	parallel: { spacing: number, angleOffset: number, forwardOffset: number }?,
	spawnRing: { radius: number, away: boolean }?,
}
function Volley.emit(
	rule: Rule,
	x: number,
	z: number,
	tx: number,
	tz: number,
	speed: number,
	random: () -> number,
	emit: (number, number, number, number, number, number) -> ()
)
	local px = x + (if tx < x then -rule.offsetX else rule.offsetX)
	local pz = z + rule.offsetZ
	local base = math.atan2(tz - pz, tx - px)
	for index = 0, rule.count - 1 do
		local sx, sz = px, pz
		if rule.spawnRing then
			local ringAngle = random() * 2 * math.pi
			if rule.constantSpread then
				ringAngle = index * 2 * math.pi / rule.count
			end
			sx += math.cos(ringAngle) * rule.spawnRing.radius
			sz += math.sin(ringAngle) * rule.spawnRing.radius
		end
		local spread = if rule.parallel then 0 else (random() * 2 - 1) * rule.spread
		if rule.constantSpread and rule.count > 1 then
			spread = -rule.spread + index * (2 * rule.spread / (rule.count - 1))
		end
		local angle = base + spread
		-- Source specific angles replace the aim, but a constant-spread fan overrides them again.
		if rule.specificDegrees and not (rule.constantSpread and rule.count > 1) then
			angle = math.rad(assert(rule.specificDegrees[index + 1], "Missing source volley angle"))
		end
		if rule.parallel then
			local p = rule.parallel
			local dx, dz = math.cos(base), math.sin(base)
			local side = (index - (rule.count - 1) * 0.5) * p.spacing
			-- Godot Vector2.tangent is (y,-x), including the lone-projectile negative-angle endpoint.
			sx += dx * p.forwardOffset + dz * side
			sz += dz * p.forwardOffset - dx * side
			angle = base - p.angleOffset + 2 * p.angleOffset * index / math.max(1, rule.count - 1)
		end
		if rule.spawnRing and rule.spawnRing.away then
			angle = math.atan2(sz - z, sx - x)
		end
		local scale = 1
		if rule.scaleWithCount then
			local minimum = assert(rule.minimumScale, "Scaled native volley requires its source minimum scale")
			if rule.count > 1 then
				local centerDistance = math.abs(index / (rule.count - 1) - 0.5) * 2
				scale = 1 + (minimum - 1) * centerDistance
			end
			if minimum > 1 then
				scale = minimum
			end
		end
		emit(sx, sz, math.cos(angle), math.sin(angle), speed + rule.speedStep * index, scale)
	end
end
return Volley
