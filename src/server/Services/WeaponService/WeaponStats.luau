--!strict
-- Effective weapon stats (DESIGN.md sections 4 and 6): the tier I values from Config.Weapons, the tier deltas up to
-- the current tier (Brotato's tiers I-IV since B3), an evolution's overrides and the owner's stats (Config.Stats since B2, Brotato's rules):
--   damage   = max(1, (tiered damage + sum of scaling * damage stat) * (1 + Damage / 100))
--   timing   = cooldowns and hit intervals times StatMath.cooldownFactor(Attack Speed), never below minCooldown;
--              spinning weapons turn faster by the same factor
--   reach    = rangeKeys + Range * studsPerPoint (melee weapons meleeFactor of it), never below minStuds
--   critChance and lifeSteal as chances per hit (Arsenal rolls them)
-- Pure and unit tested; used by WeaponService/Arsenal whenever a weapon is added, merged or evolved, or stats change.

local Shared = game:GetService("ReplicatedStorage").Shared
local Evolutions = require(Shared.Config.Evolutions)
local Player = require(Shared.Config.Player)
local Stats = require(Shared.Config.Stats)
local Weapons = require(Shared.Config.Weapons)
local StatMath = require(Shared.Util.StatMath)

-- The owner's stats by id (Util/StatMath.Sheet); missing stats count as 0.
export type Bonuses = { [string]: number }

export type Stats = { [string]: number }

local WeaponStats = {}

-- Seconds between attacks or hits: shorter with Attack Speed.
local TIME_STATS = { "cooldown", "tickInterval", "hitCooldownPerEnemy" }
-- Turning speeds: faster with Attack Speed.
local RATE_STATS = { "rotationSpeed" }

-- `minCooldown` keeps Attack Speed from making a weapon fire absurdly fast (Config.Player.minWeaponCooldown).
function WeaponStats.compute(
	weapon: Weapons.Weapon,
	tier: number,
	bonuses: Bonuses,
	evolution: Evolutions.Evolution?,
	minCooldown: number
): Stats
	local stats: Stats = table.clone(weapon.base)
	local damageBonus = 0
	for n = 1, math.min(tier, #weapon.tiers) do
		for key, delta in weapon.tiers[n] :: { [string]: number } do
			if key == "damage" then
				damageBonus += delta
			else
				stats[key] = (stats[key] or 0) + delta
			end
		end
	end

	local damage = (stats.damage or 0) * (1 + damageBonus)
	if evolution then
		for key, value in evolution.stats do
			if key == "damageMultiplier" then
				damage *= value
			else
				stats[key] = value
			end
		end
	end

	for statId, share in weapon.scaling do
		damage += share * (bonuses[statId] or 0)
	end
	stats.damage = math.max(1, damage * math.max(0, 1 + (bonuses.damage or 0) / 100))

	local timing = StatMath.cooldownFactor(bonuses.attackSpeed or 0)
	for _, key in TIME_STATS do
		if stats[key] then
			stats[key] = math.max(minCooldown, stats[key] * timing)
		end
	end
	for _, key in RATE_STATS do
		if stats[key] then
			stats[key] /= timing
		end
	end

	local rule = Stats.range
	local reach = (bonuses.range or 0) * rule.studsPerPoint * (if weapon.class == "Melee" then rule.meleeFactor else 1)
	for _, key in weapon.rangeKeys do
		if stats[key] then
			stats[key] = math.max(rule.minStuds, stats[key] + reach)
		end
	end

	stats.critChance = StatMath.critChance(Player.critChance, bonuses.critChance or 0)
	stats.lifeSteal = math.clamp((bonuses.lifeSteal or 0) / 100, 0, 1)
	return stats
end

return WeaponStats
