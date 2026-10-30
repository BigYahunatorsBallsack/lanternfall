--!strict
-- Effective weapon stats (DESIGN.md sections 4 and 6): the tier I values from Config.Weapons, the tier deltas up to
-- the current tier (Brotato's tiers I-IV since B3), an evolution's overrides and the owner's stats (Config.Stats since B2, Brotato's rules):
--   damage   = max(1, (tiered damage + sum of scaling * stat) * (1 + Damage / 100))
--   timing   = cooldowns and hit intervals times StatMath.cooldownFactor(Attack Speed), never below minCooldown;
--              spinning weapons turn faster by the same factor
--   reach    = rangeKeys + Range * studsPerPoint (melee weapons meleeFactor of it), never below minStuds
--   critChance and lifeSteal as chances per hit (Arsenal rolls them), eliteDamage as a fraction (Damage vs Elites)
-- Since B5 (Brotato's combat, Config.Combat) also per weapon: critChance (the weapon's own plus Crit Chance) and
-- critDamage, lifeSteal (own plus Life Steal), knockback in studs (own plus the Knockback stat), pierce and
-- pierceDamage (the share each further enemy takes of the one before), bounce and bounceDamage, explosionRadius and
-- explosionDamage (Explosion Size and Damage), burnDamage per tick (+100 % Elemental Damage, Damage %), burnSpread
-- and burnInterval (Burning Spread and Speed), and Chain Lightning's jumps grow with Bounce.
-- Pure and unit tested; used by WeaponService/Arsenal whenever a weapon is added, merged or evolved, or stats change.

local Shared = game:GetService("ReplicatedStorage").Shared
local Combat = require(Shared.Config.Combat)
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

-- Factor of every damage the owner deals: 1 + Damage / 100, never below 0.
function WeaponStats.damageFactor(bonuses: Bonuses): number
	return math.max(0, 1 + (bonuses.damage or 0) / 100)
end

-- Damage of an item effect's burn or explosion (B5): (base + sum of scaling * stat) * (1 + Damage / 100), at least 1.
function WeaponStats.ownerDamage(base: number, scaling: { [string]: number }?, bonuses: Bonuses): number
	local damage = base
	for statId, share in scaling or {} do
		damage += share * (bonuses[statId] or 0)
	end
	return math.max(1, damage * WeaponStats.damageFactor(bonuses))
end

-- Share of the damage the next enemy a projectile pierces takes (Brotato): 1 - falloff + Piercing Damage, 0..1.
function WeaponStats.pierceShare(falloff: number, bonuses: Bonuses): number
	return math.clamp(1 - falloff + (bonuses.piercingDamage or 0) / 100, 0, 1)
end

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

	for statId, share in (if weapon.tierScaling then weapon.tierScaling[tier] else weapon.scaling) do
		damage += share * (bonuses[statId] or 0)
	end
	local damageFactor = WeaponStats.damageFactor(bonuses)
	stats.damage = math.max(1, damage * damageFactor)

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
	local reach = (bonuses.range or 0) * rule.studsPerPoint * (if weapon.kind == "Melee" then rule.meleeFactor else 1)
	for _, key in weapon.rangeKeys do
		if stats[key] then
			stats[key] = math.max(rule.minStuds, stats[key] + reach)
		end
	end

	stats.critChance = StatMath.critChance(stats.critChance or Player.critChance, bonuses.critChance or 0)
	stats.critDamage = stats.critDamage or Player.critMultiplier
	stats.lifeSteal = math.clamp((stats.lifeSteal or 0) + (bonuses.lifeSteal or 0) / 100, 0, 1)
	stats.eliteDamage = (bonuses.eliteDamage or 0) / 100
	stats.knockback = math.max(0, (stats.knockback or 0) + (bonuses.knockback or 0)) * Combat.knockback.studsPerPoint

	-- projectiles: piercing and bouncing (pierce -1 flies through everything and does not grow)
	local pierce = stats.pierce
	if pierce then
		if pierce >= 0 then
			stats.pierce = math.max(0, math.floor(pierce + (bonuses.piercing or 0)))
		end
		stats.pierceDamage = WeaponStats.pierceShare(stats.pierceFalloff or Combat.piercing.falloff, bonuses)
		stats.pierceFalloff = nil
	end
	if stats.bounce then
		stats.bounce = math.max(0, math.floor(stats.bounce + (bonuses.bounce or 0)))
		stats.bounceDamage = math.clamp(1 - (stats.bounceFalloff or Combat.bounce.falloff), 0, 1)
		stats.bounceFalloff = nil
	end
	if stats.jumps then
		stats.jumps += math.max(0, math.floor(bonuses.bounce or 0)) -- a chain is a bouncer without falloff
	end

	if stats.explosionRadius then
		stats.explosionRadius *= math.max(0, 1 + (bonuses.explosionSize or 0) / 100)
		stats.explosionDamage = (stats.explosionDamage or 1) * math.max(0, 1 + (bonuses.explosionDamage or 0) / 100)
	end

	if stats.burnDamage then
		stats.burnDamage = math.max(1, (stats.burnDamage + (bonuses.elementalDamage or 0)) * damageFactor)
		stats.burnSpread = math.max(0, math.floor((stats.burnSpread or 0) + (bonuses.burnSpread or 0)))
		stats.burnInterval = StatMath.burnInterval(bonuses.burnSpeed or 0)
		stats.burnChance = stats.burnChance or 1
	end
	return stats
end

return WeaponStats
