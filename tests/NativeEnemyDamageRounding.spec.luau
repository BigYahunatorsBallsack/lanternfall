--!strict
-- Source-based bodies and shots round final enemy damage while retaining raw inputs for later resets and Charm.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Combat = require(f.S.CombatService)
require(f.S.RandomService).setNextSeed(1234)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.MapService).setMovementCheck(false)
for _, player in { f.me, f.peer } do
	Combat.protect(player, 1000)
end
local function clear()
	Enemy.killAll()
	f.world.advance(0.1)
	Enemy.killAll()
	f.me.Character.HumanoidRootPart.Position = Vector3.new(0, 100, 0)
	f.peer.Character.HumanoidRootPart.Position = Vector3.new(-80, 100, -80)
end
describe("Native initial enemy damage rounding", function()
	it("opts in all38 source-bound families without changing legacy rounding policy", function()
		local count = 0
		for _, kind in f.Config.Enemies.types do
			if kind.nativeHealthRounding then
				expect(kind.nativeDamageRounding).toBe(true)
				count += 1
			end
		end
		expect(count).toBe(38)
		expect(f.Config.Enemies.types.Shadeling.nativeDamageRounding).toBe(nil)
	end)
	it("rounds contact after fractional growth and global factors in the actual spawn adapter", function()
		clear()
		local id = assert(Enemy.spawn("Gallimimus", 2, 0, 100, 3, nil, nil, 0, 10))
		expect(select(2, Enemy.getMultipliers(id))).toBe(19) -- round((1+.6*9)*3), no early base rounding
	end)
	it("rounds actual hostile projectiles independently from contact damage", function()
		clear()
		local seen = {}
		local connection = Enemy.ShotHit:Connect(function(player, damage)
			if player == f.me then
				table.insert(seen, damage)
			end
		end)
		local id = assert(Enemy.spawn("HornedSpitter", 20, 0, 100, 1.4, nil, nil, 0, 3))
		f.world.advance(6, 1 / 60)
		connection:Disconnect()
		expect(select(2, Enemy.getMultipliers(id))).toBe(4) -- round((1+1*2)*1.4)
		expect(#seen > 0).toBe(true)
		for _, damage in seen do
			expect(damage).toBe(5)
		end -- round((1+1.25*2)*1.4)
	end)
	it("keeps raw native contact and projectile inputs for a later source stat reset", function()
		local World = require(f.S.EnemySim.World)
		local w = World.new({
			cellSize = 8,
			maxEnemies = 10,
			playerRadius = 1,
			contactMargin = 0,
			separationStiffness = 0,
			separationPasses = 0,
			obstacleSteerMargin = 0,
			keepDistanceTolerance = 0,
			minX = -100,
			maxX = 100,
			minZ = -100,
			maxZ = 100,
			obstacles = {},
		})
		local id = assert(w:spawn(f.Config.Enemies.types.HornedSpitter, 0, 0, 100, 21.2, 21.2, 0, 3))
		expect(w.contactDamage[w.indexOf[id]]).toBe(21)
		expect(w:getShotDamage(id)).toBe(21)
		local raw = assert(w:getSpawnStatBases(id))
		expect(raw.contact).toBe(21.2)
		expect(raw.shot).toBe(21.2)
		assert(w:resetNativeStats(id, raw, { hp = 1, damage = 1.3, speed = 1 }))
		expect(w.contactDamage[w.indexOf[id]]).toBe(28)
		expect(w:getShotDamage(id)).toBe(28)
	end)
end)
