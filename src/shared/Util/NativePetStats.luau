--!strict
-- Shared original pet scaling and weapon statistics; server PetRules and client PetText use identical arithmetic.
local Shared = script.Parent.Parent
local C = require(Shared.Config.Pets)
local Stats = require(Shared.Config.Stats)
local Combat = require(Shared.Config.Combat)
local Ranged = require(script.Parent.NativeRangedStats)
local Damage = require(script.Parent.NativeWeaponDamage)
local Rules = {}

function Rules.scaling(base: { { any } }, beastMaster: boolean?, modifiers: { [string]: number }?): { [string]: number }
	local result = {}
	for _, row in base do
		result[row[1]] = row[2]
	end
	if beastMaster and #base > 0 then
		for _, id in C.beastMasterStats do
			if result[id] == nil then
				result[id] = base[1][2]
			end
		end
	end
	-- Native weapon_scaling_stats effects are applied after Beast Master's missing-entry expansion.
	for id, percent in modifiers or {} do
		result[id] = (result[id] or 0) + percent / 100
	end
	return result
end

-- Intrinsic pet burn keeps its own scaling; global burn contributes only its flat base damage.
function Rules.weaponScaling(def: any, sheet: { [string]: number }, beastMaster: boolean?): { [string]: number }
	return Damage.scaling(Rules.scaling(def.scaling, beastMaster), sheet)
end

function Rules.burnDamage(def: any, sheet: { [string]: number }, beastMaster: boolean?): number
	local flat = def.damage + (sheet.nativeGlobalBurnDamage or 0)
	for id, share in Rules.scaling(def.scaling, beastMaster) do
		flat += share * (sheet[id] or 0)
	end
	return Damage.total(flat, Damage.factor(sheet, false), { nativeTiming = 1 })
end

function Rules.compute(
	def: any,
	sheet: { [string]: number },
	beastMaster: boolean?,
	structuresCanCrit: boolean?,
	scalingModifiers: { [string]: number }?
): any
	local flat = def.damage
	for id, share in Damage.scaling(Rules.scaling(def.scaling, beastMaster, scalingModifiers), sheet) do
		flat += share * (sheet[id] or 0)
	end
	local percent = (sheet.damage or 0)
		+ (if def.isStructure then sheet.structureDamage or 0 else 0)
		+ (if def.exploding then sheet.explosionDamage or 0 else 0)
	local rangeBonus = if def.isStructure
		then sheet.structureRange or 0
		else (sheet.range or 0) * (if def.isRanged then 1 else Stats.range.meleeFactor)
	local critical = not def.isStructure or structuresCanCrit == true or (sheet.structuresCanCrit or 0) > 0
	local knockback = sheet.knockback or 0
	if def.negativeKnockback and not def.positiveKnockback then
		knockback = -knockback
	end
	knockback += def.knockbackPoints
	if not def.positiveKnockback then
		knockback = math.min(0, knockback)
	end
	if not def.negativeKnockback then
		knockback = math.max(0, knockback)
	end
	if (sheet.negativeKnockback or 0) > 0 then
		if def.knockbackPoints < 0 then
			knockback -= sheet.knockback or 0
		elseif knockback >= 0 then
			knockback = -knockback
		end
	end
	local stats: any = {
		damage = Damage.total(flat, math.max(0, 1 + percent / 100), { nativeTiming = 1 }),
		cooldown = math.max(
			C.minimumCooldownFrames,
			math.floor(def.cooldownFrames),
			math.ceil((sheet.weaponCooldownMin or 0) * C.frameRate)
		) / C.frameRate,
		range = math.floor(math.max(C.minimumRangePoints + def.minRangePoints, def.rangePoints + rangeBonus))
			* Stats.range.studsPerPoint,
		critChance = def.critChance
			+ (if critical then math.min(Stats.critChanceMax, sheet.critChance or 0) / 100 else 0),
		critDamage = def.critDamage + (if critical then (sheet.critDamage or 0) / 100 else 0),
		lifeSteal = def.lifeSteal + (if def.isStructure then 0 else (sheet.lifeSteal or 0) / 100),
		knockback = knockback * Combat.knockback.studsPerPoint,
	}
	if def.isRanged then
		stats.projectileSpeed = def.projectileSpeedPoints * Stats.range.studsPerPoint
		stats.nativeAccuracy, stats.nativeSpread, stats.count = def.nativeAccuracy, def.nativeSpread, def.count
		stats.pierce = def.pierce + (sheet.piercing or 0)
		stats.pierceDamage = math.clamp(1 - def.pierceFalloff + (sheet.piercingDamage or 0) / 100, 0, 1)
		stats.bounce = if def.canBounce then def.bounce + (sheet.bounce or 0) else 0
		stats.bounceDamage = math.clamp(1 - def.bounceFalloff + (sheet.bounceDamage or 0) / 100, 0, 1)
		Ranged.apply(stats, sheet)
	end
	return stats
end

return Rules
