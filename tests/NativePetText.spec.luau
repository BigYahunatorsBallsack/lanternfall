--!strict
-- Original pet descriptions use real shared calculations, owner stats, native formatting and caller-compatible tooltip APIs.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("BeastMaster")
local Text = require(f.Shared.Util.PetText)
local PetStats = require(f.Shared.Util.NativePetStats)
local UpgradeText = require(f.Shared.Util.UpgradeText)
local TooltipText = require(f.Shared.Util.TooltipText)
local function contains(text: string, part: string)
	assert(string.find(text, part, 1, true) ~= nil, `Expected "{part}" in "{text}"`)
end
describe("Native pet descriptions", function()
	it("renders all six original templates without unresolved arguments", function()
		for _, id in { "Ratzilla", "BonkDog", "CatlingGun", "BotOMine", "Blazemander", "Lootworm" } do
			local text = Text.line(id)
			contains(text, "Spawns a ")
			expect(string.find(text, "{", 1, true)).toBe(nil)
			expect(string.find(text, "nil", 1, true)).toBe(nil)
		end
		contains(Text.line("Lootworm"), "10% chance to double it")
	end)
	it("uses current HP, Beast Master's expansion and additional item scaling in the shown damage", function()
		local owner = {
			maxHp = 50,
			meleeDamage = 10,
			rangedDamage = 20,
			elementalDamage = 30,
			engineering = 40,
			nativePetScaling = 1,
			weaponScalingEngineering = 20,
			weaponScalingElemental = 10,
		}
		contains(Text.line("Ratzilla", owner), "deals 30 (")
		contains(Text.line("Ratzilla", owner), "+30% Engineering")
		contains(Text.line("Ratzilla", { maxHp = 50 }), "deals 9 (")
		expect(PetStats.compute(require(f.Shared.Config.Pets).kinds.Ratzilla.weapon, owner, true).damage).toBe(30)
	end)
	it("keeps Blazemander's intrinsic burn scaling separate from extra weapon scaling", function()
		local owner = {
			elementalDamage = 20,
			engineering = 10,
			nativeGlobalBurnDamage = 1,
			weaponScalingEngineering = 20,
			weaponScalingElemental = 10,
		}
		contains(Text.line("Blazemander", owner), "5x14 (+50% Elemental Damage) burning damage")
	end)
	it(
		"preserves the native tooltip's structure-speed calculation without changing the Bot's raw mine interval",
		function()
			contains(Text.line("BotOMine", { structureAttackSpeed = 100 }), "every 2.5 seconds")
			contains(Text.line("BotOMine", { attackSpeed = 100, nativeImprovedTools = 1 }), "every 3.3 seconds")
			contains(Text.line("BonkDog", { attackSpeed = 1000, structureAttackSpeed = 1000 }), "Every 5 seconds")
			expect(require(f.Shared.Config.Pets).kinds.BotOMine.mineIntervalFrames).toBe(300)
		end
	)
	it("keeps the original generic item tooltip calls usable while accepting actual owner sheets", function()
		contains(UpgradeText.itemLines("Ratzilla"), "deals 5 (")
		contains(UpgradeText.itemLines("Ratzilla", nil, nil, { maxHp = 50 }), "deals 9 (")
		local _, text = TooltipText.item("Ratzilla", 1, { maxHp = 50 })
		contains(text, "deals 9 (")
	end)
	it("publishes pet-scaling and Improved Tools context only for the actual owning player", function()
		assert(f.Run.selectClass(f.me, "BeastMaster"))
		assert(f.Run.launch({ f.me, f.peer }, require(f.Shared.Util.DangerRules).defaultOptions()))
		f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
		f.Weapons.setPaused(true)
		assert(f.Stats.addStats(f.me, { maxHp = 40 }))
		local owner = f.Weapons.getStructureStats(f.me)
		expect(owner.nativePetScaling).toBe(1)
		expect(f.Weapons.getStructureStats(f.peer).nativePetScaling).toBe(0)
		contains(Text.line("Ratzilla", owner), "deals 9 (")
		assert(f.Stats.addItem(f.me, "CalibratedTools"))
		owner = f.Weapons.getStructureStats(f.me)
		expect(owner.nativeImprovedTools).toBe(1)
		expect(f.Weapons.getStructureStats(f.peer).nativeImprovedTools).toBe(0)
		contains(Text.line("BotOMine", owner), "every 4.8 seconds")
		expect(#f.world.errors).toBe(0)
	end)
end)
