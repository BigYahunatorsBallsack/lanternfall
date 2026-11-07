--!strict
-- Survivor rewards must observe the world before cleanup and combine with each recipient's own harvesting.
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
Run.setReady(me, true)
Run.setReady(peer, true)
world.advance(3.5)
XP.setPaused(true)
Enemy.killAll()

local function setHarvest(player, value)
	Stats.addStats(player, { harvesting = value - Stats.getStat(player, "harvesting") })
end
local function spawn(kind)
	return assert(Enemy.spawn(kind, 40, 40, 1, 1))
end
local function endWave()
	Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
	expect(Run.getPhase()).toBe("Shop")
end

describe("Native survivor rewards", function()
	it("pays different personal rewards for living enemies and trees before the world is cleared", function()
		setHarvest(me, 0)
		setHarvest(peer, 0)
		for _ = 1, 10 do
			spawn("Shadeling")
		end
		spawn("Tree")
		spawn("Tree")
		endWave()
		expect(Enemy.getCount()).toBe(0)
		expect(Shop.getShards(me)).toBe(7)
		expect(Shop.getShards(peer)).toBe(24)
		expect(XP.getProgress(me).xp).toBe(7)
		expect(XP.getLevel(peer)).toBe(2)
		expect(XP.getProgress(peer).xp).toBe(8)
	end)

	it("offsets negative harvesting before granting XP and does not leak rewards into the next wave", function()
		world.fireServerAs(me, "SetShopReady", true)
		world.fireServerAs(peer, "SetShopReady", true)
		world.advance(0.2)
		setHarvest(me, -10)
		setHarvest(peer, -5)
		local goldA, goldB = Shop.getShards(me), Shop.getShards(peer)
		local xpA, xpB = XP.getProgress(me).xp, XP.getProgress(peer).xp
		spawn("Shadeling")
		spawn("Shadeling")
		endWave()
		expect(Shop.getShards(me)).toBe(math.max(0, goldA - 9))
		expect(Shop.getShards(peer)).toBe(math.max(0, goldB - 5))
		expect(XP.getProgress(me).xp).toBe(xpA)
		expect(XP.getProgress(peer).xp).toBe(xpB)
	end)
end)
