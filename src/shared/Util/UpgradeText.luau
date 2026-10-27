--!strict
-- Texts of level-up cards, shop offers and chest rewards (DESIGN.md section 13), built from Config.Stats,
-- Config.Items, Config.Weapons and Config.Evolutions so the server only sends ids: names, effect lines ("+5% Damage",
-- "-1 Armor", optionally colored as rich text) and badges ("NEW", "LV 3", rarity names). Used by LevelUpController,
-- ShopController, ChestController and StatsController; tested in tests/UpgradePool.spec.luau.

local Config = require(script.Parent.Parent.Config)
local Weapons = require(script.Parent.Parent.Config.Weapons)
local Types = require(script.Parent.Parent.Net.Types)
local StatMath = require(script.Parent.StatMath)

export type Colors = { plus: Color3, minus: Color3 }

local UpgradeText = {}

-- 0.3 -> "0.3", 2 -> "2"
local function number(value: number): string
	if value == math.floor(value) then
		return tostring(value)
	end
	return string.format("%.1f", value)
end

local function signed(value: number): string
	return if value >= 0 then `+{number(value)}` else `-{number(-value)}`
end

local function plural(count: number, noun: string): string
	return if math.abs(count) == 1 then noun else `{noun}s`
end

local function hex(color: Color3): string
	local function channel(value: number): number
		return math.clamp(math.round(value * 255), 0, 255)
	end
	return string.format("#%02X%02X%02X", channel(color.R), channel(color.G), channel(color.B))
end

-- "Common", "Uncommon", "Rare" or "Legendary".
function UpgradeText.tierName(tier: number): string
	local rule = Config.Items.tiers[tier]
	return if rule then rule.name else `Tier {tier}`
end

-- One line per stat in the order of the stat panel, e.g. "+5% Damage\n-1 Armor". With `colors` the lines are rich
-- text, plus green and minus red.
function UpgradeText.statLines(stats: { [string]: number }, colors: Colors?): string
	local lines = {}
	for _, stat in Config.Stats.order do
		local value = stats[stat.id]
		if value and value ~= 0 then
			local text = StatMath.format(stat.id, value)
			if colors then
				text = `<font color="{hex(if value > 0 then colors.plus else colors.minus)}">{text}</font>`
			end
			table.insert(lines, text)
		end
	end
	return table.concat(lines, "\n")
end

-- One line for what a weapon level adds, e.g. "+1 blade" or "+2 radius, -0.3s cooldown".
function UpgradeText.weaponLevel(weapon: Weapons.Weapon, level: number): string
	local delta = weapon.levels[level]
	if not delta then
		return weapon.description
	end
	local parts = {}
	if delta.count then
		local noun = weapon.countName or "projectile"
		table.insert(parts, `{signed(delta.count)} {plural(delta.count, noun)}`)
	end
	if delta.jumps then
		table.insert(parts, `{signed(delta.jumps)} {plural(delta.jumps, "jump")}`)
	end
	if delta.damage then
		table.insert(parts, `{signed(math.round(delta.damage * 100))}% damage`)
	end
	if delta.radius then
		table.insert(parts, `{signed(delta.radius)} radius`)
	end
	if delta.cooldown then
		table.insert(parts, `{signed(delta.cooldown)}s cooldown`)
	end
	if delta.duration then
		table.insert(parts, `{signed(delta.duration)}s duration`)
	end
	return if #parts > 0 then table.concat(parts, ", ") else weapon.description
end

-- Title, effect line and badge of a level-up card ("Damage", "+8% Damage", "Uncommon").
function UpgradeText.card(card: Types.UpgradeCard): (string, string, string)
	local stat = Config.Stats.byId[card.stat]
	local title = if stat then stat.displayName else card.stat
	return title, StatMath.format(card.stat, card.amount), UpgradeText.tierName(card.tier)
end

-- Title, effect text and badge of a shop offer. Weapons: their description or what the next level adds, "NEW" or
-- "LV 3". Items: their stat lines (rich text with `colors`), the rarity and how many the player owns ("Rare · x2").
function UpgradeText.offer(offer: Types.ShopOffer, colors: Colors?): (string, string, string)
	if offer.kind == "Weapon" then
		local weapon = Config.Weapons[offer.itemId]
		local badge = if offer.isNew then "NEW" else `LV {offer.level}`
		if not weapon then
			return offer.itemId, "", badge
		end
		return weapon.displayName,
			if offer.isNew then weapon.description else UpgradeText.weaponLevel(weapon, offer.level),
			badge
	end
	local item = Config.Items.byId[offer.itemId]
	local owned = offer.level - 1
	local badge = UpgradeText.tierName(offer.tier) .. (if owned > 0 then ` · x{owned}` else "")
	if not item then
		return offer.itemId, "", badge
	end
	return item.displayName, UpgradeText.statLines(item.stats, colors), badge
end

-- Title and effect line of an elite chest reward (Net/Types.ChestReward).
function UpgradeText.chestReward(reward: Types.ChestReward): (string, string)
	if reward.kind == "Evolution" then
		local evolution = Config.Evolutions[reward.itemId]
		if not evolution then
			return reward.itemId, "Evolution"
		end
		local weapon = Config.Weapons[evolution.weapon]
		return evolution.displayName, `{if weapon then weapon.displayName else evolution.weapon} evolved!`
	elseif reward.kind == "Item" then
		local item = Config.Items.byId[reward.itemId]
		if not item then
			return reward.itemId, ""
		end
		local title = if reward.level > 1 then `{item.displayName} x{reward.level}` else item.displayName
		return title, (string.gsub(UpgradeText.statLines(item.stats), "\n", ", "))
	end
	if reward.itemId == "Heal" then
		return "Heal", "Full HP"
	end
	return reward.itemId, ""
end

return UpgradeText
