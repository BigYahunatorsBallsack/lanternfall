--!strict
-- Weapon class bonuses (DESIGN.md section 6, Brotato's set bonuses since B5) as pure functions over Config.Weapons
-- and Config.WeaponClasses: how many weapons of each class a player carries (copies count), the bonus of each class
-- for its count, the sum of all of them and short texts. Used by StatService (adds the sum to the permanent stats),
-- the stat panel and the shop cards on the client; tested in tests/WeaponClasses.spec.luau.

local Config = require(script.Parent.Parent.Config)

local Classes = Config.WeaponClasses

local WeaponClasses = {}

-- Weapons per class id for a list of weapon ids (copies count, unknown ids do not).
function WeaponClasses.counts(weaponIds: { string }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, weaponId in weaponIds do
		local weapon = Config.Weapons[weaponId]
		if weapon then
			for _, classId in weapon.classes do
				counts[classId] = (counts[classId] or 0) + 1
			end
		end
	end
	return counts
end

-- The bonus stats of a class for `count` weapons (at most Config.WeaponClasses.maxCount), nil below minCount.
function WeaponClasses.bonus(classId: string, count: number): { [string]: number }?
	local class = Classes.byId[classId]
	if not class or count < Classes.minCount then
		return nil
	end
	return class.bonuses[math.min(count, Classes.maxCount)]
end

-- Every class bonus for these weapons added up (stat id -> value); empty without any.
function WeaponClasses.bonuses(weaponIds: { string }): { [string]: number }
	local sheet: { [string]: number } = {}
	for classId, count in WeaponClasses.counts(weaponIds) do
		local stats = WeaponClasses.bonus(classId, count)
		if stats then
			for statId, value in stats do
				sheet[statId] = (sheet[statId] or 0) + value
			end
		end
	end
	return sheet
end

-- The classes of a weapon by name, e.g. "Edge · Primal"; "" for unknown weapons.
function WeaponClasses.names(weaponId: string): string
	local weapon = Config.Weapons[weaponId]
	if not weapon then
		return ""
	end
	local names = {}
	for _, classId in weapon.classes do
		local class = Classes.byId[classId]
		table.insert(names, if class then class.displayName else classId)
	end
	return table.concat(names, " · ")
end

-- The classes a player has at least one weapon of, in the order of Config.WeaponClasses, with their counts.
function WeaponClasses.carried(weaponIds: { string }): { { id: string, count: number } }
	local counts = WeaponClasses.counts(weaponIds)
	local list = {}
	for _, class in Classes.order do
		local count = counts[class.id]
		if count then
			table.insert(list, { id = class.id, count = count })
		end
	end
	return list
end

return WeaponClasses
