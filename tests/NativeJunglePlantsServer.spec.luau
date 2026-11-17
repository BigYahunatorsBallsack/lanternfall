--!strict
-- Actual plant actors emit world-aligned bullets and take source flat armor damage; Charm retains their cardinal spread.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.StructureService).setPaused(true)
require(f.S.MapService).setMovementCheck(false)
require(f.S.CombatService).protect(f.me, 10000)
require(f.S.CombatService).protect(f.peer, 10000)
f.peer.Character.HumanoidRootPart.Position = Vector3.new(80, 100, 80)
describe("Registered normal Jungle plants", function()
	for _, row in
		{ { "CarnivorousPlant", 4, 7, 5, 2.2, 1, 0.1 }, { "CarnivorousPlantMother", 8, 35, 16, 1.6, 1.15, -2.7 } }
	do
		it("fires " .. row[1] .. " in world directions with independent source growth", function()
			Enemy.killAll()
			f.world.advance(1.1)
			local id = assert(Enemy.spawn(row[1], 40, 30, 2, 2, nil, nil, 0, 10))
			expect(Enemy.getMaxHealth(id)).toBe((row[3] + row[4] * 9) * 2)
			local at = assert(Enemy.getPosition(id))
			local hurt = assert(Enemy.getHurtGeometry(id))
			expect(hurt.X - at.X).toBeNear(0.1)
			expect(hurt.Z - at.Z).toBeNear(row[7])
			local shots = {}
			local original = Enemy.fireShot
			Enemy.fireShot = function(x, z, dx, dz, speed, range, radius, damage)
				table.insert(shots, { x, z, dx, dz, speed, range, radius, damage })
				return original(x, z, dx, dz, speed, range, radius, damage)
			end
			f.world.advance(row[5] + 0.65, 1 / 60)
			Enemy.fireShot = original
			expect(#shots).toBe(row[2])
			for index, shot in shots do
				local angle = (index - 1) * 2 * math.pi / row[2]
				expect(shot[1]).toBeNear(at.X)
				expect(shot[2]).toBeNear(at.Z - 7)
				expect(shot[3]).toBeNear(math.cos(angle))
				expect(shot[4]).toBeNear(math.sin(angle))
				expect(shot[5]).toBe(50)
				expect(shot[7]).toBeNear(1.70294)
				expect(shot[8]).toBe(24)
			end
			expect(Enemy.getPosition(id).X).toBeNear(at.X)
			expect(Enemy.getPosition(id).Z).toBeNear(at.Z)
			local _, contact = Enemy.getMultipliers(id)
			expect(contact).toBeNear(math.round((1 + row[6] * 9) * 2))
			expect(f.Run.getNativeZoneId()).toBe(0)
			expect(#f.world.errors).toBe(0)
		end)
	end
	it("subtracts flat armor on normal hits and bypasses it for actual structure burns", function()
		Enemy.killAll()
		local id = assert(Enemy.spawn("CarnivorousPlantMother", 40, 30, 1, 0, nil, nil, 0, 10))
		local before = Enemy.getHealth(id)
		local _, dealt = Enemy.damage(id, 10, f.me)
		expect(dealt).toBe(5)
		f.Weapons.structureHit(f.me, id, 10, "Burn")
		expect(Enemy.getHealth(id)).toBe(before - 15)
	end)
	it("bypasses armor through the actual weapon burn queue while ordinary shots stay out of range", function()
		Enemy.killAll()
		local id = assert(Enemy.spawn("CarnivorousPlantMother", -75, -70, 100, 0, nil, nil, 0, 10))
		local before = Enemy.getHealth(id)
		f.Weapons.burnEnemy(f.me, id, 2, {}, 1)
		f.Weapons.setPaused(false)
		f.world.advance(1.4, 1 / 60)
		f.Weapons.setPaused(true)
		expect(Enemy.getHealth(id)).toBe(before - 2)
	end)
	it("keeps all eight world directions through a real Charm conversion and damages a hostile", function()
		Enemy.killAll()
		f.world.advance(1.1)
		local id = assert(Enemy.spawn("CarnivorousPlantMother", 30, 20, 1000, 1, nil, nil, 0, 10))
		local target = assert(Enemy.spawn("Brute", 42, 15, 1000, 0, nil, nil, 0, 10))
		assert(Enemy.charmSummoned(id, f.me.UserId))
		local before = Enemy.getHealth(target)
		local shots = {}
		local connection = Enemy.CharmShot:Connect(function(owner, event)
			if event.kind == "CharmFire" then
				expect(owner).toBe(f.me.UserId)
				table.insert(shots, event)
			end
		end)
		f.world.advance(2.3, 1 / 60)
		connection:Disconnect()
		expect(#shots).toBe(8)
		for index, shot in shots do
			local angle = (index - 1) * math.pi / 4
			expect(shot.dx).toBeNear(math.cos(angle))
			expect(shot.dz).toBeNear(math.sin(angle))
			expect(shot.x).toBeNear(30)
			expect(shot.z).toBeNear(13)
		end
		expect(before - Enemy.getHealth(target)).toBe(35) -- round((1+1.2*9)*3), not round(11.8)*3
		expect(Enemy.isCharmed(id)).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
