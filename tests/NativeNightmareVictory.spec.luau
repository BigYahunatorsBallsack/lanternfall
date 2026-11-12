--!strict
-- Production twenty-wave Nightmare result records unlock Wounded personally; this simulates the wave lifecycle, not real Studio combat acceptance.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Records = require(f.S.PlayerDataService.ProfileRecords)
local Access = require(f.Shared.Util.CharacterAccess)
local Combat = require(f.S.CombatService)
local data = assert(f.Data.get(f.me))
for _, id in { "Baby", "Jack", "Vampire", "BeastMaster", "Soldier", "Speedy", "Vagabond", "King", "Loud", "Old" } do
	Records.applyRun(
		data,
		{ won = true, wave = 20, danger = 5, zoneId = 0, classId = id, kills = 0, bossKills = 2, seconds = 1200 }
	)
end
describe("Native Nightmare production victory", function()
	it("starts a legitimately unlocked mode with a teammate who has not unlocked Wounded", function()
		expect(f.Data.hasNativeNightmareAccess(f.me)).toBe(true)
		expect(f.Data.hasNativeNightmareAccess(f.peer)).toBe(false)
		expect(Access.characterUnlocked(f.Data.get(f.peer), "Wounded")).toBe(false)
		assert(f.Run.selectClass(f.me, "NightWatch"))
		local options = require(f.Shared.Util.DangerRules).defaultOptions()
		options.danger = 6
		assert(f.Run.launch({ f.me, f.peer }, options, true))
		f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
		f.Weapons.setPaused(true)
		require(f.S.SpawnDirector).setPaused(true)
		require(f.S.EnemySim).killAll()
		for _, player in { f.me, f.peer } do
			Combat.protect(player, 10000)
		end
		expect(f.Run.getRunOptions().danger).toBe(6)
	end)
	it("records the native area and original difficulty at actual wave20 victory for both participants", function()
		for _ = 1, 19 do
			f.nextWave()
			f.Weapons.setPaused(true)
		end
		expect(f.Run.getWave()).toBe(20)
		if f.Run.getPhase() ~= "Ended" then
			assert(f.Run.endRun("Victory"))
		end
		if f.Run.getPhase() == "Shop" then
			for _, player in { f.me, f.peer } do
				f.world.fireServerAs(player, "ChooseEndless", false)
			end
		end
		f.world.advance(0.1)
		expect(f.Run.getPhase()).toBe("Ended")
		for _, player in { f.me, f.peer } do
			expect(f.Data.get(player).nativeZoneBest.NightWatch["0"]).toBe(6)
			expect(Access.characterUnlocked(f.Data.get(player), "Wounded")).toBe(true)
		end
		expect(f.Data.hasNativeNightmareAccess(f.peer)).toBe(false)
		expect(#f.world.errors).toBe(0)
	end)
end)
