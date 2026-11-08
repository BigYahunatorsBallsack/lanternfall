--!strict
-- Pure B10 character rules; called by weapon/stat/shop services and tests.
local Config = require(script.Parent.Parent.Config)
local StatMath = require(script.Parent.StatMath)
local CharacterRules = {}

function CharacterRules.maxWeapons(classId: string?, grantedSlots: number?): number
	local class = classId and Config.Classes[classId]
	if class and class.baseWeaponSlots then
		local slots = class.baseWeaponSlots + math.max(0, math.floor(grantedSlots or 0))
		return math.min(slots, class.maxWeaponSlots or math.huge)
	end
	return if class then class.maxWeapons or Config.Player.maxWeapons else Config.Player.maxWeapons
end

function CharacterRules.weaponAllowed(classId: string?, weaponId: string, tier: number?): boolean
	local weapon = Config.Weapons[weaponId]
	local class = classId and Config.Classes[classId]
	if not weapon or weapon.available == false or (class and class.maxWeapons == 0) then
		return false
	end
	if class and class.weaponKind and weapon.kind ~= class.weaponKind then
		return false
	end
	if tier then
		local minimum = math.max(weapon.minTier or 1, if class then class.minWeaponTier or 1 else 1)
		local maximum =
			math.min(Config.Player.maxWeaponTier, if class then class.maxWeaponTier or math.huge else math.huge)
		return tier == math.floor(tier) and tier >= minimum and tier <= maximum
	end
	return true
end

function CharacterRules.hasSlot(
	classId: string?,
	weaponId: string,
	weapons: { { id: string, tier: number? } },
	grantedSlots: number?,
	tier: number?
): boolean
	if
		not CharacterRules.weaponAllowed(classId, weaponId, tier)
		or #weapons >= CharacterRules.maxWeapons(classId, grantedSlots)
	then
		return false
	end
	local class = classId and Config.Classes[classId]
	local kind = Config.Weapons[weaponId].kind
	local limit = class and class.kindLimits and class.kindLimits[kind]
	local count = 0
	for _, owned in weapons do
		if class and class.noDuplicateWeapons and owned.id == weaponId then
			return false
		end
		local config = Config.Weapons[owned.id]
		if limit and config and config.kind == kind then
			count += 1
		end
	end
	return not limit or count < limit
end

-- Conversions read the unconverted sheet simultaneously, never their own outputs.
function CharacterRules.bonuses(
	classId: string?,
	sheet: StatMath.Sheet,
	weapons: { { id: string, tier: number? } },
	permanent: StatMath.Sheet?
): StatMath.Sheet
	local class = classId and Config.Classes[classId]
	local gains = {}
	if not class then
		return gains
	end
	StatMath.add(gains, class.perWeapon or {}, #weapons)
	local unique = {}
	local distinct = 0
	for _, weapon in weapons do
		local tierStats = class.perTierWeapon and class.perTierWeapon[weapon.tier or 1]
		if tierStats then
			StatMath.add(gains, tierStats)
		end
		if not unique[weapon.id] then
			unique[weapon.id] = true
			distinct += 1
		end
	end
	StatMath.add(gains, class.perDistinctWeapon or {}, distinct)
	for _, conversion in class.conversions or {} do
		local source = if conversion.permanentOnly then permanent or sheet else sheet
		local value = math.modf(conversion.amount * (source[conversion.source] or 0) / conversion.per)
		gains[conversion.target] = (gains[conversion.target] or 0) + value
	end
	return StatMath.addGains({}, gains, class.gainMultipliers)
end

-- Weapon-specific character bonuses travel separately from the owner's ordinary stat sheet.
function CharacterRules.weaponSheet(classId: string?, sheet: StatMath.Sheet): StatMath.Sheet
	local result = table.clone(sheet)
	result.nativeBurningTargetBonus =
		CharacterRules.nativeAmount(classId, "bonus_non_elemental_damage_against_burning_targets")
	local class = classId and Config.Classes[classId]
	if class then
		for weaponClass, stats in class.weaponClassStats or {} do
			for statId, amount in stats do
				result[`class.{weaponClass}.{statId}`] = amount
			end
		end
		for kind, stats in class.weaponKindStats or {} do
			for statId, amount in stats do
				result[`kind.{kind}.{statId}`] = amount
			end
		end
	end
	return result
end

-- Character class/kind modifiers are weapon-local; they never enter the owner's shared item/structure sheet.
local LOCAL_STATS = {
	"damage",
	"meleeDamage",
	"rangedDamage",
	"elementalDamage",
	"engineering",
	"attackSpeed",
	"range",
	"lifeSteal",
	"critChance",
	"critDamage",
	"baseDamage",
	"weaponRange",
	"knockback",
	"explosionDamage",
	"explosionSize",
	"piercing",
	"piercingDamage",
	"bounce",
	"burnSpeed",
	"burnSpread",
}

function CharacterRules.weaponBonuses(
	weapon: { kind: string, classes: { string } },
	bonuses: StatMath.Sheet
): StatMath.Sheet
	local result = table.clone(bonuses)
	for _, statId in LOCAL_STATS do
		local amount = bonuses[`kind.{weapon.kind}.{statId}`] or 0
		for _, classId in weapon.classes do
			amount += bonuses[`class.{classId}.{statId}`] or 0
		end
		if amount ~= 0 then
			result[statId] = (result[statId] or 0) + amount
		end
	end
	return result
end

-- Direct additive native policies; custom triggers and replacement effects are handled by their owning systems.
function CharacterRules.nativeAmount(classId: string?, key: string): number
	local class = classId and Config.Classes[classId]
	local native = class and class.native
	local result = 0
	if native then
		for _, effect in native.sourceEffects do
			if effect.sourceKey == key and effect.customKey == "" and effect.storageMethod == 0 then
				result += effect.amount
			end
		end
	end
	return result
end

return CharacterRules
