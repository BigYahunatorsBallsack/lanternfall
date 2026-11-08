--!strict
-- Pure character equipment and weapon-local stat contracts; called by the standalone Luau test runner.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Util.CharacterRules)

-- Config's outer catalog is frozen; restore only the nested fixture fields, including after a failed assertion.
local function withClass(fields, check)
	local class = Config.Classes.ManyHands
	local before = {}
	for key, value in fields do
		before[key] = class[key]
		class[key] = value
	end
	local ok, message = pcall(check)
	for key in fields do
		class[key] = before[key]
	end
	assert(ok, message)
end

describe("Character weapon capacity", function()
	it("retains ordinary limits and rejects equipment for a weaponless character", function()
		expect(Rules.maxWeapons(nil)).toBe(Config.Player.maxWeapons)
		expect(Rules.maxWeapons("Unknown")).toBe(Config.Player.maxWeapons)
		withClass({ maxWeapons = 0 }, function()
			expect(Rules.maxWeapons("ManyHands")).toBe(0)
			expect(Rules.weaponAllowed("ManyHands", "RitualDirk")).toBe(false)
			expect(Rules.hasSlot("ManyHands", "RitualDirk", {})).toBe(false)
		end)
	end)

	it("adds only granted slots and caps Baby at twenty-four", function()
		withClass({ baseWeaponSlots = 1, slotUpgradeAmount = 1, maxWeaponSlots = 24 }, function()
			expect(Rules.maxWeapons("ManyHands")).toBe(1)
			expect(Rules.maxWeapons("ManyHands", 0)).toBe(1)
			expect(Rules.maxWeapons("ManyHands", 3)).toBe(4)
			expect(Rules.maxWeapons("ManyHands", 24)).toBe(24)
			expect(Rules.maxWeapons("ManyHands", 100)).toBe(24)
			expect(Rules.hasSlot("ManyHands", "RitualDirk", { { id = "RattleRepeater" } }, 0)).toBe(false)
			expect(Rules.hasSlot("ManyHands", "RitualDirk", { { id = "RattleRepeater" } }, 1)).toBe(true)
		end)
	end)

	it("rejects duplicate weapon ids independently of their tier", function()
		withClass({ noDuplicateWeapons = true }, function()
			expect(Rules.hasSlot("ManyHands", "RitualDirk", { { id = "RitualDirk", tier = 1 } }, nil, 2)).toBe(false)
			expect(Rules.hasSlot("ManyHands", "RitualDirk", { { id = "RattleRepeater" } })).toBe(true)
		end)
	end)

	it("keeps separate melee and ranged limits", function()
		local weapons = { { id = "RitualDirk" }, { id = "BrassKnuckles" }, { id = "LamplighterPike" } }
		expect(Rules.hasSlot("TwinLedger", "SpiritFlint", weapons)).toBe(false)
		expect(Rules.hasSlot("TwinLedger", "RattleRepeater", weapons)).toBe(true)
	end)
end)

describe("Character weapon eligibility", function()
	it("rejects unknown weapons and retains kind restrictions", function()
		expect(Rules.weaponAllowed("ManyHands", "Unknown")).toBe(false)
		expect(Rules.weaponAllowed("NightWatch", "RitualDirk")).toBe(false)
		expect(Rules.weaponAllowed("NightWatch", "RattleRepeater")).toBe(true)
	end)

	it("checks character tier restrictions when the caller supplies a tier", function()
		withClass({ minWeaponTier = 2, maxWeaponTier = 3 }, function()
			expect(Rules.weaponAllowed("ManyHands", "RitualDirk")).toBe(true)
			expect(Rules.weaponAllowed("ManyHands", "RitualDirk", 1)).toBe(false)
			expect(Rules.weaponAllowed("ManyHands", "RitualDirk", 2)).toBe(true)
			expect(Rules.weaponAllowed("ManyHands", "RitualDirk", 3)).toBe(true)
			expect(Rules.weaponAllowed("ManyHands", "RitualDirk", 4)).toBe(false)
			expect(Rules.hasSlot("ManyHands", "RitualDirk", {}, nil, 1)).toBe(false)
			expect(Rules.hasSlot("ManyHands", "RitualDirk", {}, nil, 2)).toBe(true)
		end)
	end)

	it("checks the weapon minimum and rejects non-existent tiers", function()
		expect(Rules.weaponAllowed("ManyHands", "OrbitBlades", 1)).toBe(false)
		expect(Rules.weaponAllowed("ManyHands", "OrbitBlades", 2)).toBe(true)
		expect(Rules.weaponAllowed("ManyHands", "RitualDirk", 0)).toBe(false)
		expect(Rules.weaponAllowed("ManyHands", "RitualDirk", 5)).toBe(false)
		expect(Rules.weaponAllowed("ManyHands", "RitualDirk", 1.5)).toBe(false)
	end)
end)

