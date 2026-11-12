--!strict
-- Production result observers capture the real area, save distinct wins, isolate players and preserve Nightmare progress across sessions.
local store
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch", function(server)
	local S = server.Services
	store = require(S.PlayerDataService.MemoryStore).new(require(S.PlayerDataService.ProfileTemplate).new())
	require(S.PlayerDataService).useStore(store)
end)
describe("Native Nightmare result recording", function()
	it("records a completed Danger 5 run with the server-captured Crash Zone for both participants", function()
		assert(f.Run.selectClass(f.me, "NightWatch"))
		local options = require(f.Shared.Util.DangerRules).defaultOptions()
		options.danger = 5
		assert(f.Run.launch({ f.me, f.peer }, options))
		f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
		f.Weapons.setPaused(true)
		require(f.S.EnemySim).killAll()
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
			expect(f.Data.get(player).nativeZoneBest.NightWatch["0"]).toBe(5)
			expect(f.Data.hasNativeNightmareAccess(player)).toBe(false)
		end
		expect(f.Run.getNativeZoneId()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
	it(
		"updates and saves the actual player's prerequisite at ten distinct records without changing the danger cap",
		function()
			local ids = { "Baby", "Jack", "Vampire", "BeastMaster", "Soldier", "Speedy", "Vagabond", "King", "Loud" }
			for index, classId in ids do
				assert(
					f.Data.recordRun(
						f.me,
						{
							won = true,
							wave = 20,
							danger = 5,
							zoneId = 0,
							classId = classId,
							kills = 0,
							bossKills = 2,
							seconds = 1200,
						}
					)
				)
				expect(f.Data.hasNativeNightmareAccess(f.me)).toBe(index == #ids)
			end
			expect(f.Data.hasNativeNightmareAccess(f.peer)).toBe(false)
			expect(store.saved["Player_1"].nativeZoneBest.Loud["0"]).toBe(5)
			expect(f.Data.maxDanger(f.me, "NightWatch")).toBe(5) -- mode still gated until its real runtime exists
		end
	)
	it("restores the same distinct records on a new profile session", function()
		f.world.removePlayer(f.me)
		local again = f.world.addPlayer("OwnerAgain", 1, true)
		f.world.advance(0.5)
		expect(f.Data.hasNativeNightmareAccess(again)).toBe(true)
		expect(f.Data.get(again).nativeZoneBest.NightWatch["0"]).toBe(5)
		expect(f.Data.get(f.peer).nativeZoneBest.Loud).toBe(nil)
		expect(#f.world.errors).toBe(0)
	end)
end)
