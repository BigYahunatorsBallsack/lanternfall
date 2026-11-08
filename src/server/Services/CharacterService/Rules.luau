--!strict
-- Pure native character live-effect policies; CharacterService composes these with existing stat/item layers.
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.CharacterCatalog)
local C = require(Shared.Config.CharacterMechanics)
local StatMath = require(Shared.Util.StatMath)
local Explosions = require(Shared.Config.CharacterExplosions)

export type HalfConversion = { source: string, target: string, per: number, percent: number, targetAmount: number }
export type Strike = { stat: string, percent: number, chance: number }
export type Policy = {
	source: Catalog.CatalogCharacter,
	halfConversions: { HalfConversion },
	onHurt: StatMath.Sheet,
	onDodge: StatMath.Sheet,
	onFullConsumable: StatMath.Sheet,
	still: StatMath.Sheet,
	moving: StatMath.Sheet,
	belowHalf: StatMath.Sheet,
	selfDamage: number,
	stillMaterials: number,
	stillMaterialsMax: number,
	healStrike: Strike?,
	pickupStrike: Strike?,
	consumableExplosion: { definition: Explosions.Definition, chance: number }?,
	hurtExplosion: { definition: Explosions.Definition, chance: number }?,
	canAttackMoving: boolean,
	waveEnemyPercent: number,
	waveTreeMaterials: number,
	waveLivingEnemyMaterials: number,
}
export type WaveContext = {
	enemies: number,
	trees: number,
	removedForPerformance: number,
	horde: boolean,
	eliteBonus: number?,
	charmedBonus: number?,
}
export type Context = {
	hp: number,
	maxHp: number,
	moving: boolean?,
	counts: { [string]: number },
	items: { [string]: number },
}

local Rules = {}

function Rules.numberParameter(effect: Catalog.SourceEffect, name: string, fallback: number): number
	for _, parameter in effect.parameters do
		if parameter.name == name and parameter.numberValue ~= nil then
			return parameter.numberValue
		end
	end
	return fallback
end

function Rules.compile(classId: string): Policy?
	local source = Catalog[classId]
	if not source then
		return nil
	end
	local policy: Policy = {
		source = source,
		halfConversions = {},
		onHurt = {},
		onDodge = {},
		onFullConsumable = {},
		still = {},
		moving = {},
		belowHalf = {},
		selfDamage = 0,
		stillMaterials = 0,
		stillMaterialsMax = math.huge,
		canAttackMoving = source.canAttackWhileMoving ~= false,
		waveEnemyPercent = 0,
		waveTreeMaterials = 0,
		waveLivingEnemyMaterials = 0,
	}
	StatMath.add(policy.still, source.stationaryStats)
	for _, effect in source.remainingRules do
		local key, custom, amount = effect.sourceKey, effect.customKey, effect.amount
		local stat = C.statIds[key]
		local target: StatMath.Sheet? = nil
		if custom == "temp_stats_on_hit" then
			target = policy.onHurt
		elseif custom == "temp_stats_on_dodge" then
			target = policy.onDodge
		elseif custom == "consumable_stats_while_max" then
			target = policy.onFullConsumable
		elseif custom == "temp_stats_while_not_moving" then
			target = policy.still
		elseif custom == "temp_stats_while_moving" then
			target = policy.moving
		elseif custom == "stats_below_half_health" then
			target = policy.belowHalf
		end
		if target and stat then
			target[stat] = (target[stat] or 0) + amount
		end
		if custom == "convert_stats_half_wave" then
			local targetStat: string? = nil
			for _, parameter in effect.parameters do
				if parameter.name == "to_stat" and parameter.stringValue then
					targetStat = C.statIds[parameter.stringValue]
				end
			end
			assert(stat and targetStat and amount > 0, "Invalid native half-wave conversion")
			table.insert(policy.halfConversions, {
				source = stat,
				target = targetStat,
				per = amount,
				percent = Rules.numberParameter(effect, "pct_converted", 0),
				targetAmount = Rules.numberParameter(effect, "to_value", 0),
			})
		end
		if key == "lose_hp_per_second" then
			policy.selfDamage += amount
		end
		if key == "percent_materials" and custom == "temp_stats_while_not_moving" then
			policy.stillMaterials = amount
			policy.stillMaterialsMax = Rules.numberParameter(effect, "value2", math.huge)
		end
		if custom == "dmg_when_heal" or custom == "dmg_when_pickup_gold" then
			assert(stat, `Unknown native character strike stat {key}`)
			local strike =
				{ stat = stat, percent = amount, chance = Rules.numberParameter(effect, "chance", 100) / 100 }
			if custom == "dmg_when_heal" then
				policy.healStrike = strike
			else
				policy.pickupStrike = strike
			end
		end
		if key == "can_attack_while_moving" then
			policy.canAttackMoving = amount ~= 0
		end
		if
			(key == "explode_on_hit" or key == "explode_on_consumable")
			and effect.effectType == "res://effects/items/item_exploding_effect.gd"
		then
			for _, parameter in effect.parameters do
				if parameter.name == "stats" and parameter.resource then
					local definition = Explosions.bySource[parameter.resource]
					assert(definition, `Unknown native hurt explosion {parameter.resource}`)
					local explosion = {
						definition = definition,
						chance = Rules.numberParameter(effect, "chance", 1),
					}
					if key == "explode_on_hit" then
						policy.hurtExplosion = explosion
					else
						policy.consumableExplosion = explosion
					end
				end
			end
		end
		if effect.effectType == "res://items/global/effect.gd" and custom == "" and effect.storageMethod == 0 then
			if key == "pacifist" then
				policy.waveEnemyPercent += amount
			elseif key == "cryptid" then
				policy.waveTreeMaterials += amount
			elseif key == "materials_per_living_enemy" then
				policy.waveLivingEnemyMaterials += amount
			end
		end
	end
	return policy
