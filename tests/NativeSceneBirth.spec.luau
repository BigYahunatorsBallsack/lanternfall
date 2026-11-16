--!strict
-- Source wave scene references create actual registered native actors; unknown/evolved/boss scenes never fall back to another family.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local Data = require(f.Shared.Config.NativeJungleWaveBindings)
local Groups = require(f.S.SpawnDirector.NativeWaveGroups)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
local function kill(id)
	local result
	local c = Enemy.EnemyKilled:Connect(function(info)
		if info.id == id then
			result = info
		end
	end)
	Enemy.damage(id, math.huge, f.me)
	c:Disconnect()
	return assert(result)
end
describe("Source scene-native actor births", function()
	it("resolves all explicitly registered Jungle bodies and the separate neutral/global actors", function()
		local walkers = require(f.Shared.Config.JungleWalkers)
		for _, name in walkers.implemented do
			local source = walkers.enemies[name].source
			expect(Kinds.byNativeScene(source)).toBe(Kinds.get(name))
		end
		expect(Kinds.byNativeScene(require(f.Shared.Config.NativeJungleTree).source)).toBe(Kinds.treeForZone(2))
		expect(Kinds.byNativeScene(require(f.Shared.Config.NativeSeaPig).source)).toBe(Kinds.get("SeaPig"))
	end)
	it("spawns the actual first Jungle wave's bound unit through the real group scheduler", function()
		local wave = Data.waves[1]
		local group = Data.groups[wave.properties.groups_data[1].resource]
		local state = Groups.new({ group }, wave.properties.wave_duration)
		local fired = Groups.step(state, wave.properties.wave_duration - 1.01, {
			difficulty = 0,
			elite = false,
			horde = false,
			treesStart = false,
		}, function(chance)
			return 0 <= chance
		end)
		expect(#fired).toBe(1)
		local unit = Data.units[fired[1].wave_units_data[1].resource]
		local id = assert(Enemy.spawnNativeScene(unit.properties.unit_scene.resource, 20, 0))
		expect(Enemy.getMaxHealth(id)).toBe(3) -- source2HP*actual two-player1.3, rounded
		expect(kill(id).enemyId).toBe("BabyTriceratops")
	end)
	it("keeps a source neutral Tree's actual snapshot kind and normal kill identity", function()
		local source = require(f.Shared.Config.NativeJungleTree).source
		local id = assert(Enemy.spawnNativeScene(source, 20, 0))
		expect(Enemy.getMaxHealth(id)).toBe(13)
		local info = kill(id)
		expect(info.enemyId).toBe("Tree")
		expect(info.typeId).toBe(71)
	end)
	it("binds the DLC Sea Pig source without confusing it with the current area's enemies", function()
		local source = require(f.Shared.Config.NativeSeaPig).source
		local id = assert(Enemy.spawnNativeScene(source, 20, 0))
		expect(Enemy.getMaxHealth(id)).toBe(39)
		expect(kill(id).enemyId).toBe("SeaPig")
	end)
	it("refuses absent, unported boss and explicit variant scenes before consuming spawn randomness", function()
		local random = require(f.S.RandomService)
		local old, calls, count = random.number, 0, Enemy.getCount()
		random.number = function(...)
			calls += 1
			return old(...)
		end
		local ok, message = pcall(function()
			for _, source in
				{
					"res://unknown.tscn",
					"res://entities/units/enemies/jungle/basic/velociraptor/velociraptor++.tscn",
					"res://entities/units/enemies/jungle/elites/therizinosaurus/therizinosaurus.tscn",
					"res://entities/units/enemies/jungle/bosses/brachiosaurus/brachiosaurus.tscn",
				}
			do
				expect(Kinds.byNativeScene(source)).toBe(nil)
				expect(Enemy.spawnNativeScene(source, 0, 0)).toBe(nil)
			end
		end)
		random.number = old
		assert(ok, message)
		expect(calls).toBe(0)
		expect(Enemy.getCount()).toBe(count)
	end)
	it("refuses even registered scenes outside an active run", function()
		f.Run.endRun("Abandoned")
		local count = Enemy.getCount()
		expect(Enemy.spawnNativeScene(require(f.Shared.Config.NativeJungleTree).source, 20, 0)).toBe(nil)
		expect(Enemy.getCount()).toBe(count)
	end)
end)
