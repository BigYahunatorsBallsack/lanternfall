--!strict
-- Effective weapon stats (DESIGN.md section 6): the level 1 values from Config.Weapons, the level deltas up to the
-- current level, an evolution's overrides and the owner's bonuses (class now, passives and talents later). Pure and
-- unit tested; used by WeaponService/Arsenal whenever a weapon is added, levelled or evolved, or bonuses change.

local Shared = game:GetService("ReplicatedStorage").Shared
local Evolutions = require(Shared.Config.Evolutions)
local Weapons = require(Shared.Config.Weapons)

-- Summed bonus fractions by stat name, the same names as Config.Passives and class bonuses
-- (e.g. { cooldown = -0.1, damage = 0.2, area = 0.15 }). Stats a weapon does not use are ignored.
export type Bonuses = { [string]: number }

export type Stats = { [string]: number }

local WeaponStats = {}

-- Weapon stats that grow with the owner's "area" bonus.
local AREA_STATS = { "radius", "explosionRadius" }

-- `minCooldown` keeps cooldown bonuses from making a weapon fire absurdly fast (Config.Player.minWeaponCooldown).
function WeaponStats.compute(
	weapon: Weapons.Weapon,
	level: number,
	bonuses: Bonuses,
	evolution: Evolutions.Evolution?,
	minCooldown: number
): Stats
	local stats: Stats = table.clone(weapon.base)
	local damageBonus = 0
	for n = 1, math.min(level, #weapon.levels) do
		for key, delta in weapon.levels[n] :: { [string]: number } do
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

	stats.damage = damage * math.max(0, 1 + (bonuses.damage or 0))
	if stats.cooldown then
		stats.cooldown = math.max(minCooldown, stats.cooldown * math.max(0, 1 + (bonuses.cooldown or 0)))
	end
	local area = math.max(0, 1 + (bonuses.area or 0))
	for _, key in AREA_STATS do
		if stats[key] then
			stats[key] *= area
		end
	end
	return stats
end

return WeaponStats
