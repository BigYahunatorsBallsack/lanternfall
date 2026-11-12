--!strict
-- Real Mad Slasher AI emits animated slash attacks; player/faction hits, parent deletion, cosmetics and lifecycle remain server-owned.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
runScript(folderProxy("src/client", "Client"), "init.client.luau")
local Enemy = require(f.S.EnemySim)
local Slashes = require(f.S.NativeSlashService)
local Client = require(folderProxy("src/client", "Client").Controllers.NativeSlashController)
local Random = require(f.S.RandomService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
for _, p in { f.me, f.peer } do
	require(f.S.CombatService).protect(p, 1000)
end
f.peer.Character.HumanoidRootPart.Position = Vector3.new(90, 100, 60)
local function clear()
	Enemy.killAll()
	f.world.advance(0.1)
end
local function target()
	return Enemy.getPlayerPosition(f.me)
end
local function force(id, at, damage, owner)
	local original = Random.number
	Random.number = function(name, player)
		if name == "Combat" then
			return 0.5
		end
		return original(name, player)
	end
	Enemy.NativeSlash:Fire(id, at.X, at.Z, damage, owner)
	Random.number = original
end
describe("Native Mad Slasher runtime", function()
	it(
		"fires two slashes from production AI after the initial delay, full cooldown and preparation animation",
		function()
			clear()
			local at = target()
			Enemy.spawn("MadSlasher", at.X + 10, at.Z, 100, 1, nil, nil, 0, 1)
			local fired = {}
			local connection = f.world.getRemote("NativeSlashes").OnClientEvent:Connect(function(batch)
				for _, shot in batch.fired do
					table.insert(fired, shot)
				end
			end)
			f.world.advance(1.9, 1 / 60)
			expect(#fired).toBe(0)
			f.world.advance(0.5, 1 / 60)
			connection:Disconnect()
			expect(#fired).toBe(2)
			expect(fired[1].sourceId).toBe(fired[2].sourceId)
			expect(fired[1].x ~= fired[2].x or fired[1].z ~= fired[2].z).toBe(true)
			expect(#f.world.errors).toBe(0)
		end
	)
	it("cannot hurt before0.48 and stops each slash after its first player hit", function()
		clear()
		local at = target()
		local id = assert(Enemy.spawn("MadSlasher", at.X + 20, at.Z, 100, 0, nil, nil, 0, 1))
		local hits = 0
		local connection = Enemy.ShotHit:Connect(function(player, damage)
			expect(player).toBe(f.me)
			expect(damage).toBe(8)
			hits += 1
		end)
		force(id, at, 8, nil)
		f.world.advance(0.46, 1 / 60)
		expect(hits).toBe(0)
		expect(Client.getCount()).toBe(2)
		f.world.advance(0.12, 1 / 60)
		expect(hits).toBe(2)
		expect(Slashes.getCount()).toBe(0)
		expect(Client.getCount()).toBe(0)
		connection:Disconnect()
	end)
	it("deletes in-flight slashes when their parent dies before activation", function()
		clear()
		local at = target()
		local id = assert(Enemy.spawn("MadSlasher", at.X + 20, at.Z, 100, 0, nil, nil, 0, 1))
		force(id, at, 8, nil)
		f.world.advance(0.1)
		expect(Slashes.getCount()).toBe(2)
		Enemy.damage(id, 1e9, f.me)
		f.world.advance(0.1)
		expect(Slashes.getCount()).toBe(0)
		expect(Client.getCount()).toBe(0)
	end)
	it("routes owned slashes to hostile enemies and renders the owned path without player damage", function()
		clear()
		local at = target()
		local id = assert(Enemy.spawn("MadSlasher", at.X, at.Z, 100, 0, nil, nil, 0, 1))
		Enemy.damage(id, 1, nil)
		assert(Enemy.tryCharm(f.me, id, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end))
		local victim = assert(Enemy.spawn("Brute", at.X + 30, at.Z, 100, 0, nil, nil, 0, 1))
		local hp = Enemy.getHealth(victim)
		local hits = 0
		local connection = Enemy.ShotHit:Connect(function()
			hits += 1
		end)
		force(id, Enemy.getPosition(victim), 3, f.me.UserId)
		f.world.advance(0.2, 1 / 60)
		expect(Client.getCount()).toBe(2)
		f.world.advance(0.4, 1 / 60)
		expect(Enemy.getHealth(victim)).toBe(hp - 6)
		expect(hits).toBe(0)
		connection:Disconnect()
		expect(#f.world.errors).toBe(0)
	end)
	it("clears all server/client attack state at run end", function()
		f.Run.endRun("Abandoned")
		f.world.advance(0.1)
		expect(Slashes.getCount()).toBe(0)
		expect(Client.getCount()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
