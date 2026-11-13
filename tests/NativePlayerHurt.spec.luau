--!strict
-- Incoming player damage uses native translated hurt circles while AI and compensated origin APIs keep their positions.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Map = require(f.S.MapService)
f.start("WatchmanPistol")
require(f.S.CombatService).protect(f.me, 10000)
Map.setMovementCheck(false)
local root = f.me.Character.HumanoidRootPart
f.peer.Character.HumanoidRootPart.Position = Vector3.new(-80, 100, 80)
root.Position = Vector3.new(20, 100, 20)
local hits = {}
Enemy.ShotHit:Connect(function(player, damage)
	if player == f.me then
		table.insert(hits, damage)
	end
end)
describe("Native player hurt circles", function()
	it("keeps current and compensated hurt centers separate from aiming origins", function()
		root.AssemblyLinearVelocity = Vector3.new(10, 0, 0)
		f.world.advance(0.1)
		local origin = assert(Enemy.getPlayerPosition(f.me))
		local hurt, radius = Enemy.getPlayerHurtGeometry(f.me)
		local current = Enemy.getPlayerHurtGeometry(f.me, false)
		expect(origin.X).toBeNear(21.5)
		expect(origin.Z).toBeNear(20)
		expect(hurt.X).toBeNear(origin.X)
		expect(hurt.Z).toBeNear(18.8)
		expect(radius).toBeNear(2.1)
		expect(current.X).toBeNear(20)
		expect(current.Z).toBeNear(18.8)
		expect(Enemy.getPlayerHurtGeometry(f.world.addPlayer("Spectator", 9, false))).toBe(nil)
		root.AssemblyLinearVelocity = Vector3.zero
	end)
	it("hits the native hurt edge with ordinary enemy shots and misses the old opposite edge", function()
		root.AssemblyLinearVelocity = Vector3.zero
		f.world.advance(0.1)
		table.clear(hits)
		Enemy.fireShot(20, 18.8 - 2.1 - 0.2 + 0.05, 1, 0, 0, 100, 0.2, 7)
		f.world.advance(0.1)
		expect(#hits).toBe(1)
		expect(hits[1]).toBe(7)
		Enemy.fireShot(20, 20 + 2.1 + 0.2 - 0.05, 1, 0, 0, 100, 0.2, 9)
		f.world.advance(0.1)
		expect(#hits).toBe(1)
	end)
	it("uses the current hurt circle for a hostile pillar after its source disappears", function()
		Enemy.killAll()
		table.clear(hits)
		local c = require(f.Shared.Config.JungleWalkers).shootingRules.pillar
		local pixel = f.Config.Stats.range.studsPerPoint
		local z = 18.8 - 2.1 - c.radiusPoints * pixel + 0.05
		local source = assert(Enemy.spawn("Enigmacursor", 70, 70, 1000, 0, nil, nil, 0, 1))
		Enemy.NativePillar:Fire(source, 20 - c.offsetPoints[1] * pixel, z - c.offsetPoints[2] * pixel, 1, 0, 0, 11)
		Enemy.remove(source)
		f.world.advance(0.62, 1 / 60)
		expect(#hits).toBe(1)
		expect(hits[1]).toBe(11)
	end)
	it("uses translated player circles for real hostile slash animation", function()
		Enemy.killAll()
		table.clear(hits)
		local Geometry = require(f.Shared.Util.NativeSlashGeometry)
		local c = require(f.Shared.Config.NightmareEnemies)
		local pixel = f.Config.Stats.range.studsPerPoint
		local info = { x = 0, z = 0, dx = 1, dz = 0, speed = c.enemies.MadSlasher.attack.projectile_speed * pixel }
		local edge, cx = -math.huge, 0
		for frame = math.ceil(c.slash.hitFrom * 60), math.ceil(c.slash.hitUntil * 60) - 1 do
			local x, z, _, hz = Geometry.rectangle(info, frame / 60, pixel)
			if z + hz > edge then
				edge, cx = z + hz, x
			end
		end
		local targetZ = edge + 2.1 - 0.05 + 1.2
		root.Position = Vector3.new(cx, 100, targetZ)
		for frame = math.ceil(c.slash.hitFrom * 60), math.ceil(c.slash.hitUntil * 60) - 1 do
			expect(Geometry.contains(info, frame / 60, cx, targetZ, 2.1, pixel)).toBe(false)
		end
		local source = assert(Enemy.spawn("MadSlasher", 70, 70, 1000, 0, nil, nil, 0, 1))
		local Random = require(f.S.RandomService)
		local old = Random.number
		Random.number = function(stream, player)
			return if stream == "Combat" then 0.5 else old(stream, player)
		end
		local ok, err = pcall(function()
			Enemy.NativeSlash:Fire(source, 0, 0, 13)
		end)
		Random.number = old
		assert(ok, err)
		f.world.advance(0.62, 1 / 60)
		expect(#hits).toBe(2)
		expect(hits[1]).toBe(13)
		expect(hits[2]).toBe(13)
		Enemy.killAll()
		root.Position = Vector3.new(20, 100, 20)
	end)
	it("uses the player hurt translation for real outgoing enemy contact circles", function()
		local contacts = {}
		local connection = Enemy.Contact:Connect(function(player, damage)
			if player == f.me then
				table.insert(contacts, damage)
			end
		end)
		local k = assert(require(f.Shared.Util.EnemyKinds).get("BabyTriceratops"))
		local distance = k.hitRadius + 2.1 + f.Config.Simulation.contactMargin - 0.05
		local id = assert(Enemy.spawn("BabyTriceratops", 20, 18.8 - distance, 1000, 1, nil, nil, 0, 1))
		f.world.advance(0.1)
		expect(#contacts > 0).toBe(true)
		Enemy.teleport(id, Vector3.new(20, 100, 20 + distance))
		table.clear(contacts)
		f.world.advance(0.1)
		expect(#contacts).toBe(0)
		connection:Disconnect()
		expect(#f.world.errors).toBe(0)
	end)
end)