end

-- Native harvesting sums all bonuses before deciding whether to grant XP or only remove materials.
function Rules.waveReward(policy: Policy, harvesting: number, context: WaveContext): number
	local pacifist = math.round((context.enemies + context.removedForPerformance) * policy.waveEnemyPercent / 100)
	if context.horde then
		pacifist = math.floor(pacifist / 2)
	end
	return harvesting
		+ pacifist
		+ context.trees * policy.waveTreeMaterials
		+ context.enemies * policy.waveLivingEnemyMaterials
		+ (context.eliteBonus or 0)
		+ (context.charmedBonus or 0)
end

function Rules.dynamic(policy: Policy, context: Context): StatMath.Sheet
	local sheet: StatMath.Sheet = {}
	if context.moving ~= nil then
		StatMath.add(sheet, if context.moving then policy.moving else policy.still)
	end
	if context.hp < context.maxHp * C.lowHealthShare then
		StatMath.add(sheet, policy.belowHalf)
	end
	for _, conversion in policy.source.conversions do
		local value: number? = nil
		if conversion.sourceKind == "Count" then
			value = context.counts[conversion.source] or 0
		elseif conversion.sourceKind == "Item" then
			value = context.items[conversion.source] or 0
		end
		if value ~= nil then
			sheet[conversion.target] = (sheet[conversion.target] or 0)
				+ math.modf(conversion.amount * value / conversion.per)
		end
	end
	return sheet
end

-- Native stat-triggered damage rounds the stat-derived base down before applying ordinary percent damage.
function Rules.statStrike(strike: Strike, sheet: StatMath.Sheet): number
	local base = math.floor(math.max(C.minimumStatStrike, (sheet[strike.stat] or 0) * strike.percent / 100))
	return math.max(0, math.round(base * (1 + (sheet.damage or 0) / 100)))
end

function Rules.periodicMaterials(policy: Policy, held: number): number
	if policy.stillMaterials == 0 then
		return 0
	end
	return math.floor(math.min(policy.stillMaterialsMax, math.max(1, math.abs(held * policy.stillMaterials / 100))))
end

-- Stable Utils.convert_stats uses permanent RunData stats, integer chunks and compensation before TempStats gains.
function Rules.halfWaveConversion(policy: Policy, permanent: StatMath.Sheet): StatMath.Sheet
	local result: StatMath.Sheet = {}
	for _, conversion in policy.halfConversions do
		local value = math.modf(permanent[conversion.source] or 0)
		local chunks = math.max(0, math.floor(value * conversion.percent / 100 / conversion.per))
		if chunks == 0 then
			break
		end
		local removed = chunks * conversion.per
		local added = chunks * conversion.targetAmount
		local sourceGain = policy.source.gainMultipliers[conversion.source] or 1
		local targetGain = policy.source.gainMultipliers[conversion.target] or 1
		if sourceGain > 0 then
			removed = math.round(removed / sourceGain)
		end
		if targetGain > 0 then
			added = math.round(added / targetGain)
		end
		result[conversion.source] = (result[conversion.source] or 0) - removed
		result[conversion.target] = (result[conversion.target] or 0) + added
	end
	return result
end

return Rules