describe("Character stat bonuses", function()
	it("counts each weapon at its held tier without changing the sheet", function()
		withClass({
			perWeapon = {},
			perDistinctWeapon = {},
			conversions = {},
			perTierWeapon = { [1] = { damage = -15, attackSpeed = -15 }, [4] = { damage = 25, attackSpeed = 25 } },
		}, function()
			local sheet = { damage = 7 }
			local result = Rules.bonuses("ManyHands", sheet, {
				{ id = "RitualDirk", tier = 4 },
				{ id = "RitualDirk", tier = 4 },
				{ id = "RattleRepeater", tier = 1 },
				{ id = "BrassKnuckles", tier = 2 },
			})
			expect(result.damage).toBe(35)
			expect(result.attackSpeed).toBe(35)
			expect(sheet.damage).toBe(7)
			expect(sheet.attackSpeed).toBe(nil)
		end)
	end)

	it("preserves simultaneous conversions and permanent-only sources", function()
		withClass({
			perWeapon = {},
			perDistinctWeapon = {},
			conversions = {
				{ source = "rangedDamage", target = "meleeDamage", per = 1, amount = 2 },
				{ source = "meleeDamage", target = "rangedDamage", per = 2, amount = 1 },
				{ source = "maxHp", target = "damage", per = 3, amount = 1, permanentOnly = true },
			},
		}, function()
			local sheet = { rangedDamage = 2, meleeDamage = 4, maxHp = 30 }
			local result = Rules.bonuses("ManyHands", sheet, {}, { maxHp = 12 })
			expect(result.meleeDamage).toBe(4)
			expect(result.rangedDamage).toBe(2)
			expect(result.damage).toBe(4)
			expect(sheet.meleeDamage).toBe(4)
			expect(sheet.rangedDamage).toBe(2)
		end)
	end)

	it("truncates the complete linked amount toward zero before applying target gain modifiers", function()
		withClass({
			perWeapon = {},
			perDistinctWeapon = {},
			gainMultipliers = { meleeDamage = 2, rangedDamage = 0.5 },
			conversions = {
				{ source = "rangedDamage", target = "meleeDamage", per = 1, amount = 2 },
				{ source = "meleeDamage", target = "rangedDamage", per = 2, amount = 1 },
			},
		}, function()
			local result = Rules.bonuses("ManyHands", { rangedDamage = 2.5, meleeDamage = -3 }, {})
			expect(result.meleeDamage).toBe(10)
			expect(result.rangedDamage).toBe(-0.5)
		end)
	end)

	it("encodes class and kind modifiers only in a separate weapon sheet", function()
		withClass({
			weaponClassStats = { Keen = { range = 100, critDamage = 200 }, Remedy = { attackSpeed = 200 } },
			weaponKindStats = { Melee = { range = 50 }, Ranged = { damage = 10 } },
		}, function()
			local sheet = { damage = 7, range = 5 }
			local result = Rules.weaponSheet("ManyHands", sheet)
			expect(result ~= sheet).toBe(true)
			expect(result.damage).toBe(7)
			expect(result.range).toBe(5)
			expect(result["class.Keen.range"]).toBe(100)
			expect(result["class.Keen.critDamage"]).toBe(200)
			expect(result["class.Remedy.attackSpeed"]).toBe(200)
			expect(result["kind.Melee.range"]).toBe(50)
			expect(result["kind.Ranged.damage"]).toBe(10)
			expect(sheet["class.Keen.range"]).toBe(nil)
			expect(sheet["kind.Melee.range"]).toBe(nil)
		end)
	end)

	it("returns an independent ordinary sheet without a known character", function()
		local sheet = { damage = 3 }
		local result = Rules.weaponSheet("Unknown", sheet)
		result.damage = 9
		expect(sheet.damage).toBe(3)
	end)
end)
