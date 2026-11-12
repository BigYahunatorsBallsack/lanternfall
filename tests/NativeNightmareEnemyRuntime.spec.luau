--!strict
-- Source Nightmare descendants, independent counters and projectile-pet reactions execute through production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Random = require(f.S.RandomService)
local Feed = require(f.Shared.Net.ShotFeed)
local Sim = require(f.S.StructureService.Projectiles)
local Pets = require(f.Shared.Config.Pets)
f.start("WatchmanPistol")
local function clear()
	Sim.clear()
	Enemy.killAll()
	f.world.advance(0.1)
	Enemy.killAll()
end
describe("Native Nightmare enemy runtime", function()
	it("keeps the new families out of ordinary spawn eligibility", function()
		local Rules = require(f.Shared.Util.EnemyStats)
		for _, id in { "BloatedSpawner", "HornedFly", "HornedSpitter", "DireJunkie" } do
			expect(Rules.canSpawn(f.Config.Enemies.types[id], 20, 5)).toBe(false)
		end
		expect(Rules.canSpawn(f.Config.Enemies.types.HornedFly, 20, 6)).toBe(true)
		expect(Rules.canSpawn(f.Config.Enemies.types.DireJunkie, 20, 6)).toBe(false)
	end)
	it(
		"splits into five real Dire Junkies with the inherited spawn context and only the parent's kill credit",
		function()
			clear()
			local parent = assert(Enemy.spawn("BloatedSpawner", 0, 0, 2, 3, nil, nil, 0, 10))
			local kills = 0
			local connection = Enemy.EnemyKilled:Connect(function()
				kills += 1
			end)
			assert(Enemy.damage(parent, 1e9, f.me))
			connection:Disconnect()
			local ids = {}
			Enemy.collectIds(ids)
			expect(#ids).toBe(5)
			for _, id in ids do
				expect(Enemy.getKind(id)).toBe("DireJunkie")
				expect(Enemy.getMaxHealth(id)).toBe((15 + 8 * 9) * 2)
				local hp, damage, speed = Enemy.getMultipliers(id)
				expect(hp).toBeNear((15 + 8 * 9) * 2 / 15)
				expect(damage).toBeNear((1 + 0.85 * 9) * 3)
				expect(speed).toBe(0)
			end
			expect(kills).toBe(1)
		end
	)
	it("cleans up a live parent without spawning death children", function()
		clear()
		local id = assert(Enemy.spawn("BloatedSpawner", 0, 0, 1, 1, nil, nil, 0))
		expect(Enemy.remove(id)).toBe(true)
		expect(Enemy.getCount()).toBe(0)
	end)
	it("reacts only to ranged hits at the native fifty-percent threshold and emits independent directions", function()
		clear()
		local id = assert(Enemy.spawn("HornedFly", 20, 0, 100, 0, nil, nil, 0))
		local original = Random.number
		local draws = { 0.5, 0.1, 0.7, 0.5001 }
		local index = 0
		Random.number = function(name, player)
			if name == "Combat" then
				index += 1
				return draws[index] or 0.5
			end
			return original(name, player)
		end
		Enemy.retaliate(id, "Melee")
		expect(Enemy.getShotCount()).toBe(0)
		Enemy.retaliate(id, "Ranged")
		expect(Enemy.getShotCount()).toBe(2)
		Enemy.retaliate(id, "Ranged")
		expect(Enemy.getShotCount()).toBe(2)
		Random.number = original
		local shots = {}
		local connection = f.world.getRemote("EnemyShots").OnClientEvent:Connect(function(packet)
			for _, shot in Feed.decode(packet).fired do
				table.insert(shots, shot)
			end
		end)
		f.world.advance(0.1)
		connection:Disconnect()
		expect(#shots).toBe(2)
		expect(shots[1].dx).toBeNear(math.cos(0.1 * 2 * math.pi), 0.00001)
		expect(shots[2].dx).toBeNear(math.cos(0.7 * 2 * math.pi), 0.00001)
		expect(shots[1].x).toBeNear(20)
	end)
	it("passes projectile pet hits to the counter rule while excluding Bot-O-Mine structures", function()
		clear()
		local id = assert(Enemy.spawn("HornedFly", 20, 0, 100, 0, nil, nil, 0))
		local original = Enemy.retaliate
		local calls = 0
		Enemy.retaliate = function(target, kind)
			expect(target).toBe(id)
			expect(kind).toBe("Ranged")
			calls += 1
		end
		local at = Vector3.new(0, f.Config.Map.arena.center.Y, 0)
		Sim.launchPet(f.me, at, Pets.kinds.CatlingGun.weapon, {}, { Vector3.new(1, 0, 0) }, false)
		Sim.step(0.2)
		expect(calls).toBe(1)
		Sim.clear()
		Sim.launchPet(f.me, at, Pets.kinds.BotOMine.weapon, {}, { Vector3.new(1, 0, 0) }, false)
		Sim.step(0.2)
		expect(calls).toBe(1)
		Enemy.retaliate = original
	end)
	it("preserves Charm ownership for all five descendants when the charmed parent's lifetime ends", function()
		clear()
		local id = assert(Enemy.spawn("BloatedSpawner", 0, 0, 100, 0, nil, nil, 0))
		Enemy.damage(id, 1, nil)
		expect(Enemy.tryCharm(f.me, id, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end)).toBe(true)
		expect(Enemy.getCharmedCount(f.me.UserId)).toBe(1)
		f.world.advance(require(f.Shared.Config.Charm).duration + 0.1)
		expect(Enemy.getCharmedCount(f.me.UserId)).toBe(5)
		expect(Enemy.getCharmedCount(f.peer.UserId)).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
