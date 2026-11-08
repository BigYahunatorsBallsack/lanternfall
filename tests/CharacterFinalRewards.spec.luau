--!strict
-- Real service coverage for final-wave settlement, result ordering, endless votes and failed-wave retries.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run = require(S.RunDirector)
local Stats = require(S.StatService)
local Shop = require(S.ShopService)
local XP = require(S.ExperienceService)
local Enemy = require(S.EnemySim)
local Schedule = require(Shared.Util.RunSchedule)
local Danger = require(Shared.Util.DangerRules)
local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
Config.Classes.Pacifist.available = true
Config.Classes.Cryptid.available = true
require(S.PlayerDataService).unlockAll(me)
require(S.PlayerDataService).unlockAll(peer)
world.fireServerAs(me, "SelectClass", "Pacifist")
world.fireServerAs(peer, "SelectClass", "Cryptid")
require(S.SpawnDirector).setPaused(true)
require(S.WeaponService).setPaused(true)
Run.setHoldWaves(true)
XP.setPaused(true)
local resultWallets = {}
local summary
world.getRemote("RunSummary").OnClientEvent:Connect(function(value)
	summary = value
end)
Run.RunEnded:Connect(function()
	resultWallets = { Shop.getShards(me), Shop.getShards(peer) }
end)

local function start(firstNight, endless)
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
	end
	local options = Danger.defaultOptions()
	options.firstNight = if firstNight then true else nil
	options.endless = endless == true
	assert(Run.launch({ me, peer }, options))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	expect(Run.getPhase()).toBe("Running")
	Enemy.killAll()
	for _, player in { me, peer } do
		Stats.addStats(player, { harvesting = -Stats.getStat(player, "harvesting") })
	end
	Stats.addStats(me, { harvesting = 10 })
	Stats.addItem(me, "OathRing")
end

local function survivors()
	for _ = 1, 10 do
		assert(Enemy.spawn("Shadeling", 40, 40, 1, 1))
	end
	assert(Enemy.spawn("Tree", 40, 40, 1, 1))
	assert(Enemy.spawn("Tree", 40, 40, 1, 1))
end

local function totalXp(player)
	local progress = XP.getProgress(player)
	local result = progress.xp
	for level = 0, progress.level - 1 do
		result += (level + 4) ^ 2
	end
	return result
end

describe("Native final wave rewards", function()
	it("settles direct final-wave victory before results without opening a shop", function()
		start(true, false)
		survivors()
		local damage = Stats.getStat(me, "damage")
		Run.skipTo(Schedule.wave(Config.FirstNight.waves).endsAt)
		expect(Run.getPhase()).toBe("Ended")
		expect(Enemy.getCount()).toBe(0)
		expect(Shop.isOpen(me)).toBe(false)
		expect(Shop.getShards(me)).toBe(17)
		expect(Shop.getShards(peer)).toBe(24)
		expect(totalXp(me)).toBe(17)
		expect(totalXp(peer)).toBe(24)
		expect(Stats.getStat(me, "damage")).toBe(damage + 3)
		expect(Stats.getStat(me, "harvesting")).toBe(11)
		expect(resultWallets[1]).toBe(17)
		expect(resultWallets[2]).toBe(24)
		expect(summary.teamLevel).toBe(1)
	end)

	it("rejects repeated victory and ordinary XP grants after results", function()
		local gold, xp = Shop.getShards(me), totalXp(me)
		expect(Run.endRun("Victory")).toBe(false)
		expect(XP.addXp(100, me)).toBe(false)
		world.advance(0.2)
		expect(Shop.getShards(me)).toBe(gold)
		expect(totalXp(me)).toBe(xp)
	end)

	it("settles the boss wave once when an endless vote ends in victory", function()
		start(false, false)
		survivors()
		local damage = Stats.getStat(me, "damage")
		Run.skipTo(Schedule.wave(Schedule.waveCount()).endsAt)
		expect(Run.getPhase()).toBe("Shop")
		expect(Shop.getShards(me)).toBe(17)
		expect(Shop.getShards(peer)).toBe(24)
		local xp = totalXp(me)
		world.fireServerAs(me, "ChooseEndless", false)
		world.fireServerAs(peer, "ChooseEndless", false)
		expect(Run.getPhase()).toBe("Ended")
		expect(Shop.getShards(me)).toBe(17)
		expect(Shop.getShards(peer)).toBe(24)
		expect(totalXp(me)).toBe(xp)
		expect(Stats.getStat(me, "damage")).toBe(damage + 3)
	end)

	it("does not settle a lost wave or leak its survivor count through retry", function()
		start(false, false)
		survivors()
		local damage = Stats.getStat(me, "damage")
		Run.setParticipantState(me, "Out")
		Run.setParticipantState(peer, "Out")
		expect(Run.getPhase()).toBe("Ended")
		expect(Shop.getShards(me)).toBe(0)
		expect(Shop.getShards(peer)).toBe(0)
		expect(totalXp(me)).toBe(0)
		expect(Stats.getStat(me, "damage")).toBe(damage)
		assert(Run.retryWave(me))
		expect(Run.getPhase()).toBe("Running")
		Enemy.killAll()
		for _, player in { me, peer } do
			Stats.addStats(player, { harvesting = -Stats.getStat(player, "harvesting") })
		end
		assert(Enemy.spawn("Tree", 40, 40, 1, 1))
		Run.endRun("Victory")
		expect(Run.getPhase()).toBe("Ended")
		expect(Shop.getShards(me)).toBe(0)
		expect(Shop.getShards(peer)).toBe(12)
		expect(totalXp(peer)).toBe(12)
	end)

	it("does not treat an endless defeat recorded as victory as a completed wave", function()
		start(false, true)
		survivors()
		Run.skipTo(Schedule.wave(Schedule.waveCount()).endsAt)
		world.fireServerAs(me, "SetShopReady", true)
		world.fireServerAs(peer, "SetShopReady", true)
		world.advance(0.2)
		expect(Run.getPhase()).toBe("Running")
		expect(Run.getWave()).toBe(Schedule.waveCount() + 1)
		survivors()
		local gold, xp, damage = Shop.getShards(me), totalXp(me), Stats.getStat(me, "damage")
		Run.setParticipantState(me, "Out")
		Run.setParticipantState(peer, "Out")
		expect(Run.getPhase()).toBe("Ended")
		expect(Shop.getShards(me)).toBe(gold)
		expect(totalXp(me)).toBe(xp)
		expect(Stats.getStat(me, "damage")).toBe(damage)
	end)
end)
