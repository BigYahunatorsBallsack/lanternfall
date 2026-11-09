--!strict
-- Native per-player progression, rotating material recipients and retry restoration through real services.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run = require(S.RunDirector)
local Stats = require(S.StatService)
local Experience = require(S.ExperienceService)
local Shop = require(S.ShopService)
local Upgrade = require(S.UpgradeService)
local Enemy = require(S.EnemySim)
local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
Config.Classes.Mutant.available = true
require(S.PlayerDataService).unlockAll(me)
world.fireServerAs(me, "SelectClass", "Mutant")
require(S.SpawnDirector).setPaused(true)
require(S.WeaponService).setPaused(true)
Run.setHoldWaves(true)
Run.setReady(me, true)
Run.setReady(peer, true)
world.advance(3.5)
Enemy.killAll()

-- Two players get Brotato's co-op material bonus (+43 %, a 1-orb is worth 1 or 2 by chance); a high Loot roll keeps
-- every orb at 1 so the round-robin counts stay exact (orbs still drop: wave 1 drops 100 %).
local RandomService = require(S.RandomService)
local originalNumber = RandomService.number
RandomService.number = function(stream: string, ...)
	return if stream == "Loot" then 0.99 else originalNumber(stream, ...)
end

local function pickup(count)
	local here = me.Character.HumanoidRootPart.Position
	for _ = 1, count do
		local id = assert(Enemy.spawn("Shadeling", here.X, here.Z, 1, 1))
		Enemy.damage(id, 10000, me)
	end
	world.advance(0.1)
end

describe("Native character progression", function()
	it("distributes materials and XP round-robin even when one player collects every orb", function()
		local goldA, goldB = Shop.getShards(me), Shop.getShards(peer)
		pickup(3)
		expect(Shop.getShards(me)).toBe(goldA + 2)
		expect(Shop.getShards(peer)).toBe(goldB + 1)
		expect(Experience.getProgress(me).xp).toBe(2)
		expect(Experience.getProgress(peer).xp).toBe(1)
		expect(math.abs(Experience.getProgress(me).needed - 5.44) < 0.00001).toBe(true)
		expect(Experience.getProgress(peer).needed).toBe(16)
	end)

	it("applies personal XP Gain and individual level HP without granting teammates a level", function()
		local hpA, hpB = Stats.getStat(me, "maxHp"), Stats.getStat(peer, "maxHp")
		Stats.addStats(me, { xpGain = 50 })
		pickup(2)
		expect(Experience.getProgress(me).xp).toBe(3.5)
		expect(Experience.getProgress(peer).xp).toBe(2)
		Experience.addXp(2, me)
		expect(Experience.getLevel(me)).toBe(1)
		expect(Experience.getLevel(peer)).toBe(0)
		expect(Stats.getStat(me, "maxHp")).toBe(hpA + 1)
		expect(Stats.getStat(peer, "maxHp")).toBe(hpB)
	end)

	it("opens a stat card only for the player who earned the level", function()
		Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
		expect(Upgrade.getOffer(me) ~= nil).toBe(true)
		expect(Upgrade.getOffer(peer)).toBe(nil)
	end)

	it("restores individual progression and the next rotating material recipient on retry", function()
		world.fireServerAs(me, "SetShopReady", true)
		world.fireServerAs(peer, "SetShopReady", true)
		world.advance(0.2)
		expect(Run.getPhase()).toBe("Running")
		local a, b = Experience.getProgress(me), Experience.getProgress(peer)
		local goldA, goldB = Shop.getShards(me), Shop.getShards(peer)
		Experience.addXp(30, peer)
		pickup(1)
		Run.setParticipantState(me, "Down")
		Run.setParticipantState(peer, "Down")
		assert(Run.retryWave(me))
		world.advance(0.1)
		expect(Experience.getProgress(me).xp).toBe(a.xp)
		expect(Experience.getProgress(peer).xp).toBe(b.xp)
		expect(Experience.getLevel(me)).toBe(a.level)
		expect(Experience.getLevel(peer)).toBe(b.level)
		pickup(1)
		expect(Shop.getShards(me)).toBe(goldA)
		expect(Shop.getShards(peer)).toBe(goldB + 1)
	end)
end)
