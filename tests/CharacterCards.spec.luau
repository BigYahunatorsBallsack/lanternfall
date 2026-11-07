--!strict
-- Native card modification, exclusions and Baby's slot selection before the limit, without runtime fixtures.
local Shared = game:GetService("ReplicatedStorage").Shared
local Server = game:GetService("ServerScriptService").Server
local Catalog = require(Shared.Config.CharacterCatalog)
local Rules = require(Server.Services.ExperienceService.CharacterRules)
local Pool = require(Server.Services.UpgradeService.UpgradePool)

local function roll(id, slots, wave)
	return Pool.roll({
		classId = id,
		weaponSlots = slots,
		wave = wave or 1,
		level = 5,
		luck = 0,
		cardCount = 4,
		random = function()
			return 0
		end,
	})
end

describe("Native character cards", function()
	it("resolves every source character's card restrictions without unknown upgrade ids", function()
		for id in Catalog do
			assert(Rules.forClass(id))
		end
	end)
	it("doubles Captain card amounts before ordinary stat gain multipliers", function()
		expect(Pool.card("maxHp", 1, "Captain").amount).toBe(6)
		expect(Pool.card("rangedDamage", 3, "Captain").amount).toBe(6)
		expect(Pool.card("maxHp", 1, "WellRounded").amount).toBe(3)
	end)
	it("offers exactly one weapon slot until Baby has 24, then ordinary stat cards", function()
		local cards = roll("Baby", 1)
		expect(#cards).toBe(1)
		expect(cards[1].stat).toBe("weaponSlots")
		expect(cards[1].amount).toBe(1)
		cards = roll("Baby", 23)
		expect(#cards).toBe(1)
		cards = roll("Baby", 24)
		expect(#cards).toBe(4)
		expect(cards[1].stat == "weaponSlots").toBe(false)
	end)
	it("excludes native banned stat cards before wave 20 and lifts that restriction afterwards", function()
		local all = Pool.roll({
			classId = "FarSeer",
			wave = 1,
			level = 5,
			luck = 0,
			cardCount = 99,
			random = function()
				return 0
			end,
		})
		for _, card in all do
			expect(card.stat == "harvesting").toBe(false)
		end
		all = Pool.roll({
			classId = "FarSeer",
			wave = 20,
			level = 5,
			luck = 0,
			cardCount = 99,
			random = function()
				return 0
			end,
		})
		local found = false
		for _, card in all do
			found = found or card.stat == "harvesting"
		end
		expect(found).toBe(true)
	end)
end)
