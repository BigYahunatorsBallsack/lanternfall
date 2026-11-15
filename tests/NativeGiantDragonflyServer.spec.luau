--!strict
-- Actual EnemySim/Charm connect the scene-bound Giant Dragonfly normal body and diagonal charge.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.MapService).setMovementCheck(false)
require(f.S.CombatService).protect(f.me, 10000)
require(f.S.CombatService).protect(f.peer, 10000)
f.peer.Character.HumanoidRootPart.Position = Vector3.new(-80, 100, 80)
describe("Normal GiantDragonfly service integration", function()
	it("spawns source stat growth and the actual translated hurt circle", function()
		Enemy.killAll()
		local id = assert(Enemy.spawn("GiantDragonfly", 40, 0, 2, 3, nil, nil, 0, 10))
		expect(Enemy.getMaxHealth(id)).toBeNear((4 + 2 * 9) * 2)
		local _, damage = Enemy.getMultipliers(id)
		expect(damage).toBeNear((1 + 0.85 * 9) * 3)
		local position = assert(Enemy.getPosition(id))
		local hurt, radius = Enemy.getHurtGeometry(id)
		expect(hurt.Z - position.Z).toBeNear(-3.4)
		expect(radius > 0).toBe(true)
	end)
	it("executes a real diagonal rush and preserves the active actor through actual charm conversion", function()
		Enemy.killAll()
		local root = f.me.Character.HumanoidRootPart
		local id =
			assert(Enemy.spawn("GiantDragonfly", root.Position.X - 20, root.Position.Z - 10, 1000, 0, nil, nil, 0))
		for _ = 1, 180 do
			f.world.step(1 / 60)
			local mode, dx, dz = Enemy.getMode(id)
			if mode == 2 and dx * dx + dz * dz > 0 then
				break
			end
		end
		local mode, dx, dz = Enemy.getMode(id)
		expect(mode).toBe(2)
		assert(
			dx > 0,
			"dx="
				.. tostring(dx)
				.. " dz="
				.. tostring(dz)
				.. " source="
				.. tostring(Enemy.getPosition(id))
				.. " target="
				.. tostring(root.Position)
		)
		assert(
			dz > 0,
			"dx="
				.. tostring(dx)
				.. " dz="
				.. tostring(dz)
				.. " source="
				.. tostring(Enemy.getPosition(id))
				.. " target="
				.. tostring(root.Position)
		)
		expect(Enemy.isProjectileDeflecting(id)).toBe(false)
		expect(Enemy.charmSummoned(id, f.me.UserId)).toBe(true)
		expect(Enemy.isCharmed(id)).toBe(true)
		f.world.step(0.1)
		expect(Enemy.getPosition(id) ~= nil).toBe(true)
		expect(#f.world.errors).toBe(0)
		expect(f.Run.getNativeZoneId()).toBe(0)
	end)
end)
