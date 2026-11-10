--!strict
-- Server integration of original enemy/HP units, offspring, counter-shots and one-wave lure encounters.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local Services = Server.Services
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local RunSchedule = require(Shared.Util.RunSchedule)
local RunDirector = require(Services.RunDirector)
local EnemySim = require(Services.EnemySim)
local SpawnDirector = require(Services.SpawnDirector)
local WeaponService = require(Services.WeaponService)
local CombatService = require(Services.CombatService)
local StatService = require(Services.StatService)
local RandomService = require(Services.RandomService)
local LootService = require(Services.LootService)

local me = world.addPlayer("Owner", 1, true)
world.step()

local function idsOf(kind: string): { number }
	local ids, found = {}, {}
	for i = 1, EnemySim.collectIds(ids) do
		if EnemySim.getKind(ids[i]) == kind then
			table.insert(found, ids[i])
		end
	end
	return found
end

local function clear()
	EnemySim.killAll()
	world.advance(0.2)
end

local function nextWave()
	RunDirector.skipTo(RunSchedule.wave(RunDirector.getWave()).endsAt)
	world.advance(0.1)
	expect(RunDirector.getPhase()).toBe("Shop")
	world.fireServerAs(me, "SetShopReady", true)
	world.advance(0.3)
	expect(RunDirector.getPhase()).toBe("Running")
	CombatService.protect(me, 1000)
end

-- Runs spawning from the wave's start past the lure group's time (waves are held) and its red crosses.
local function lureSecondsIn()
	RunDirector.skipTo(RunSchedule.wave(RunDirector.getWave()).startsAt)
	SpawnDirector.setPaused(false)
	RunDirector.skipTo(RunSchedule.wave(RunDirector.getWave()).startsAt + Config.Effects.lure.timing + 0.1)
	world.advance(Config.Run.spawn.markerSeconds + 1) -- the queue lets one enemy out every 3 frames
	SpawnDirector.setPaused(true)
end

describe("main-game enemy runtime", function()
	it("starts Night Watch with 10 HP on the original scale", function()
		RandomService.setNextSeed(123456)
		world.fireServerAs(me, "SetReady", true)
		world.advance(3.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		WeaponService.setPaused(true)
		RunDirector.setHoldWaves(true)
		LootService.setDropsPaused(true)
		CombatService.protect(me, 1000)
		expect(CombatService.getHp(me)).toBe(10)
		clear()
	end)

	it("gives a late spawner's children their own wave stats", function()
		local id = EnemySim.spawn("Splitter", 60, 60, 1.4, 1.4, nil, nil, 1, 14)
		expect(EnemySim.getHealth(id)).toBeNear((10 + 13) * 1.4)
		EnemySim.damage(id, 1e6)
		local children = idsOf("Skulker")
		expect(#children).toBe(3)
		for _, child in children do
			expect(EnemySim.getHealth(child)).toBeNear((5 + 13 * 4) * 1.4) -- junkie_stats: 5 + 4 per wave
		end
		clear()
	end)

	it("delivers separate wave-11 contact and projectile damage through the real simulation", function()
		local root = me.Character.HumanoidRootPart.Position
		local contact, shot = 0, 0
		local a = EnemySim.Contact:Connect(function(_, amount)
			contact = amount
		end)
		local b = EnemySim.ShotHit:Connect(function(_, amount)
			shot = amount
		end)
		EnemySim.spawn("Spitter", root.X + 1, root.Z, 1, 1, nil, nil, 0, 11)
		world.advance(3)
		a:Disconnect()
		b:Disconnect()
		expect(contact).toBeNear(7)
		expect(shot).toBeNear(8.5)
		clear()
	end)

	it("hatches one slasher with its own wave stats instead of four small chasers", function()
		EnemySim.spawn("BroodEgg", 60, 60, 1, 1, nil, nil, 1, 11)
		world.advance(5.8) -- slasher_egg: 4 s, then half of its 1 s shoot animation (hatching at 0.8 s of it)
		expect(#idsOf("BroodEgg")).toBe(0)
		local children = idsOf("Reaper")
		expect(#children).toBe(1)
		expect(EnemySim.getHealth(children[1])).toBe(300)
		clear()
	end)

	it("counter-fires only for surviving ranged weapon hits at 25% chance", function()
		local id = EnemySim.spawn("Thornback", 60, 60, 1, 1, nil, nil, 1, 11)
		local original = RandomService.number
		RandomService.number = function()
			return 0.24
		end
		local before = EnemySim.getShotCount()
		EnemySim.damage(id, 1)
		EnemySim.retaliate(id, "Melee")
		expect(EnemySim.getShotCount()).toBe(before)
		EnemySim.retaliate(id, "Ranged")
		expect(EnemySim.getShotCount()).toBe(before + Config.Enemies.types.Thornback.retaliate.count)
		RandomService.number = function()
			return 0.25
		end
		EnemySim.retaliate(id, "Ranged")
		expect(EnemySim.getShotCount()).toBe(before + Config.Enemies.types.Thornback.retaliate.count)
		EnemySim.damage(id, 1e6)
		RandomService.number = function()
			return 0
		end
		EnemySim.retaliate(id, "Ranged")
		expect(EnemySim.getShotCount()).toBe(before + Config.Enemies.types.Thornback.retaliate.count)
		RandomService.number = original
		clear()
	end)

	it("fires side projectiles during a Hookfang charge", function()
		local root = me.Character.HumanoidRootPart.Position
		EnemySim.spawn("Hookfang", root.X + 20, root.Z, 1, 1, nil, nil, 1, 1)
		local sawShots = false
		for _ = 1, 30 do
			world.advance(0.1)
			sawShots = sawShots or EnemySim.getShotCount() > 0
		end
		expect(sawShots).toBe(true) -- faster shots can already have reached their range by the end
		clear()
	end)

	it("rolls the rare Gobbler once at ten seconds, rather than in recurring groups", function()
		local original = RandomService.number
		RandomService.number = function()
			return 0.02
		end
		RunDirector.skipTo(10)
		SpawnDirector.setPaused(false)
		world.advance(Config.Run.spawn.markerSeconds + 0.2) -- Brotato shows the red cross for a second first
		expect(#idsOf("Gobbler")).toBe(1)
		RunDirector.skipTo(12)
		world.advance(Config.Run.spawn.markerSeconds + 0.2)
		expect(#idsOf("Gobbler")).toBe(1)
		SpawnDirector.setPaused(true)
		RandomService.number = original
		clear()
	end)

	it("spawns 7-8 lure enemies once on the next wave, and restores that encounter on retry", function()
		RunDirector.skipTo(RunSchedule.wave(1).endsAt)
		world.advance(0.1)
		expect(StatService.addItem(me, "BloodLure")).toBe(true)
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.1)
		CombatService.protect(me, 1000)
		lureSecondsIn()
		local count = #idsOf("Hookfang")
		expect(count >= 7 and count <= 8).toBe(true)
		RunDirector.setParticipantState(me, "Down")
		world.advance(0.1)
		expect(RunDirector.getPhase()).toBe("Ended")
		expect(RunDirector.retryWave(me)).toBe(true)
		CombatService.protect(me, 1000)
		lureSecondsIn()
		count = #idsOf("Hookfang")
		expect(count >= 7 and count <= 8).toBe(true)
		clear()
		nextWave()
		lureSecondsIn()
		expect(#idsOf("Hookfang")).toBe(0)
	end)

	it("has no server runtime errors", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n"))
		end
	end)
end)
