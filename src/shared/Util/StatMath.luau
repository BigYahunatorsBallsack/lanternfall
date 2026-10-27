--!strict
-- Stat formulas from Brotato as pure functions (DESIGN.md section 4, since B2), numbers in Config.Stats and
-- Config.Items.tiers: summing a stat sheet, armor, dodge, HP regeneration, attack speed, move speed and the rarity
-- tier roll. Used by StatService, CombatService, WeaponStats, ShopRules and UpgradePool on the server and by the stat
-- panel on the client; tested in tests/StatMath.spec.luau.

local Config = require(script.Parent.Parent.Config)

local Stats = Config.Stats

export type Sheet = { [string]: number } -- stat id -> value (Config.Stats units)

local StatMath = {}

-- A sheet with every stat at its start value: base Max HP from Config.Player, everything else 0.
function StatMath.baseSheet(): Sheet
	local sheet: Sheet = {}
	for _, stat in Stats.order do
		sheet[stat.id] = 0
	end
	sheet.maxHp = Config.Player.maxHp
	return sheet
end

-- Adds `stats` times `count` to `sheet` (in place) and returns it. Unknown stat ids are added too (ConfigCheck
-- reports them).
function StatMath.add(sheet: Sheet, stats: { [string]: number }, count: number?): Sheet
	local times = count or 1
	for id, value in stats do
		sheet[id] = (sheet[id] or 0) + value * times
	end
	return sheet
end

-- Max HP the player actually has: never below 1.
function StatMath.maxHp(sheet: Sheet): number
	return math.max(1, math.round(sheet.maxHp or Config.Player.maxHp))
end

-- Share of a hit's damage the player takes with `armor` (Brotato): 1 / (1 + armor / 15), more with negative armor.
function StatMath.armorFactor(armor: number): number
	local divisor = Stats.armor.divisor
	if armor >= 0 then
		return 1 / (1 + armor / divisor)
	end
	return (divisor - 2 * armor) / (divisor - armor)
end

-- Chance (0..1) to dodge a hit, capped at Config.Stats.dodge.max.
function StatMath.dodgeChance(dodge: number): number
	return math.clamp(dodge, 0, Stats.dodge.max) / 100
end

-- HP healed per second by HP Regeneration (in our HP, hpScale per tick). 0 below 1 regen.
function StatMath.regenPerSecond(regen: number): number
	if regen < 1 then
		return 0
	end
	local rule = Stats.regen
	local seconds = rule.baseSeconds / (1 + (regen - 1) / rule.divisor)
	return Stats.hpScale / seconds
end

-- Factor for weapon cooldowns from Attack Speed: halved at +100 %, slower (but less) with negative values.
function StatMath.cooldownFactor(attackSpeed: number): number
	if attackSpeed >= 0 then
		return 1 / (1 + attackSpeed / 100)
	end
	return 1 + (-attackSpeed / 100) * Stats.attackSpeed.negativeFactor
end

-- Factor for move speed from Speed (+10 = 10 % faster), never below Config.Stats.minSpeedFactor.
function StatMath.speedFactor(speed: number): number
	return math.max(Stats.minSpeedFactor, 1 + speed / 100)
end

-- Chance (0..1) that a weapon hit crits: the base crit plus Crit Chance, capped.
function StatMath.critChance(baseChance: number, critStat: number): number
	return math.clamp(baseChance + critStat / 100, 0, Stats.critChanceMax / 100)
end

-- Chance of rarity tier `tier` (Config.Items.tiers) at wave or level `wave` with `luck`, before the rarer tiers
-- are rolled: (perWave * (wave - minWave + 1) + base) * (1 + luck / 100), between 0 and max.
function StatMath.tierChance(tier: number, wave: number, luck: number): number
	local rule = Config.Items.tiers[tier]
	if not rule or wave < rule.minWave then
		return 0
	end
	local chance = (rule.perWave * (wave - rule.minWave + 1) + rule.base) * (1 + luck / 100)
	return math.clamp(chance, 0, rule.max)
end

-- Rolls a rarity tier with one number 0 <= roll < 1, rarest first (Brotato): roll < chance(4) gives 4, else
-- < chance(3) gives 3, and so on; tier 1 takes the rest.
function StatMath.rollTier(wave: number, luck: number, roll: number): number
	for tier = #Config.Items.tiers, 2, -1 do
		if roll < StatMath.tierChance(tier, wave, luck) then
			return tier
		end
	end
	return 1
end

-- How a stat value reads on cards and in the panel: "+5% Damage", "-1 Armor", "+30 Max HP".
function StatMath.format(statId: string, value: number): string
	local stat = Stats.byId[statId]
	local name = if stat then stat.displayName else statId
	local percent = if stat and stat.percent then "%" else ""
	local magnitude = math.abs(value)
	local text = if magnitude == math.floor(magnitude) then tostring(magnitude) else string.format("%.1f", magnitude)
	return `{if value < 0 then "-" else "+"}{text}{percent} {name}`
end

return StatMath
