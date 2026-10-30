--!strict
-- Texts of item effects (DESIGN.md sections 6 and 13, since B4), built from Config.Effects records, Config.Stats and
-- Config.Weapons: one line per effect for shop cards and chest rewards ("Wave end: +3% Damage", "+8 Armor while
-- standing still", "Kill (crit): +1 Shard (33%)", since B5 "Hit: burn 3x1 (+100% Elemental Damage) (25%)", since B8
-- "Kill: 1 (+25% Luck) damage to a random enemy (25%)"), the feedback text when an effect pays out ("+50 HP") and the
-- HUD's active bonus lines ("+8 Armor (standing still)"). Used by UpgradeText, ProcTextController and the HUD;
-- tested in tests/EffectRules.spec.luau.

local Config = require(script.Parent.Parent.Config)
local Effects = require(script.Parent.Parent.Config.Effects)
local Types = require(script.Parent.Parent.Net.Types)
local Format = require(script.Parent.Format)
local StatMath = require(script.Parent.StatMath)

local EffectText = {}

local TRIGGER_TEXT: { [string]: string } = {
	Acquire = "When taken",
	WaveStart = "Wave start",
	WaveEnd = "Wave end",
	ShopEnter = "Shop",
	Reroll = "Reroll",
	Buy = "Purchase",
	Sell = "Sale",
	LevelUp = "Level-up",
	Hit = "Hit",
	Crit = "Crit",
	Kill = "Kill",
	Dodge = "Dodge",
	Hurt = "Hit taken",
	Pickup = "Orb",
	Chest = "Chest",
	Consumable = "Fruit or crate",
}

local KIND_TEXT: { [string]: string } = {
	Still = "standing still",
	Moving = "moving",
	Wave = "this wave",
	Timed = "for now",
	NextWave = "this wave",
}

local function number(value: number): string
	if value == math.floor(value) then
		return tostring(value)
	end
	return string.format("%.1f", value)
end

local function plural(count: number, noun: string): string
	return if math.abs(count) == 1 then `{number(count)} {noun}` else `{number(count)} {noun}s`
end

-- "+3 Melee Damage, -10 Max HP" in the order of the stat panel.
function EffectText.stats(stats: { [string]: number }?): string
	local parts = {}
	for _, stat in Config.Stats.order do
		local value = stats and stats[stat.id]
		if value and value ~= 0 then
			table.insert(parts, StatMath.format(stat.id, value))
		end
	end
	return table.concat(parts, ", ")
end

