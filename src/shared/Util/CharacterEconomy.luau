--!strict
-- Native character economy arithmetic used by material drops, harvesting and recycling; values come from Config.
local Shared = script.Parent.Parent
local Mechanics = require(Shared.Config.CharacterMechanics).economy
local Stats = require(Shared.Config.Stats)
local Shop = require(Shared.Config.Shop)
local Run = require(Shared.Config.Run)
local Rules = require(script.Parent.CharacterRules)
local Danger = require(script.Parent.DangerRules)
local Coop = require(Shared.Config.EnemyWaves).coop
local Economy = {}
function Economy.priceInflation(wave: number): number
	return 1 + Danger.endlessFactor(wave) / Mechanics.priceEndlessDivisor
end
-- Brotato CoopService.get_coop_materials_factor: the extra share of material value for `players` players, so the
-- team gets back about what the extra co-op enemies cost.
function Economy.coopMaterials(players: number): number
	if players <= 1 then
		return 0
	end
	local enemies = 1 + Coop.enemiesPerPlayer * (players - 1)
	return (players / enemies - 1) * Mechanics.coopMaterialsFactor
end
function Economy.materialValue(base: number, classIds: { string }, isEnemy: boolean): number
	if #classIds == 0 then
		return base
	end
	local value = base + base * Economy.coopMaterials(#classIds)
	local all, typed = 0, 0
	for _, classId in classIds do
		all += Rules.nativeAmount(classId, "gold_drops")
		typed += Rules.nativeAmount(classId, if isEnemy then "enemy_gold_drops" else "neutral_gold_drops")
	end
	local total = math.modf(all / #classIds) + math.modf(typed / #classIds)
	return math.max(base * Mechanics.minimumMaterialFactor, value + value * total / 100)
end
function Economy.materialCount(base: number, classIds: { string }, isEnemy: boolean, roll: number): number
	local value = Economy.materialValue(base, classIds, isEnemy)
	local whole = math.floor(value)
	return whole + (if roll < value - whole then 1 else 0)
end
function Economy.recyclingPrice(recycleBasis: number, shopPrice: number, gains: number): number
	local share = math.clamp(Shop.sellShare + gains / 100, Mechanics.minimumRecycleShare, Mechanics.maximumRecycleShare)
	return math.min(shopPrice, math.max(Mechanics.minimumRecycleValue, math.floor(recycleBasis * share)))
end
function Economy.harvestingGrowth(classId: string?, harvesting: number, wave: number): number
	if harvesting <= 0 then
		return 0
	end
	if wave > #Run.spawn.waves.lengthsSeconds then
		return -math.ceil(harvesting * Mechanics.endlessHarvestingDecrease)
	end
	return math.ceil(harvesting * (Stats.harvesting.growth + Rules.nativeAmount(classId, "harvesting_growth") / 100))
end
return Economy
