--!strict
-- Structure formulas and the native pet-mine exception; used by StructureService and source-based tests.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local StatMath = require(game:GetService("ReplicatedStorage").Shared.Util.StatMath)
local Timing = require(game:GetService("ReplicatedStorage").Shared.Util.NativeWeaponTiming)
local PetRules = require(script.Parent.PetRules)
local Pets = require(game:GetService("ReplicatedStorage").Shared.Config.Pets)
local Rules = {}
function Rules.critical(def, sheet): (number, number)
	if def.petMine then
		local stats = PetRules.compute(Pets.kinds.BotOMine.mine, sheet, def.petBeastMaster)
		return stats.critChance, stats.critDamage
	end
	local enabled = (sheet.structuresCanCrit or 0) > 0
	return (def.critChance or 0) + (if enabled
		then math.min(Config.Stats.critChanceMax, sheet.critChance or 0) / 100
		else 0),
		(def.critDamage or Config.Player.critMultiplier) + (if enabled then (sheet.critDamage or 0) / 100 else 0)
end
function Rules.damage(def, sheet)
	if def.finalDamageOverride then
		return def.finalDamageOverride
	end
	if def.petMine then
		return PetRules.compute(Pets.kinds.BotOMine.mine, sheet, def.petBeastMaster).damage
	end
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
