--!strict
-- Texts of a level-up card (DESIGN.md section 13): name, one line of effect and the badge ("NEW", "LV 3"), built from
-- Config.Weapons and Config.Passives so the server only sends ids, and the texts of a chest reward. Used by
-- LevelUpController and ChestController; tested in tests/UpgradePool.spec.luau.

local Config = require(script.Parent.Parent.Config)
local Weapons = require(script.Parent.Parent.Config.Weapons)
local Types = require(script.Parent.Parent.Net.Types)

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

-- Title, effect line and badge of a card.
function UpgradeText.describe(card: Types.UpgradeCard): (string, string, string)
	local badge = if card.isNew then "NEW" else `LV {card.level}`
	if card.kind == "Weapon" then
		local weapon = Config.Weapons[card.itemId]
		if not weapon then
			return card.itemId, "", badge
		end
		local detail = if card.isNew then weapon.description else UpgradeText.weaponLevel(weapon, card.level)
		return weapon.displayName, detail, badge
	elseif card.kind == "Passive" then
		local passive = Config.Passives[card.itemId]
		if not passive then
			return card.itemId, "", badge
		end
		return passive.displayName, passive.description, badge
	end
	local rewards = Config.Run.levelUp.maxedOutRewards
	if card.itemId == "Heal" then
		return "Heal", `Heal {math.round(rewards.healFraction * 100)}% of your HP`, ""
	elseif card.itemId == "Embers" then
		return "Embers", `+{rewards.embers} Embers`, ""
	end
	return card.itemId, "", ""
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
	end
	local title, detail, badge = UpgradeText.describe({
		id = `{reward.kind}:{reward.itemId}`,
		kind = reward.kind :: any,
		itemId = reward.itemId,
		level = reward.level,
		isNew = false,
	})
	return if badge ~= "" then `{title} {badge}` else title, detail
end

return UpgradeText
