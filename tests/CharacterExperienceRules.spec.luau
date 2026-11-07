--!strict
-- Native XP thresholds, level-up flags and material sharing contracts; called by the standalone Luau test runner.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
local Rules = require(Server.Services.ExperienceService.CharacterRules)

local function withEffects(effects, check)
	local class = Config.Classes.ManyHands
	local before = class.native
	class.native = { sourceEffects = effects }
	local ok, message = pcall(check)
	class.native = before
	assert(ok, message)
end

local function effect(key, amount, storage, custom, effectType)
	return {
		sourceKey = key,
		amount = amount,
		storageMethod = storage,
		customKey = custom or "",
		effectType = effectType or "res://items/global/effect.gd",
	}
end

describe("Native character XP thresholds", function()
	it("retains normal progression for unknown, ordinary and legacy characters", function()
		for _, id in { "Unknown", "WellRounded", "NightWatch", "LanternKeeper" } do
			local result = Rules.forClass(id)
			expect(result.xpNeededMultiplier).toBe(1)
			expect(result.cardsAllowed).toBe(true)
		end
		expect(Rules.forClass(nil).xpNeededMultiplier).toBe(1)
	end)

	it("reads the installed 1.2.0.1 Mutant, Baby, Captain and Technomage modifiers", function()
		expect(Rules.forClass("Mutant").xpNeededMultiplier).toBeNear(0.34)
		expect(Rules.forClass("Baby").xpNeededMultiplier).toBeNear(2.3)
		expect(Rules.forClass("Captain").xpNeededMultiplier).toBe(3)
		expect(Rules.forClass("Technomage").xpNeededMultiplier).toBe(1.75)
	end)

	it("preserves fractional thresholds instead of rounding the resulting requirement", function()
		local multiplier = Rules.forClass("Mutant").xpNeededMultiplier
		local needed = 16 * multiplier
		expect(needed).toBeNear(5.44)
		expect(5.4 >= needed).toBe(false)
		expect(5.44 >= needed).toBe(true)
	end)

	it("adds multiple native modifiers before converting percentage points into a factor", function()
		withEffects({ effect("next_level_xp_needed", -50, 0), effect("next_level_xp_needed", 25, 0) }, function()
			expect(Rules.forClass("ManyHands").xpNeededMultiplier).toBe(0.75)
		end)
	end)

	it("rejects conditional, specialized and non-additive effects that only reuse an XP key", function()
		withEffects({
			effect("next_level_xp_needed", -90, 1),
			effect("next_level_xp_needed", -90, 2),
			effect("next_level_xp_needed", -90, 0, "stats_on_level_up"),
			effect("next_level_xp_needed", -90, 0, "", "res://effects/items/double_value_effect.gd"),
			effect("xp_gain", 200, 0),
		}, function()
			expect(Rules.forClass("ManyHands").xpNeededMultiplier).toBe(1)
		end)
	end)
end)

describe("Native level-up queue eligibility", function()
	it("suppresses Droid upgrades while preserving Baby's separate weapon-slot choice", function()
		expect(Rules.forClass("Droid").cardsAllowed).toBe(false)
		expect(Rules.forClass("Baby").cardsAllowed).toBe(true)
		expect(Rules.forClass("Mutant").cardsAllowed).toBe(true)
	end)

	it("requires the plain native absolute flag and treats zero as disabled", function()
		withEffects({ effect("no_level_upgrades", 0, 2), effect("no_level_upgrades", 1, 1) }, function()
			expect(Rules.forClass("ManyHands").cardsAllowed).toBe(true)
		end)
		withEffects({ effect("no_level_upgrades", 1, 2, "conditional") }, function()
			expect(Rules.forClass("ManyHands").cardsAllowed).toBe(true)
		end)
		withEffects({ effect("no_level_upgrades", 1, 2) }, function()
			expect(Rules.forClass("ManyHands").cardsAllowed).toBe(false)
		end)
	end)
end)

describe("Native round-robin material sharing", function()
	it("gives one material per positive loop iteration, including fractional remainders", function()
		local shares, nextIndex = Rules.distributeMaterials(0.01, 2, 1)
		expect(shares[1]).toBe(1)
		expect(shares[2]).toBe(0)
		expect(nextIndex).toBe(2)
		shares, nextIndex = Rules.distributeMaterials(1.01, 2, 1)
		expect(shares[1]).toBe(1)
		expect(shares[2]).toBe(1)
		expect(nextIndex).toBe(1)
	end)

	it("retains exact integer boundaries and leaves nonpositive pickups unchanged", function()
		local shares, nextIndex = Rules.distributeMaterials(4, 3, 2)
		expect(shares[1]).toBe(1)
		expect(shares[2]).toBe(2)
		expect(shares[3]).toBe(1)
		expect(nextIndex).toBe(3)
		for _, value in { 0, -0.1, -10 } do
			shares, nextIndex = Rules.distributeMaterials(value, 3, 2)
			expect(shares[1] + shares[2] + shares[3]).toBe(0)
			expect(nextIndex).toBe(2)
		end
	end)

	it("rotates across successive pickups without receiving or favoring a collector", function()
		local first, nextIndex = Rules.distributeMaterials(1, 3, 1)
		local second
		second, nextIndex = Rules.distributeMaterials(2, 3, nextIndex)
		local third
		third, nextIndex = Rules.distributeMaterials(1, 3, nextIndex)
		expect(first[1] + second[1] + third[1]).toBe(2)
		expect(first[2] + second[2] + third[2]).toBe(1)
		expect(first[3] + second[3] + third[3]).toBe(1)
		expect(nextIndex).toBe(2)
	end)

	it("wraps a saved index when the participant count changes", function()
		local shares, nextIndex = Rules.distributeMaterials(1, 2, 4)
		expect(shares[1]).toBe(0)
		expect(shares[2]).toBe(1)
		expect(nextIndex).toBe(1)
	end)

	it("handles solo and billion-material pickups with bounded work", function()
		local solo, nextIndex = Rules.distributeMaterials(2.2, 1, 1)
		expect(solo[1]).toBe(3)
		expect(nextIndex).toBe(1)
		local shares
		shares, nextIndex = Rules.distributeMaterials(1000000001, 4, 3)
		expect(shares[1]).toBe(250000000)
		expect(shares[2]).toBe(250000000)
		expect(shares[3]).toBe(250000001)
		expect(shares[4]).toBe(250000000)
		expect(nextIndex).toBe(4)
	end)
end)
