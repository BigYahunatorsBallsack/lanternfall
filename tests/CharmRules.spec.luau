--!strict
-- Original Flute pre-hit HP boundaries, native chance endpoints, eligibility and endless rules.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local W = game:GetService("ServerScriptService").Server.Services.WeaponService
local Rules = require(game:GetService("ServerScriptService").Server.Services.EnemySim.CharmRules)
describe("Native Charm pre-hit rules", function()
	it("requires HP strictly below each tier threshold before damage", function()
		for tier = 1, 4 do
			local stats = require(W.WeaponStats).compute(Config.Weapons.Flute, tier, {}, nil, 0)
			local target = { kind = "Shadeling", hp = stats.charmThreshold * 100, maxHp = 100 }
			expect(Rules.chance(stats, target, 0, 0)).toBe(0)
			target.hp -= 0.01
			expect(Rules.chance(stats, target, 0, 0)).toBeNear(tier * 0.05 + 0.05)
			expect(Rules.chance(stats, target, 0, 8)).toBeNear((tier * 0.05 + 0.05) / 4)
		end
	end)
	it(
		"rejects neutral, loot, dead, elite, boss, protected and already charmed targets and full owner capacity",
		function()
			local stats = { charmChance = 1, charmThreshold = 0.75 }
			local target = { kind = "Shadeling", hp = 10, maxHp = 100 }
			expect(Rules.chance(stats, target, 998, 0)).toBe(1)
			expect(Rules.chance(stats, target, 999, 0)).toBe(0)
			for _, field in { "elite", "boss", "charmed" } do
				local invalid = table.clone(target)
				invalid[field] = true
				expect(Rules.chance(stats, invalid, 0, 0)).toBe(0)
			end
			for _, kind in { "Tree", "Looter" } do
				local invalid = table.clone(target)
				invalid.kind = kind
				expect(Rules.chance(stats, invalid, 0, 0)).toBe(0)
			end
			target.canBeCharmed = false
			expect(Rules.chance(stats, target, 0, 0)).toBe(0)
			target.canBeCharmed = true
			target.hp = 0
			expect(Rules.chance(stats, target, 0, 0)).toBe(0)
		end
	)
	it("preserves native inclusive probability and avoids a random draw at zero chance", function()
		expect(Rules.success(0.1, function()
			return 0.1
		end)).toBe(true)
		expect(Rules.success(0.1, function()
			return 0.1000001
		end)).toBe(false)
		expect(Rules.success(0, function()
			error("unexpected RNG")
		end)).toBe(false)
	end)
end)
