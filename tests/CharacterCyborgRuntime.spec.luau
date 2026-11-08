--!strict
-- Cyborg conversion timing, snapshot semantics, shop reset and retry through actual services.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run = require(S.RunDirector)
local Stats = require(S.StatService)
local Weapons = require(S.WeaponService)
local Schedule = require(Shared.Util.RunSchedule)
local me = world.addPlayer("Cyborg", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
Config.Classes.Cyborg.available = true
require(S.PlayerDataService).unlockAll(me)
assert(Run.selectClass(me, "Cyborg"))
require(S.SpawnDirector).setPaused(true)
Weapons.setPaused(true)
require(S.ExperienceService).setPaused(true)
Run.setHoldWaves(true)
Run.setReady(me, true)
Run.setReady(peer, true)
world.advance(3.5)
require(S.EnemySim).killAll()
for _, weapon in Weapons.getWeapons(me) do
	assert(Weapons.removeWeapon(me, weapon.uid))
end
Stats.addStats(me, { rangedDamage = 10, engineering = 8 })
local peerRanged = Stats.getStat(peer, "rangedDamage")
local function skip(at)
	assert(Run.skipTo(at))
	world.advance(0.1)
end
describe("Native Cyborg in services", function()
	it("converts once at the actual midpoint and does not alter the peer", function()
		local wave = Schedule.wave(1)
		local half = (wave.startsAt + wave.endsAt) / 2
		skip(half - 0.1)
		expect(Stats.getStat(me, "rangedDamage")).toBe(30)
		expect(Stats.getStat(me, "engineering")).toBe(2)
		skip(half)
		expect(Stats.getStat(me, "rangedDamage")).toBe(0)
		expect(Stats.getStat(me, "engineering")).toBe(62)
		expect(Stats.getStat(peer, "rangedDamage")).toBe(peerRanged)
	end)
	it(
		"keeps the converted amount fixed after later permanent gains and removes only the temporary conversion in the shop",
		function()
			Stats.addStats(me, { rangedDamage = 2 })
			world.advance(0.2)
			expect(Stats.getStat(me, "rangedDamage")).toBe(6)
			expect(Stats.getStat(me, "engineering")).toBe(62)
			skip(Schedule.wave(1).endsAt)
			expect(Run.getPhase()).toBe("Shop")
			expect(Stats.getStat(me, "rangedDamage")).toBe(36)
			expect(Stats.getStat(me, "engineering")).toBe(2)
		end
	)
	it(
		"restores the pre-conversion checkpoint on retry and triggers a fresh conversion at the repeated midpoint",
		function()
			world.fireServerAs(me, "SetShopReady", true)
			world.fireServerAs(peer, "SetShopReady", true)
			world.advance(0.2)
			local wave = Schedule.wave(2)
			local half = (wave.startsAt + wave.endsAt) / 2
			skip(half)
			expect(Stats.getStat(me, "rangedDamage")).toBe(0)
			expect(Stats.getStat(me, "engineering")).toBe(74)
			Run.setParticipantState(me, "Down")
			Run.setParticipantState(peer, "Down")
			world.advance(0.1)
			assert(Run.retryWave(me))
			expect(Stats.getStat(me, "rangedDamage")).toBe(36)
			expect(Stats.getStat(me, "engineering")).toBe(2)
			skip(half)
			expect(Stats.getStat(me, "rangedDamage")).toBe(0)
			expect(Stats.getStat(me, "engineering")).toBe(74)
			expect(Stats.getStat(peer, "rangedDamage")).toBe(peerRanged)
			expect(#world.errors).toBe(0)
		end
	)
end)
