--!strict
-- Texts of level-up cards, shop offers and chest rewards (DESIGN.md section 13), built from Config.Stats,
-- Config.Items, Config.Weapons and Config.Evolutions so the server only sends ids: names, effect lines ("+5% Damage",
-- "-1 Armor", optionally colored as rich text), weapon names with tiers ("Spark Bolt II") and badges (rarity names,
-- "NEW"). Used by LevelUpController,
-- ShopController, ChestController and StatsController; tested in tests/UpgradePool.spec.luau.

local Config = require(script.Parent.Parent.Config)
local Weapons = require(script.Parent.Parent.Config.Weapons)
local Types = require(script.Parent.Parent.Net.Types)
local Format = require(script.Parent.Format)
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

-- What a weapon's tier adds over tier I, e.g. "+30% damage, +1 blade" (tiers II-IV since B3); "" for tier I.
function UpgradeText.weaponTier(weapon: Weapons.Weapon, tier: number): string
	local total: { [string]: number } = {}
	for n = 2, math.min(tier, #weapon.tiers) do
		for key, value in weapon.tiers[n] :: { [string]: number } do
			total[key] = (total[key] or 0) + value
		end
	end
	local parts = {}
	if total.count then
		local noun = weapon.countName or "projectile"
		table.insert(parts, `{signed(total.count)} {plural(total.count, noun)}`)
	end
	if total.jumps then
		table.insert(parts, `{signed(total.jumps)} {plural(total.jumps, "jump")}`)
	end
	if total.damage then
		table.insert(parts, `{signed(math.round(total.damage * 100))}% damage`)
	end
	if total.radius then
		table.insert(parts, `{signed(total.radius)} radius`)
	end
	if total.cooldown then
		table.insert(parts, `{signed(total.cooldown)}s cooldown`)
	end
	if total.duration then
		table.insert(parts, `{signed(total.duration)}s duration`)
	end
	return table.concat(parts, ", ")
end

-- Weapon name with its tier, e.g. "Spark Bolt II"; an evolved weapon shows its evolution's name.
function UpgradeText.weaponName(weaponId: string, tier: number, evolutionId: string?): string
	local evolution = evolutionId and Config.Evolutions[evolutionId]
	if evolution then
		return evolution.displayName
	end
	local weapon = Config.Weapons[weaponId]
	return `{if weapon then weapon.displayName else weaponId} {Format.tier(tier)}`
end

-- Title, effect line and badge of a level-up card ("Damage", "+8% Damage", "Uncommon").
function UpgradeText.card(card: Types.UpgradeCard): (string, string, string)
	local stat = Config.Stats.byId[card.stat]
	local title = if stat then stat.displayName else card.stat
	return title, StatMath.format(card.stat, card.amount), UpgradeText.tierName(card.tier)
end

-- Title, effect text and badge of a shop offer. Weapons: name with tier ("Spark Bolt II"), description, what the tier
-- adds and whether buying merges it; badge "Uncommon · NEW" or "Uncommon · own 2". Items: their stat lines (rich text
-- with `colors`), the rarity and how many the player owns ("Rare · x2").
function UpgradeText.offer(offer: Types.ShopOffer, colors: Colors?): (string, string, string)
	if offer.kind == "Weapon" then
		local weapon = Config.Weapons[offer.itemId]
		local badge = UpgradeText.tierName(offer.tier) .. (if offer.isNew then " · NEW" else ` · own {offer.count}`)
		if not weapon then
			return offer.itemId, "", badge
		end
		local lines = { weapon.description }
		local bonus = UpgradeText.weaponTier(weapon, offer.tier)
		if bonus ~= "" then
			table.insert(lines, bonus)
		end
		if offer.merges then
			table.insert(lines, `Merges into {Format.tier(offer.tier + 1)}`)
		elseif offer.blocked then
			table.insert(lines, "Weapon slots full")
		end
		return UpgradeText.weaponName(offer.itemId, offer.tier, nil), table.concat(lines, "\n"), badge
	end
	local item = Config.Items.byId[offer.itemId]
	local owned = offer.count - 1
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
