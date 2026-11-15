--!strict
-- Registered Dilophosaurus emits real scaled pillar triples with native offsets/cadence and owner routing.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.StructureService).setPaused(true)
require(f.S.MapService).setMovementCheck(false)
for _, player in { f.me, f.peer } do
	require(f.S.CombatService).protect(player, 10000)
end
f.peer.Character.HumanoidRootPart.Position = Vector3.new(80, 100, 80)
local function clear()
	Enemy.killAll()
	f.world.advance(1.1)
end
local function watch(id)
	local shots = {}
	local connection = Enemy.NativePillar:Connect(function(source, x, z, dx, dz, speed, damage, owner, scale)
		if source ~= id then
			return
		end
		local at = assert(Enemy.getPosition(id))
		table.insert(shots, {
			offsetX = x - at.X,
			offsetZ = z - at.Z,
			dx = dx,
			dz = dz,
			speed = speed,
			damage = damage,
			owner = owner,
			scale = scale,
		})
	end)
	return shots, connection
end
describe("Registered normal Dilophosaurus server", function()
	it("fires three scaled triples before the long pause with actual source transform and damage growth", function()
		clear()
		local root = f.me.Character.HumanoidRootPart
		local id =
			assert(Enemy.spawn("Dilophosaurus", root.Position.X - 30, root.Position.Z + 3, 1000, 2, nil, nil, 0, 10))
		expect(Enemy.getMaxHealth(id)).toBeNear((5 + 7 * 9) * 1000)
		local _, damage = Enemy.getMultipliers(id)
		expect(damage).toBeNear((1 + 1.1 * 9) * 2)
		local at = assert(Enemy.getPosition(id))
		local hurt = assert(Enemy.getHurtGeometry(id))
		expect(hurt.Z - at.Z).toBeNear(-3.1)
		local shots, connection = watch(id)
		f.world.advance(1.2, 1 / 60)
		expect(#shots).toBe(9)
		for index, shot in shots do
			local part = (index - 1) % 3
			expect(shot.offsetX).toBeNear(2)
			expect(shot.offsetZ).toBeNear(-3)
			expect(shot.speed).toBe(60 - part * 2)
			expect(shot.scale).toBeNear(if part == 1 then 1 else 0.7)
			expect(shot.damage).toBe(20)
			expect(shot.owner).toBe(nil)
		end
		f.world.advance(1.4, 1 / 60)
		expect(#shots).toBe(9)
		f.world.advance(1.2, 1 / 60)
		connection:Disconnect()
		expect(#shots > 9).toBe(true)
		expect(f.Run.getNativeZoneId()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
	it("retains scale and mirrored muzzle offsets through actual Charm conversion", function()
		clear()
		local id = assert(Enemy.spawn("Dilophosaurus", 60, 3, 1000, 1, nil, nil, 0, 10))
		assert(Enemy.spawn("Brute", 20, 0, 1000, 0, nil, nil, 0, 10))
		assert(Enemy.charmSummoned(id, f.me.UserId))
		local shots, connection = watch(id)
		f.world.advance(1.2, 1 / 60)
		connection:Disconnect()
		expect(#shots).toBe(9)
		for index, shot in shots do
			local part = (index - 1) % 3
			expect(shot.owner).toBe(f.me.UserId)
			expect(shot.damage).toBe(30)
			expect(shot.offsetX).toBeNear(-2)
			expect(shot.offsetZ).toBeNear(-3)
			expect(shot.speed).toBe(60 - part * 2)
			expect(shot.scale).toBeNear(if part == 1 then 1 else 0.7)
		end
		expect(Enemy.isCharmed(id)).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
