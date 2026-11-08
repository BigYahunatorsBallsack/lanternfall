--!strict
-- Pure native character live-effect policies; CharacterService composes these with existing stat/item layers.
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.CharacterCatalog)
local C = require(Shared.Config.CharacterMechanics)
local StatMath = require(Shared.Util.StatMath)
local Explosions = require(Shared.Config.CharacterExplosions)

export type Strike = { stat: string, percent: number, chance: number }
export type Policy = {
	source: Catalog.CatalogCharacter,
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
		if key == "explode_on_hit" and effect.effectType == "res://effects/items/item_exploding_effect.gd" then
			for _, parameter in effect.parameters do
				if parameter.name == "stats" and parameter.resource then
					local definition = Explosions.bySource[parameter.resource]
					assert(definition, `Unknown native hurt explosion {parameter.resource}`)
					policy.hurtExplosion = {
						definition = definition,
						chance = Rules.numberParameter(effect, "chance", 1),
					}
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

return Rules
