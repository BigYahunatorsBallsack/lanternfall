--!strict
-- Pure engineering formulas; used by StructureService and tests. Primary combat stats do not scale structures.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Rules = {}
function Rules.damage(def, sheet)
	return math.max(
		1,
		math.floor(
			def.damage
				+ def.engineering * (sheet.engineering or 0)
				+ (def.elemental or 0) * (sheet.elementalDamage or 0)
		)
	)
end
function Rules.heal(def, sheet)
	return math.max(1, math.floor(def.damage + def.engineering * (sheet.engineering or 0))) * Config.Stats.hpScale
end
function Rules.interval(def, sheet, improved: boolean)
	local speed = if improved then (sheet.attackSpeed or 0) * Config.Structures.improvedToolsShare else 0
	return math.max(
		Config.Structures.minInterval,
		def.interval * require(game:GetService("ReplicatedStorage").Shared.Util.StatMath).cooldownFactor(speed)
	)
end
function Rules.pierceFactor(def, sheet)
	return math.clamp(
		1 - (def.pierceFalloff or Config.Combat.piercing.falloff) + (sheet.piercingDamage or 0) / 100,
		0,
		1
	)
end
return Rules
