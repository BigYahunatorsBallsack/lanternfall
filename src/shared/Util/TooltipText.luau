--!strict
-- Tooltip texts (Paket 14, DESIGN.md section 13) built from the config: a weapon with its real damage next to
-- Brotato's base notation ("Damage 32 | 18 (+100% Melee Damage)"), an item with its count and limit, what a stat
-- does with its current value, a weapon class with the bonus of every count (the active one bold) and the planned
-- elite and horde waves. Returns a title and rich-text lines. Used by the HUD, the stat panel and the shop (UI/Tooltip).

local Config = require(script.Parent.Parent.Config)
local StatMath = require(script.Parent.StatMath)
local Types = require(script.Parent.Parent.Net.Types)
local UpgradeText = require(script.Parent.UpgradeText)
local WeaponClasses = require(script.Parent.WeaponClasses)

local DIM = "#9A93A8"

local TooltipText = {}

local function number(value: number): string
	local rounded = math.round(value * 10) / 10
	return if rounded == math.floor(rounded) then tostring(rounded) else string.format("%.1f", rounded)
end

local function dim(text: string): string
	return `<font color="{DIM}">{text}</font>`
end

-- What each stat does (game text); a function gets the stat's current value.
local STAT_HINTS: { [string]: string | (value: number) -> string } = {
	maxHp = "Your health.",
	hpRegen = function(value)
		return `Heals {number(StatMath.regenPerSecond(value))} HP per second.`
	end,
	lifeSteal = function(value)
		return `{number(math.clamp(value, 0, 100))}% chance per weapon hit to heal {Config.Stats.hpScale} HP.`
	end,
	damage = "Raises the damage of every weapon, burn and explosion by this share.",
	meleeDamage = "Added to weapons that scale with Melee Damage.",
	rangedDamage = "Added to weapons that scale with Ranged Damage.",
	elementalDamage = "Added to burns and weapons that scale with Elemental Damage.",
	attackSpeed = function(value)
		return `Weapon cooldowns x{string.format("%.2f", StatMath.cooldownFactor(value))}.`
	end,
	critChance = "Added to every weapon's own crit chance.",
	range = "Reach of your weapons; melee weapons get part of it.",
	armor = function(value)
		local taken = StatMath.armorFactor(value)
		if taken <= 1 then
			return `You take {number((1 - taken) * 100)}% less damage from hits.`
		end
		return `You take {number((taken - 1) * 100)}% more damage from hits.`
	end,
	dodge = function(value)
		return `{number(StatMath.dodgeChance(value) * 100)}% chance to dodge a hit (at most {Config.Stats.dodge.max}%).`
	end,
	speed = function(value)
		return `Move speed x{string.format("%.2f", StatMath.speedFactor(value))}.`
	end,
	luck = "Rarer cards, items and crates, and more drops.",
	harvesting = "Shards and XP at the end of every wave.",
	xpGain = "More XP from every orb.",
	pickupRange = "Orbs fly to you from further away.",
	itemPrice = "Changes every shop price.",
	freeRerolls = "Free rerolls in every shop.",
	sellValue = "More Shards back when you sell a weapon.",
	doubleShards = "Chance that an orb gives double Shards and XP.",
	shardHealing = "Chance that an orb heals you.",
	eliteDamage = "Weapon damage against elites, champions and bosses.",
	enemyCount = "More enemies spawn. The whole team's values add up.",
	enemyHp = "Enemies spawn with more HP. The whole team's values add up.",
	enemyDamage = "Enemies hit harder. The whole team's values add up.",
	knockback = "Pushes enemies further back with every weapon hit.",
	explosionDamage = "Damage of every explosion.",
	explosionSize = "Size of every explosion.",
	piercing = "Projectiles fly through this many more enemies.",
	piercingDamage = "Projectiles lose less damage per enemy they pierce.",
	bounce = "Projectiles bounce to this many more enemies.",
	burnSpeed = "Burns tick faster.",
	burnSpread = "Burns pass on to this many more enemies.",
	fruitHeal = "Extra HP from every fruit and crate.",
	trees = "More trees every wave. The whole team's values add up.",
	engineering = "Makes structures and some weapons stronger.",
	enemySpeed = "Enemies move faster. The whole team's values add up.",
}

