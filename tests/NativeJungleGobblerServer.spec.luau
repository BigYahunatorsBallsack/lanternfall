--!strict
-- Actual Jungle Gobbler ignores speed modifiers, consumes authoritative gold objects, evolves and returns its source value through real loot services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local XP = require(f.S.ExperienceService)
local Random = require(f.S.RandomService)
local Kinds = require(f.Shared.Util.EnemyKinds)
local Economy = require(f.Shared.Util.CharacterEconomy)
local Snapshot = require(f.Shared.Net.Snapshot)
local stages = {}
local previousWatch = f.world.netWatch
f.world.netWatch = function(name, player, packet)
	if previousWatch then
		previousWatch(name, player, packet)
	end
	if name == "EnemySnapshot" and player == f.me then
		local columns = Snapshot.newColumns()
		local count = Snapshot.decodeInto(packet, columns, 1)
		for index = 1, count do
			stages[columns.ids[index]] = Snapshot.unpackPursuerStage(columns.statuses[index] or 0)
		end
	end
end
local function fresh()
	XP.setPaused(true)
	f.start("WatchmanPistol")
	f.Weapons.setPaused(true)
	require(f.S.StructureService).setPaused(true)
	require(f.S.MapService).setMovementCheck(false)
	for _, player in { f.me, f.peer } do
		require(f.S.CombatService).protect(player, 10000)
		player.Character.HumanoidRootPart.Position = Vector3.new(-80, 100, -70)
	end
	XP.setPaused(false)
end
local function lootRolls(action)
	local original = Random.number
	Random.number = function(name, player)
		return if name == "Loot" then 0.5 else original(name, player)
	end
	local ok, result = pcall(action)
	Random.number = original
	assert(ok, result)
	return result
end
describe("Registered Jungle Gobbler server", function()
	it("binds source fixed base speed, sensor offsets and ordinary Charm/boost exclusions", function()
		fresh()
		local kind = assert(Kinds.get("JungleGobbler"))
		expect(kind.typeId).toBe(68)
		expect(kind.speed).toBe(35)
		expect(kind.speedMax).toBe(35)
		expect(kind.nativeCanBeBoosted).toBe(false)
		expect(kind.loot.crate).toBe(nil)
		expect(kind.loot.consumableChance).toBe(0)
		expect(kind.nativeEater.material.attractRadiusPoints).toBe(100)
		expect(kind.nativeEater.material.pickupOffsetZPoints).toBe(-10)
		expect(require(f.Shared.Util.EnemyStats).spawnSpeedFactor(kind, 0, 0, 0.1)).toBe(1)
		expect(require(f.Shared.Util.EnemyStats).spawnSpeedFactor(kind, 1, 10, 5)).toBe(1)
		local id = assert(Enemy.spawn("JungleGobbler", 40, 30, 2, 2, nil, nil, 0, 10))
		expect(Enemy.getMaxHealth(id)).toBe(550)
		local _, contact, speed = Enemy.getMultipliers(id)
		expect(contact).toBe(17)
		expect(speed).toBe(1)
		Enemy.damage(id, 1, f.me)
		expect(Enemy.tryCharm(f.me, id, { charmChance = 1, charmThreshold = 1 }, function()
			error("Loot cannot roll Charm")
		end)).toBe(false)
	end)
	it("returns zero source material when killed empty, rather than adding the stats resource value8", function()
		fresh()
		local id = assert(Enemy.spawn("JungleGobbler", 40, 30, 1, 0, nil, nil, 0, 1))
		local value = -1
		local connection = Enemy.EnemyKilled:Connect(function(info)
			if info.id == id then
				value = info.xp
			end
		end)
		Enemy.damage(id, 1e9, f.me)
		connection:Disconnect()
		expect(value).toBe(0)
		expect(XP.getMaterialsOnFloor()).toBe(0)
	end)
	it("eats real material objects, doubles damaged HP at stage2 and returns separate capped gold objects", function()
		fresh()
		local id = assert(Enemy.spawn("JungleGobbler", 40, 30, 2, 1, nil, nil, 0, 10))
		Enemy.damage(id, 5, f.me)
		lootRolls(function()
			XP.dropMaterials(Vector3.new(40, 100, 30), 20, 0)
		end)
		local offered = XP.getMaterialsOnFloor()
		expect(offered >= 20).toBe(true)
		f.world.advance(1, 1 / 60)
		local gold, stage = Enemy.getNativeEater(id)
		expect(gold).toBe(offered)
		expect(stage).toBe(2)
		expect(stages[id]).toBe(2)
		expect(Enemy.getHealth(id)).toBe(1090)
		expect(Enemy.getMaxHealth(id)).toBe(1100)
		expect(XP.getMaterialsOnFloor()).toBe(0)
		local value = -1
		local connection = Enemy.EnemyKilled:Connect(function(info)
			if info.id == id then
				value = info.xp
			end
		end)
		lootRolls(function()
			Enemy.damage(id, 1e9, f.me)
		end)
		connection:Disconnect()
		expect(value).toBe(gold * 3)
		local classes = { f.Run.getParticipantClassId(f.me), f.Run.getParticipantClassId(f.peer) }
		local raw = Economy.materialValue(gold * 3, classes, true)
		local expected = math.floor(raw) + (if 0.5 <= raw - math.floor(raw) then 1 else 0)
		expect(XP.getMaterialsOnFloor()).toBe(expected)
		expect(XP.getOrbCount()).toBe(math.min(expected, f.Config.Run.xpOrbs.maxOrbs))
		expect(XP.getOrbCount() > 1).toBe(true)
		expect(f.Run.getNativeZoneId()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
