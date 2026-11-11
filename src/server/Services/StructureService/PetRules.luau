--!strict
-- Original pet weapon arithmetic and movement speed; used by StructureService pet attacks and focused source tests.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.Pets)
local Stats = require(Shared.Config.Stats)
local Combat = require(Shared.Config.Combat)
local Ranged = require(Shared.Util.NativeRangedStats)
local Damage = require(Shared.Util.NativeWeaponDamage)
local Rules = {}

-- Boss.take_damage applies its positive bonus to integer hitbox damage before Unit.take_damage rolls the critical.
function Rules.hitDamage(
	base: number,
	share: number?,
	criticalMultiplier: number,
	boss: boolean,
	bossBonus: number
): number
	local amount = math.max(1, math.floor(base * (share or 1)))
	if boss and bossBonus > 0 then
		amount = math.floor(amount * (1 + bossBonus / 100))
	end
	return math.max(1, math.round(amount * criticalMultiplier))
end

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
	for id, share in Rules.scaling(def.scaling, beastMaster, scalingModifiers) do
		flat += share * (sheet[id] or 0)
	end
	local percent = (sheet.damage or 0)
		+ (if def.isStructure then sheet.structureDamage or 0 else 0)
		+ (if def.exploding then sheet.explosionDamage or 0 else 0)
	local rangeBonus = if def.isStructure
		then sheet.structureRange or 0
		else (sheet.range or 0) * (if def.isRanged then 1 else Stats.range.meleeFactor)
	local critical = not def.isStructure or structuresCanCrit == true
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

function Rules.speed(def: any, sheet: { [string]: number }): number
	return def.speedPoints * Stats.range.studsPerPoint * math.max(1, 1 + (sheet.speed or 0) / 100)
end
-- Bonk Dog requests Godot 3.5 TRANS_EXPO/EASE_IN_OUT, including that engine's small endpoint correction.
-- Mathematical reference: github.com/godotengine/godot/blob/3.5/scene/animation/easing_equations.h (expo::in_out).
function Rules.jumpShare(t: number): number
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	return if t < 0.5 then 0.5 * 2 ^ (10 * (2 * t - 1)) - 0.0005 else 0.50025 * (2 - 2 ^ (-10 * (2 * t - 1)))
end
return Rules
