--!strict
-- Stable Buffer formulas distinguish turret base damage, intrinsic burns, mine snapshots and trap marking.
loadHelper("tests/helpers/RobloxMock.luau")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.StructureService
local Boost, Rules = require(S.BoostRules), require(S.Rules)
describe("Native structure boosts", function()
	it("changes turret base stats before Engineering and separate structure attack speed", function()
		local base = Config.Structures.kinds.BrassSentry
		local boosted = Boost.definition(base, { engineering = 10 }, 20, 20, 20)
		expect(Rules.damage(boosted, { engineering = 10 })).toBe(20) -- 12 base +8 Engineering, not 18*1.2
		expect(Rules.range(boosted, { structureRange = 50 })).toBe(41)
		expect(Rules.interval(boosted, { structureAttackSpeed = 100 }, false)).toBe(12 / 60)
		expect(base.damage).toBe(10)
		local flame = Boost.definition(Config.Structures.kinds.CinderSentry, {}, 20, 20, 20)
		expect(flame.burnBase).toBe(5) -- FlameTurret forces contact damage1; Buffer does not change its burning data
	end)
	it("boosts a mine's already-scaled damage and explosion while a trap is only marked", function()
		local mine = table.clone(Config.Structures.kinds.RuneMine)
		mine.boostMode = "Mine"
		local boosted = Boost.definition(mine, { engineering = 10, explosionDamage = 50 }, 20, 20, 20)
		expect(Rules.damage(boosted, { engineering = 10, explosionDamage = 50 })).toBe(36)
		expect(boosted.radius).toBeNear(25.7845 * 1.2)
		local trap = table.clone(Config.Structures.kinds.DartTrap)
		trap.boostMode = "Trap"
		local marked = Boost.definition(trap, { engineering = 10 }, 20, 20, 20)
		expect(Rules.damage(marked, { engineering = 10 })).toBe(18)
	end)
end)
