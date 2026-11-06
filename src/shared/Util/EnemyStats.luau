--!strict
-- Pure enemy growth and appearance rules, read by EnemySim, SpawnRules and RunSchedule.
local Enemies = require(script.Parent.Parent.Config.Enemies)

local EnemyStats = {}

function EnemyStats.firstWave(kind: Enemies.Enemy, danger: number): number
	local first = kind.firstWave or 1
	local best = -1
	for level, wave in kind.firstWaveByDanger or {} do
		if danger >= level and level > best then
			best, first = level, wave
		end
	end
	return first
end

function EnemyStats.canSpawn(kind: Enemies.Enemy, wave: number, danger: number): boolean
	return not kind.specialSpawn and danger >= (kind.minDanger or 0) and wave >= EnemyStats.firstWave(kind, danger)
end

function EnemyStats.baseShot(kind: Enemies.Enemy): number
	if kind.ranged then
		return kind.ranged.projectileDamage
	elseif kind.slash then
		return kind.slash.damage
	elseif kind.retaliate then
		return kind.retaliate.projectileDamage
	elseif kind.charge then
		return kind.charge.projectileDamage or 0
	end
	return 0
end

-- Contact and projectile/slash damage have independent increments in the wiki.
function EnemyStats.growth(kind: Enemies.Enemy, wave: number): (number, number, number)
	local steps = math.max(0, math.floor(wave) - 1)
	local shot = EnemyStats.baseShot(kind)
	return if kind.hp > 0 then 1 + kind.hpPerWave * steps / kind.hp else 1,
		if kind.contactDamage > 0 then 1 + kind.damagePerWave * steps / kind.contactDamage else 1,
		if shot > 0 then 1 + (kind.shotDamagePerWave or kind.damagePerWave) * steps / shot else 1
end

-- One sample per spawn; speed does not grow with the wave or danger level.
function EnemyStats.speedFactor(kind: Enemies.Enemy, roll: number): number
	return if kind.speed > 0 and kind.speedMax then 1 + (kind.speedMax / kind.speed - 1) * math.clamp(roll, 0, 1) else 1
end

return EnemyStats