-- What a damage scales with (Brotato's notation, B5): "+100% Elemental Damage, +50% Melee Damage"; "" for none.
function EffectText.scaling(scaling: { [string]: number }?): string
	local parts = {}
	for _, stat in Config.Stats.order do
		local share = scaling and scaling[stat.id]
		if share and share ~= 0 then
			table.insert(parts, `{if share > 0 then "+" else "-"}{number(math.abs(share) * 100)}% {stat.displayName}`)
		end
	end
	return table.concat(parts, ", ")
end

-- "10 (+50% Melee Damage)" or "10".
local function damageText(amount: number, scaling: { [string]: number }?): string
	local extra = EffectText.scaling(scaling)
	return if extra ~= "" then `{number(amount)} ({extra})` else number(amount)
end

-- "80 Shards", "different weapon", "1% Speed".
local function sourceText(source: string, per: number): string
	if source == "shards" then
		return plural(per, "Shard")
	elseif source == "distinctWeapons" then
		return if per == 1 then "different weapon" else `{number(per)} different weapons`
	elseif source == "enemies" then
		return if per == 1 then "living enemy" else `{number(per)} living enemies`
	end
	local tier = string.match(source, "^distinctItemsTier(%d)$")
	if tier then
		local info = Config.Items.tiers[tonumber(tier) :: number]
		local name = if info then info.name else `tier {tier}`
		return if per == 1 then `different {name} item` else `{number(per)} different {name} items`
	end
	local stat = Config.Stats.byId[source]
	if not stat then
		return source
	end
	return `{number(per)}{if stat.percent then "%" else ""} {stat.displayName}`
end

local function body(effect: Effects.Effect): string
	local action = effect.action
	local stats = EffectText.stats(effect.stats)
	if action == "Grow" then
		return stats
	elseif action == "WaveStats" then
		return `{stats} this wave{if effect.maxStacks then ` (max {effect.maxStacks}x)` else ""}`
	elseif action == "TimedStats" then
		return `{stats} for {number(effect.seconds or 0)}s`
	elseif action == "NextWaveStats" then
		return `{stats} during the next wave`
	elseif action == "Heal" then
		return `heal {number(effect.amount or 0)} HP`
	elseif action == "Shards" then
		return `+{plural(effect.amount or 0, "Shard")}`
	elseif action == "ShardShare" then
		return `+{number(effect.amount or 0)}% of your Shards{if effect.max then ` (max {effect.max})` else ""}`
	elseif action == "HpFraction" then
		return `HP set to {number((effect.amount or 0) * 100)}%`
	elseif action == "RandomStats" then
		return `{number(effect.amount or 0)} random stat points`
	elseif action == "Shields" then
		local amount = effect.amount or 0
		return if amount == 1
			then "the first hit taken deals no damage"
			else `the first {number(amount)} hits taken deal no damage`
	elseif action == "UpgradeWeapon" then
		return `a random weapon +1 tier{if stats ~= "" then ` (none: {stats})` else ""}`
	elseif action == "Burn" then
		return `burn {number(effect.ticks or 0)}x{damageText(effect.amount or 0, effect.scaling)}`
	elseif action == "Explode" then
		return `explode for {damageText(effect.amount or 0, effect.scaling)}`
	elseif action == "Strike" then
		local target = if effect.target == "random" then "a random enemy" else "the enemy"
		if effect.hpShare then
			local text = `{number(effect.hpShare * 100)}% of {target}'s current HP as damage`
			if effect.eliteHpShare then
				text ..= ` ({number(effect.eliteHpShare * 100)}% vs elites)`
			end
			return text
		end
		return `{damageText(effect.amount or 0, effect.scaling)} damage to {target}`
	elseif action == "Drain" then
		return `lose {number(effect.amount or 0)} HP`
	end
	return action
end

-- One line for an effect record, e.g. "Wave end: +3% Damage" or "+8 Armor while standing still".
function EffectText.line(effect: Effects.Effect): string
	if effect.trigger == "Always" then
		local stats = EffectText.stats(effect.stats)
		if effect.action == "PerX" then
			local text = `{stats} per {sourceText(effect.source or "", effect.per or 1)}`
			return if effect.max then `{text} (max {effect.max}x)` else text
		elseif effect.state == "Still" then
			return `{stats} while standing still`
		elseif effect.state == "Moving" then
			return `{stats} while moving`
		end
		return stats
	end
	local trigger = TRIGGER_TEXT[effect.trigger] or effect.trigger
	if effect.trigger == "Timer" then
		trigger = `Every {number(effect.interval or 0)}s`
	elseif effect.trigger == "Acquire" and effect.action == "NextWaveStats" then
		return `Next wave: {EffectText.stats(effect.stats)}`
	end
	if effect.fullHp then
		trigger ..= " at full HP"
	end
	if effect.crit and effect.elite then
		trigger ..= " (elite, crit)"
	elseif effect.crit then
		trigger ..= " (crit)"
	elseif effect.elite then
		trigger ..= " (elite)"
	end
	local text = `{trigger}: {body(effect)}`
	if effect.chance then
		text ..= ` ({number(math.round(effect.chance * 1000) / 10)}%)`
	end
	if effect.fromWave and effect.untilWave then
		text ..= ` (waves {effect.fromWave}-{effect.untilWave})`
	elseif effect.untilWave then
		text ..= ` (until wave {effect.untilWave})`
	elseif effect.fromWave then
		text ..= ` (from wave {effect.fromWave})`
	end
	if effect.maxPerWave then
		text ..= ` (max {effect.maxPerWave} per wave)`
	end
	return text
end

-- Every effect line of an item, joined by `separator` (default a new line); "" without effects.
function EffectText.lines(effects: { Effects.Effect }?, separator: string?): string
	local lines = {}
	for _, effect in effects or {} do
		table.insert(lines, EffectText.line(effect))
	end
	return table.concat(lines, separator or "\n")
end

-- The feedback text of an effect that paid out, and its kind for the color ("Heal", "Shards", "Stats", "Blocked",
-- "Weapon").
function EffectText.proc(proc: Types.EffectProc): string
	if proc.kind == "Heal" then
		return `+{number(proc.amount or 0)} HP`
	elseif proc.kind == "Shards" then
		return `+{plural(proc.amount or 0, "Shard")}`
	elseif proc.kind == "Blocked" then
		return "Blocked!"
	elseif proc.kind == "Weapon" then
		local weapon = proc.weaponId and Config.Weapons[proc.weaponId]
		local name = if weapon then weapon.displayName else proc.weaponId or "Weapon"
		return `{name} {Format.tier(proc.tier or 1)}!`
	end
	return EffectText.stats(proc.stats)
end

-- "Item name: text" for toasts; just the text without an item.
function EffectText.procWithItem(proc: Types.EffectProc): string
	local item = proc.itemId and Config.Items.byId[proc.itemId]
	local text = EffectText.proc(proc)
	return if item then `{item.displayName}: {text}` else text
end

-- One HUD line for an active bonus: "+8 Armor (standing still)".
function EffectText.bonus(bonus: Types.ActiveBonus): string
	return `{EffectText.stats(bonus.stats)} ({KIND_TEXT[bonus.kind] or bonus.kind})`
end

return EffectText
