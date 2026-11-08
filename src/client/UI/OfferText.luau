--!strict
-- Read-only weapon offer preview from config and the last server stat sheet. Called by ShopController.
-- This never grants or changes stats; parity with server WeaponStats is checked in UiShop.spec.luau.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local StatMath = require(Shared.Util.StatMath)
local CharacterRules = require(Shared.Util.CharacterRules)
local NativeTiming = require(Shared.Util.NativeWeaponTiming)
local NativeDamage = require(Shared.Util.NativeWeaponDamage)
local UpgradeText = require(Shared.Util.UpgradeText)
local WeaponClasses = require(Shared.Util.WeaponClasses)
local Theme = require(script.Parent.Theme)
local OfferText = {}

local function number(value: number): string
	return tostring(math.round(value * 10) / 10)
end

local function color(text: string, value: Color3): string
	return string.format(
		'<font color="#%02X%02X%02X">%s</font>',
		math.round(value.R * 255),
		math.round(value.G * 255),
		math.round(value.B * 255),
		text
	)
end

function OfferText.stats(id: string, tier: number, sheet: { [string]: number }): { [string]: number }
	local weapon = Config.Weapons[id]
	if not weapon then
		return {}
	end
	sheet = CharacterRules.weaponBonuses(weapon, sheet)
	local result = table.clone(weapon.base)
	local damageBonus = 0
	for n = 1, math.min(tier, #weapon.tiers) do
		for key, delta in weapon.tiers[n] do
			if key == "damage" then
				damageBonus += delta
			else
				result[key] = (result[key] or 0) + delta
			end
		end
	end
	local damage = (result.damage or 0) * (1 + damageBonus)
	damage = NativeDamage.base(damage, result, sheet)
	for stat, share in (if weapon.tierScaling then weapon.tierScaling[tier] else weapon.scaling) do
		damage += share * (sheet[stat] or 0)
	end
	damage += (result.levelScaling or 0) * (sheet.level or 0)
	damage += sheet.baseDamage or 0
	result.damage = NativeDamage.total(damage, math.max(0, 1 + (sheet.damage or 0) / 100), result)
	if result.cooldown then
		local minimum = math.max(
			if weapon.brotato then Config.Combat.originalWeapons.minCooldown else Config.Player.minWeaponCooldown,
			sheet.weaponCooldownMin or 0
		)
		local timing = if weapon.brotato
			then NativeTiming.factor(sheet.attackSpeed or 0)
			else StatMath.cooldownFactor(sheet.attackSpeed or 0)
		result.cooldown = math.max(minimum, result.cooldown * timing)
		NativeTiming.apply(result, sheet.attackSpeed or 0, minimum)
	end
	for _, key in weapon.rangeKeys do
		if result[key] then
			result[key] = math.max(
				Config.Stats.range.minStuds,
				result[key]
					+ (sheet.range or 0) * Config.Stats.range.studsPerPoint * (if weapon.kind == "Melee"
						then Config.Stats.range.meleeFactor
						else 1)
					+ (sheet.weaponRange or 0) * Config.Stats.range.studsPerPoint
			)
		end
	end
	if result.minimumRange then
		result.range = math.max(result.minimumRange + Config.Stats.range.minStuds, result.range)
	end
	result.critChance = StatMath.critChance(result.critChance or Config.Player.critChance, sheet.critChance or 0)
	result.critDamage = (result.critDamage or Config.Player.critMultiplier) + (sheet.critDamage or 0) / 100
	result.lifeSteal = math.clamp((result.lifeSteal or 0) + (sheet.lifeSteal or 0) / 100, 0, 1)
	local knockback = (result.knockback or 0) + (sheet.knockback or 0)
	result.knockback = (if result.negativeKnockbackOnly then math.min(0, knockback) else math.max(0, knockback))
		* Config.Combat.knockback.studsPerPoint
	if result.pierce and result.pierce >= 0 then
		result.pierce = math.max(0, math.floor(result.pierce + (sheet.piercing or 0)))
	end
	if result.bounce then
		result.bounce = math.max(0, math.floor(result.bounce + (sheet.bounce or 0)))
	end
	if weapon.brotato and result.noBounce then
		result.bounce = 0
	end
	return result
end

function OfferText.weapon(id: string, tier: number, sheet: { [string]: number }): (string, string)
	local weapon = Config.Weapons[id]
	if not weapon then
		return "Weapon", ""
	end
	local stats = OfferText.stats(id, tier, sheet)
	local lines = {}
	local function line(label: string, value: string)
		table.insert(lines, color(label .. ": ", Theme.statLabel) .. value)
	end
	local scaling = UpgradeText.weaponBase(weapon, tier):match("%(.+%)")
	line("Damage", number(stats.damage) .. (if scaling then " " .. scaling else ""))
	line("Critical", `x{number(stats.critDamage)} ({number(stats.critChance * 100)}% chance)`)
	if stats.cooldown then
		line("Cooldown", color(string.format("%.2fs", stats.cooldown), Theme.success))
	end
	line("Knockback", number(stats.knockback / Config.Combat.knockback.studsPerPoint))
	local rangeKey = weapon.rangeKeys[1]
	if rangeKey and stats[rangeKey] then
		local rangeText = number(stats[rangeKey] / Config.Stats.range.studsPerPoint)
		if stats.minimumRange then
			rangeText = number(stats.minimumRange / Config.Stats.range.studsPerPoint) .. " - " .. rangeText
		end
		line("Range", rangeText .. ` ({weapon.kind})`)
	end
	if stats.pierce and stats.pierce ~= 0 then
		line("Pierces", if stats.pierce < 0 then "All enemies" else number(stats.pierce))
	end
	if stats.bounce and stats.bounce > 0 then
		line("Bounces", number(stats.bounce))
	end
	if stats.lifeSteal > 0 then
		line("Life Steal", color(number(stats.lifeSteal * 100) .. "%", Theme.success))
	end
	local description = if weapon.tierDescriptions then weapon.tierDescriptions[tier] else weapon.description
	if description and description ~= "" then
		table.insert(lines, "\n" .. description)
	end
	return WeaponClasses.names(id), table.concat(lines, "\n")
end

return OfferText
