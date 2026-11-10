--!strict
-- Native Buffer boosts change turret base stats but mine final damage; StructureService applies and restores these definitions.
local Rules = require(script.Parent.Rules)
local Boost = {}
function Boost.definition(base: any, sheet: { [string]: number }, damage: number, range: number, speed: number): any
	local result = table.clone(base)
	if base.boostMode == "Trap" then
		return result
	end -- Entity.boost only marks DartTrap; it has no stat override
	if base.boostMode == "Mine" then
		result.finalDamageOverride = math.floor(Rules.damage(base, sheet) * (1 + damage / 100))
		result.radius = base.radius * (1 + range / 100)
	else
		result.damage = math.floor(base.damage * (1 + damage / 100))
		result.range = base.range * (1 + range / 100)
		result.interval = base.interval * (1 - speed / 100)
		if base.cooldownFrames then
			result.cooldownFrames = math.floor(base.cooldownFrames * (1 - speed / 100))
		end
	end
	return result
end
return Boost
