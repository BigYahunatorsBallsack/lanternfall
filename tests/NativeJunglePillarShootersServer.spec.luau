--!strict
-- Actual registered normal Jungle shooters emit pillar fans with independent speed and source damage growth.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.StructureService).setPaused(true)
require(f.S.MapService).setMovementCheck(false)
require(f.S.CombatService).protect(f.me, 10000)
require(f.S.CombatService).protect(f.peer, 10000)
f.peer.Character.HumanoidRootPart.Position = Vector3.new(80, 100, 80)
describe("Registered normal Jungle pillar fans", function()
	for _, row in
		{
			{ "Hesperosaurus", 25, 12, 3, 50, 1 },
			{ "Stegosaurus", 50, 20, 5, 60, 2 },
		}
	do
		it("emits " .. row[1] .. " pillars with actual source speed and growth", function()
			Enemy.killAll()
			local root = f.me.Character.HumanoidRootPart
			local id = assert(Enemy.spawn(row[1], root.Position.X - 30, root.Position.Z, 2, 2, nil, nil, 0, 10))
			expect(Enemy.getMaxHealth(id)).toBeNear((row[2] + row[3] * 9) * 2)
			local _, damage = Enemy.getMultipliers(id)
			expect(damage).toBeNear((1 + 1.1 * 9) * 2)
			local at = assert(Enemy.getPosition(id))
			local hurt = assert(Enemy.getHurtGeometry(id))
			expect(hurt.Z - at.Z).toBeNear(-2.9)
			local shots = {}
			local slashCount = 0
			local connection = Enemy.NativePillar:Connect(function(source, x, z, dx, dz, speed, dmg, owner)
				if source == id then
					table.insert(shots, { x = x, z = z, dx = dx, dz = dz, speed = speed, damage = dmg, owner = owner })
				end
			end)
			local wrong = Enemy.NativeSlash:Connect(function(source)
				if source == id then
					slashCount += 1
				end
			end)
			f.world.advance(2.2, 1 / 60)
			connection:Disconnect()
			wrong:Disconnect()
			expect(#shots).toBe(row[4])
			expect(slashCount).toBe(0)
			for i, shot in shots do
				local angle = -0.6 + (i - 1) * (1.2 / (row[4] - 1))
				expect(shot.x).toBeNear(at.X)
				expect(shot.z).toBeNear(at.Z)
				expect(shot.dx).toBeNear(math.cos(angle))
				expect(shot.dz).toBeNear(math.sin(angle))
				expect(shot.speed).toBeNear(row[5] - (i - 1) * 3.5)
				expect(shot.damage).toBe((row[6] + 9) * 2)
				expect(shot.owner).toBe(nil)
			end
			expect(f.Run.getNativeZoneId()).toBe(0)
			expect(#f.world.errors).toBe(0)
		end)
	end
	it("routes a real Charm-converted Hesperosaurus fan through owned pillar attacks", function()
		Enemy.killAll()
		local id = assert(Enemy.spawn("Hesperosaurus", 60, 0, 1000, 1, nil, nil, 0, 10))
		local target = assert(Enemy.spawn("Brute", 20, 0, 1000, 0, nil, nil, 0, 10))
		assert(Enemy.charmSummoned(id, f.me.UserId))
		local shots = {}
		local connection = Enemy.NativePillar:Connect(function(source, x, z, dx, dz, speed, damage, owner)
			if source == id then
				table.insert(shots, { dx = dx, dz = dz, speed = speed, damage = damage, owner = owner })
			end
		end)
		f.world.advance(2.2, 1 / 60)
		connection:Disconnect()
		expect(#shots).toBe(3)
		for index, shot in shots do
			expect(shot.owner).toBe(f.me.UserId)
			expect(shot.damage).toBe(30)
			expect(shot.speed).toBeNear(50 - (index - 1) * 3.5)
			expect(shot.dx < 0).toBe(true)
		end
		expect(Enemy.isCharmed(id)).toBe(true)
		expect(Enemy.isAlive(target)).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
