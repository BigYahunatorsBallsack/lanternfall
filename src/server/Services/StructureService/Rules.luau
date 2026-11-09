--!strict
-- Pure engineering formulas; used by StructureService and tests. Primary combat stats do not scale structures.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local StatMath = require(game:GetService("ReplicatedStorage").Shared.Util.StatMath)
local Timing = require(game:GetService("ReplicatedStorage").Shared.Util.NativeWeaponTiming)
local Rules = {}
function Rules.damage(def, sheet)
	local flat = math.floor(
		def.damage + def.engineering * (sheet.engineering or 0) + (def.elemental or 0) * (sheet.elementalDamage or 0)
	)
	if def.native then
		return math.max(
			1,
			math.round(
				flat
					* math.max(
						0,
						1
							+ (
									(sheet.structureDamage or 0)
									+ (if def.radius then sheet.explosionDamage or 0 else 0)
								)
								/ 100
					)
			)
		)
	end
	return math.max(1, flat)
end

function Rules.heal(def, sheet)
	return math.max(1, math.floor(def.damage + def.engineering * (sheet.engineering or 0))) * Config.Stats.hpScale
end
function Rules.interval(def, sheet, improved: boolean)
	local speed = (sheet.structureAttackSpeed or 0)
		+ (if improved then (sheet.attackSpeed or 0) * Config.Structures.improvedToolsShare else 0)
	if def.native then
		return math.max(
			Config.Structures.nativeMinimumCooldown,
			math.floor(
				math.max(
					def.cooldownFrames or def.interval * Config.Structures.nativeFrameRate,
					(sheet.weaponCooldownMin or 0) * Config.Structures.nativeFrameRate
				) * Timing.factor(speed)
			)
		) / Config.Structures.nativeFrameRate
	end
	return math.max(
		Config.Structures.minInterval,
		sheet.weaponCooldownMin or 0,
		def.interval * StatMath.cooldownFactor(speed)
	)
end
function Rules.spawnInterval(def, sheet, improved: boolean)
	if not def.native then
		return Rules.interval(def, sheet, improved)
	end
	local speed = (sheet.structureAttackSpeed or 0)
		+ (if improved then (sheet.attackSpeed or 0) * Config.Structures.improvedToolsShare else 0)
	return math.max(
		Config.Structures.nativeMinimumCooldown,
		math.floor((def.spawnCooldown or def.interval) * Timing.factor(speed))
	)
end
function Rules.range(def, sheet)
	return math.max(
		Config.Stats.range.minStuds,
		def.range + (sheet.structureRange or 0) * Config.Stats.range.studsPerPoint
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
