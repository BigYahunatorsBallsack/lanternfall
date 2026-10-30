--!strict
-- Pure B10 character rules; called by weapon/stat/shop services and tests.
local Config = require(script.Parent.Parent.Config)
local StatMath = require(script.Parent.StatMath)
local CharacterRules = {}

function CharacterRules.maxWeapons(classId: string?): number
	local class = classId and Config.Classes[classId]
	return if class then class.maxWeapons or Config.Player.maxWeapons else Config.Player.maxWeapons
end

function CharacterRules.weaponAllowed(classId: string?, weaponId: string): boolean
	local weapon = Config.Weapons[weaponId]
	local class = classId and Config.Classes[classId]
	return weapon ~= nil and (not class or not class.weaponKind or weapon.kind == class.weaponKind)
end

function CharacterRules.hasSlot(classId: string?, weaponId: string, weapons: { { id: string } }): boolean
	if not CharacterRules.weaponAllowed(classId, weaponId) or #weapons >= CharacterRules.maxWeapons(classId) then
		return false
	end
	local class = classId and Config.Classes[classId]
	local kind = Config.Weapons[weaponId].kind
	local limit = class and class.kindLimits and class.kindLimits[kind]
	if limit then
		local count = 0
		for _, owned in weapons do
			if Config.Weapons[owned.id].kind == kind then
				count += 1
			end
		end
		return count < limit
	end
	return true
end

-- Conversions read the unconverted sheet simultaneously, never their own outputs.
function CharacterRules.bonuses(
	classId: string?,
	sheet: StatMath.Sheet,
	weapons: { { id: string } },
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
		if not unique[weapon.id] then
			unique[weapon.id] = true
			distinct += 1
		end
	end
	StatMath.add(gains, class.perDistinctWeapon or {}, distinct)
	for _, conversion in class.conversions or {} do
		local source = if conversion.permanentOnly then permanent or sheet else sheet
		local value = math.floor((source[conversion.source] or 0) / conversion.per) * conversion.amount
		gains[conversion.target] = (gains[conversion.target] or 0) + value
	end
	return gains
end

return CharacterRules
