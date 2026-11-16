--!strict
-- Source TeamEvolution camp probabilities and scene boost percentages; component for the pending production enemy evolution adapter.
local C = require(game:GetService("ReplicatedStorage").Shared.Config.NativeEnemyEvolution)
local R, S = C.rules, C.settings
local Evolution = {}
export type Variant = "Meca" | "Mutant"
-- Foot means the source BrachiosaurusFoot class only. The caller resolves loot Stats resource identity.
export type Actor = {
	role: "Ordinary" | "Boss" | "Elite" | "Foot",
	lootStatsMatched: boolean,
	zoneEvolvedElites: boolean,
	meca: boolean,
	mutant: boolean,
	motherMeca: boolean,
	motherMutant: boolean,
}
export type PlayerData = { evolution: number, chanceStat: number, dual: boolean }
export type Team = {
	chance: number,
	eliteChance: number,
	mecaWeight: number,
	mutantWeight: number,
	mecaMagnitude: number,
	mutantMagnitude: number,
}
function Evolution.team(players: { PlayerData }, endless: number): Team
	local team: Team =
		{ chance = 0, eliteChance = 0, mecaWeight = 0, mutantWeight = 0, mecaMagnitude = 0, mutantMagnitude = 0 }
	local mecaCount, mutantCount = 0, 0
	for _, player in players do
		local value = player.evolution
		local weighted = math.abs(value * (1 + player.chanceStat / R.percent))
		local factor = R.curveMaximum * (1 - 1 / (1 + weighted / R.curveScale))
		local chance = factor / R.percent / R.chanceDivisor * (1 + endless / R.endlessDivisor)
		team.chance += math.min(1, chance)
		team.eliteChance += math.min(1, chance * R.eliteMultiplier)
		if player.dual and value ~= 0 then
			local magnitude = math.abs(value)
			team.mecaWeight += magnitude
			team.mecaMagnitude += magnitude
			mecaCount += 1
			team.mutantWeight += magnitude
			team.mutantMagnitude += magnitude
			mutantCount += 1
		elseif value > 0 then
			team.mecaWeight += value
			team.mecaMagnitude += value
			mecaCount += 1
		elseif value < 0 then
			team.mutantWeight -= value
			team.mutantMagnitude -= value
			mutantCount += 1
		end
	end
	if #players > 0 then
		team.chance /= #players
		team.eliteChance /= #players
	end
	if mecaCount > 0 then
		team.mecaMagnitude /= mecaCount
	end
	if mutantCount > 0 then
		team.mutantMagnitude /= mutantCount
	end
	return team
end
function Evolution.hasCamp(team: Team): boolean
	return team.mecaWeight + team.mutantWeight > 0
end
function Evolution.drawMeca(team: Team, random: () -> number): boolean
	local total = team.mecaWeight + team.mutantWeight
	return total > 0 and random() * total < team.mecaWeight
end
local function inherited(meca: boolean, mutant: boolean): Variant?
	return if meca then "Meca" elseif mutant then "Mutant" else nil
end
-- Selection precedes the source apply-stage dead/validity guard; no liveness filter belongs before these rolls.
function Evolution.select(team: Team, actor: Actor, chance: (number) -> boolean, random: () -> number): Variant?
	if actor.lootStatsMatched then
		return nil
	end
	if actor.role == "Foot" then
		return inherited(actor.motherMeca, actor.motherMutant)
	end
	if actor.role == "Boss" then
		return if chance(team.chance) then (if Evolution.drawMeca(team, random) then "Meca" else "Mutant") else nil
	end
	if actor.role == "Elite" and actor.zoneEvolvedElites then
		return inherited(actor.meca, actor.mutant)
	end
	if actor.meca or actor.mutant then
		return inherited(actor.meca, actor.mutant)
	end
	if not Evolution.hasCamp(team) then
		return nil
	end
	return if chance(team.chance) then (if Evolution.drawMeca(team, random) then "Meca" else "Mutant") else nil
end
local function scaled(minimum: number, maximum: number, magnitude: number, limit: number, squareRoot: boolean): number
	local depth = math.clamp(math.abs(magnitude), R.minimumMagnitude, limit)
	local progress = (depth - R.minimumMagnitude) / (limit - R.minimumMagnitude)
	if squareRoot then
		progress = math.sqrt(progress)
	end
	return math.round(minimum + (maximum - minimum) * progress)
end
function Evolution.boost(meca: boolean, magnitude: number): { hp: number, damage: number, speed: number }
	if meca then
		return {
			hp = S.hp_boost_meca + (math.modf(math.min(magnitude, R.hpMagnitude))) * S.hp_boost_per_evolution_meca,
			damage = scaled(S.damage_boost_meca_min, S.damage_boost_meca_max, magnitude, R.boostMagnitude, true),
			speed = scaled(S.speed_boost_meca_min, S.speed_boost_meca_max, magnitude, R.boostMagnitude, true),
		}
	end
	return {
		hp = S.hp_boost_mutant + math.round(math.min(magnitude, R.hpMagnitude) * S.hp_boost_per_evolution_mutant),
		damage = scaled(
			S.damage_boost_mutant_min,
			S.damage_boost_mutant_max,
			magnitude,
			R.mutantDamageMagnitude,
			false
		),
		speed = scaled(S.speed_boost_mutant_min, S.speed_boost_mutant_max, magnitude, R.boostMagnitude, true),
	}
end
return Evolution
