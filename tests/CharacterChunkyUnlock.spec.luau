--!strict
-- Chunky's native first-team-death unlock through actual run outcomes; Flail/Jungle dependency still keeps the package unready.
local store
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded", function(server)
	store = require(server.Services.PlayerDataService.MemoryStore).new(
		require(server.Services.PlayerDataService.ProfileTemplate).new()
	)
	require(server.Services.PlayerDataService).useStore(store)
end)
local Access = require(f.Shared.Util.CharacterAccess)
local Combat = require(f.S.CombatService)
local key = Access.challengeKey("chal_rookie")
local function clearGrant(player)
	local data = f.Data.get(player)
	data.achievements[key] = nil
	local index = table.find(data.classes, "MarbleHost")
	if index then
		table.remove(data.classes, index)
	end
end
clearGrant(f.me)
clearGrant(f.peer)
local spectator = f.world.addPlayer("Spectator", 3, false)
f.world.advance(0.5)
local function unlocked(player)
	return Access.characterUnlocked(f.Data.get(player), "MarbleHost")
end
describe("Native Chunky first death", function()
	it("does not invent a previous death from ambiguous historical runs and wins", function()
		local data = f.Data.get(f.me)
		data.stats.runs = 20
		data.stats.wins = 0
		expect(unlocked(f.me)).toBe(false)
		expect((f.Config.Classes.MarbleHost.pendingNative or f.Config.Classes.MarbleHost).nativeCodeReady == true).toBe(
			false
		)
	end)
	it("does not unlock from abandonment or a victory", function()
		for _, outcome in { "Abandoned", "Victory" } do
			f.start("WatchmanPistol")
			f.Run.endRun(outcome)
			expect(unlocked(f.me)).toBe(false)
			expect(unlocked(f.peer)).toBe(false)
		end
	end)
	it("waits for the last living participant and grants only the failed run's participants before retry", function()
		f.start("WatchmanPistol")
		Combat.drainPlayer(f.me, 100000)
		f.world.advance(0.1)
		expect(f.Run.getParticipantState(f.me)).toBe("Down")
		expect(unlocked(f.me)).toBe(false)
		Combat.drainPlayer(f.peer, 100000)
		f.world.advance(0.2)
		expect(f.Run.getPhase()).toBe("Ended")
		expect(unlocked(f.me)).toBe(true)
		expect(unlocked(f.peer)).toBe(true)
		expect(unlocked(spectator)).toBe(false)
	end)
	it("retains the first-death cause when an endless death is displayed as Victory", function()
		f.world.advance(f.Config.Run.flow.resultsSeconds + 0.1)
		clearGrant(f.me)
		clearGrant(f.peer)
		expect(unlocked(f.me)).toBe(false)
		assert(f.Run.selectClass(f.me, "WellRounded"))
		assert(f.Weapons.selectStartWeapon(f.me, "WellRounded", "WatchmanPistol"))
		local options = require(f.Shared.Util.DangerRules).defaultOptions()
		options.endless = true
		assert(f.Run.launch({ f.me, f.peer }, options))
		f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
		f.Weapons.setPaused(true)
		for _ = 1, 20 do
			f.nextWave()
			f.Weapons.setPaused(true)
		end
		expect(f.Run.getWave()).toBe(21)
		local results
		local connection = f.Run.RunEnded:Connect(function(value)
			results = value
		end)
		Combat.drainPlayer(f.me, 100000)
		Combat.drainPlayer(f.peer, 100000)
		f.world.advance(0.2)
		connection:Disconnect()
		assert(results)
		expect(results.outcome).toBe("Victory")
		expect(results.defeated).toBe(true)
		expect(unlocked(f.me)).toBe(true)
		expect(unlocked(f.peer)).toBe(true)
		expect(unlocked(spectator)).toBe(false)
	end)
	it("persists the source flag across a profile release and rejoin", function()
		f.world.removePlayer(f.me)
		local rejoined = f.world.addPlayer("Owner", 1, true)
		f.world.advance(0.5)
		expect(f.Data.get(rejoined).achievements[key]).toBe(true)
		expect(unlocked(rejoined)).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