-- A carried weapon (Net/Types.WeaponInfo with its effective stats).
function TooltipText.weapon(info: Types.WeaponInfo): (string, string)
	local title = UpgradeText.weaponName(info.id, info.tier, info.evolution)
	local weapon = Config.Weapons[info.id]
	if not weapon then
		return title, ""
	end
	local stats = info.stats
	local lines = {}
	local head = { UpgradeText.tierName(info.tier) }
	local classes = WeaponClasses.names(info.id)
	if classes ~= "" then
		table.insert(head, classes)
	end
	table.insert(head, weapon.kind)
	table.insert(lines, dim(table.concat(head, " · ")))
	table.insert(
		lines,
		`Damage <b>{number(stats.damage or 0)}</b> {dim("| " .. UpgradeText.weaponBase(weapon, info.tier))}`
	)
	local crit = stats.critChance or 0
	table.insert(lines, `Crit x{number(stats.critDamage or Config.Player.critMultiplier)} ({number(crit * 100)}%)`)
	local timing = {}
	if stats.cooldown then
		table.insert(timing, `Cooldown {string.format("%.2f", stats.cooldown)}s`)
	end
	local rangeKey = weapon.rangeKeys[1]
	if rangeKey and stats[rangeKey] then
		table.insert(timing, `Range {number(stats[rangeKey])}`)
	end
	if #timing > 0 then
		table.insert(lines, table.concat(timing, " · "))
	end
	local extras = {}
	if (stats.lifeSteal or 0) > 0 then
		table.insert(extras, `Life steal {number(stats.lifeSteal * 100)}%`)
	end
	if (stats.pierce or 0) > 0 then
		table.insert(extras, `Pierces {stats.pierce}`)
	end
	if (stats.bounce or 0) > 0 then
		table.insert(extras, `Bounces {stats.bounce}`)
	end
	if stats.burnDamage then
		table.insert(extras, `Burns {number(stats.burnDamage)}`)
	end
	if #extras > 0 then
		table.insert(lines, table.concat(extras, " · "))
	end
	if weapon.description and weapon.description ~= "" then
		table.insert(lines, dim(weapon.description))
	end
	return title, table.concat(lines, "\n")
end

-- An item the player owns `count` of.
function TooltipText.item(itemId: string, count: number): (string, string)
	local item = Config.Items.byId[itemId]
	if not item then
		return itemId, ""
	end
	local head = `{UpgradeText.tierName(item.tier)} · owned {count}`
	if item.limit then
		head ..= ` / max {item.limit}`
	end
	local colors = { plus = Color3.fromRGB(126, 214, 136), minus = Color3.fromRGB(236, 96, 96) } -- Theme success/danger
	local body = UpgradeText.itemLines(itemId, colors)
	return item.displayName, dim(head) .. (if body ~= "" then "\n" .. body else "")
end

-- What a stat does, with its current value.
function TooltipText.stat(statId: string, value: number): (string, string)
	local stat = Config.Stats.byId[statId]
	local title = if stat then stat.displayName else statId
	local hint = STAT_HINTS[statId]
	local text = if type(hint) == "function" then hint(value) elseif type(hint) == "string" then hint else ""
	if stat and not stat.primary then
		text ..= "\n" .. dim("Secondary stat: only from items.")
	end
	return title, text
end

-- A weapon class: the bonus for every count, the one for `count` bold, and how many more give the next one.
function TooltipText.weaponClass(classId: string, count: number): (string, string)
	local class = Config.WeaponClasses.byId[classId]
	local title = `{if class then class.displayName else classId} {count}/{Config.WeaponClasses.maxCount}`
	if not class then
		return title, ""
	end
	local lines = {}
	for n = Config.WeaponClasses.minCount, Config.WeaponClasses.maxCount do
		local bonus = class.bonuses[n]
		if bonus then
			local text = `{n}: {(string.gsub(UpgradeText.statLines(bonus), "\n", ", "))}`
			table.insert(lines, if n == count then `<b>{text}</b>` else dim(text))
		end
	end
	if count < Config.WeaponClasses.maxCount then
		local next = math.max(count + 1, Config.WeaponClasses.minCount)
		table.insert(lines, `{next - count} more for the next bonus. Copies count.`)
	end
	return title, table.concat(lines, "\n")
end

-- The run's planned elite and horde waves (WavePlan) from `fromWave` on; nil title if none are left.
function TooltipText.wavePlan(plan: { Types.WaveChallenge }, fromWave: number): (string?, string?)
	local lines = {}
	for _, challenge in plan do
		if challenge.wave >= fromWave then
			local text = if challenge.kind == "Horde" then "Horde: twice the enemies" else "Elite wave: champions join"
			table.insert(lines, `Wave {challenge.wave} · {text}`)
		end
	end
	if #lines == 0 then
		return nil, nil
	end
	return "COMING UP", table.concat(lines, "\n")
end

-- "Elite wave in 3" / "Horde wave next" for the first planned challenge after `wave`, or nil.
function TooltipText.nextChallenge(plan: { Types.WaveChallenge }, wave: number): (string?, string?)
	for _, challenge in plan do
		if challenge.wave > wave then
			local name = if challenge.kind == "Horde" then "Horde wave" else "Elite wave"
			local left = challenge.wave - wave
			return if left == 1 then `{name} next` else `{name} in {left}`, challenge.kind
		end
	end
	return nil, nil
end

return TooltipText
