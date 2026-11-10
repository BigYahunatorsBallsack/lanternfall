--!strict
-- Native Shovel's extra crate roll is independent of Luck, excludes guaranteed-loot units, and weakens per spawned crate.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Util.LootRules)
describe("Native Shovel loot", function()
	it("uses the direct weapon chance divided by the wave's already-spawned crate count", function()
		local normal = Config.Enemies.types.Shadeling
		expect(Rules.dugCrate(normal, 0.02, 0, 0.02)).toBe(true)
		expect(Rules.dugCrate(normal, 0.02, 1, 0.01001)).toBe(false)
		expect(Rules.dugCrate(normal, 0.02, 1, 0.01)).toBe(true)
		expect(Rules.dugCrate(normal, 0, 0, 0)).toBe(false)
	end)
	it("does not replace guaranteed loot or dig from a neutral tree", function()
		expect(Rules.dugCrate(Config.Enemies.types.Looter, 1, 0, 0)).toBe(false)
		expect(Rules.dugCrate(Config.Enemies.types.Tree, 1, 0, 0)).toBe(false)
	end)
end)
