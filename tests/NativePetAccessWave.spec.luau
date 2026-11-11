--!strict
-- Lootworm uses remaining material value on completed waves, including terminal victories before cleanup, never defeat.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("ManyHands")
local XP = require(f.S.ExperienceService)
local Access = require(f.Shared.Util.CharacterAccess)
local rule = require(f.Shared.Config.PetAccess).items.Lootworm
local function start(value: number)
	if f.Run.isOngoing() then
		f.Run.endRun("Abandoned")
	end
	if f.Run.getPhase() == "Ended" then
		f.world.advance(f.Config.Run.flow.resultsSeconds + 0.1)
	end
	XP.setPaused(true)
	assert(f.Run.selectClass(f.me, "ManyHands"))
	assert(f.Weapons.selectStartWeapon(f.me, "ManyHands", f.class.startWeapons[1]))
	assert(f.Run.launch({ f.me }, require(f.Shared.Util.DangerRules).defaultOptions()))
	f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
	XP.setPaused(false)
	f.Data.get(f.me).achievements[Access.challengeKey(rule.challengeId)] = nil
	XP.dropMaterials(Vector3.new(0, f.Config.Map.arena.center.Y, 0), value, 0)
	XP.setPaused(true)
	expect(XP.getMaterialsOnFloor()).toBe(value)
end
describe("Native pet completed-wave challenge", function()
	it("does not round nineteen remaining materials up to twenty", function()
		start(19)
		f.Run.endRun("Victory")
		expect(Access.petUnlocked(f.Data.get(f.me), "Lootworm")).toBe(false)
	end)
	it("does not award twenty floor materials on defeat", function()
		start(20)
		f.Run.endRun("Defeat")
		expect(Access.petUnlocked(f.Data.get(f.me), "Lootworm")).toBe(false)
	end)
	it("awards terminal victory before the material field is cleared", function()
		start(20)
		f.Run.endRun("Victory")
		expect(Access.petUnlocked(f.Data.get(f.me), "Lootworm")).toBe(true)
		expect(XP.getMaterialsOnFloor()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
