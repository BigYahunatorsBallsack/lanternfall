--!strict
-- Source-backed Jungle pursuit bodies run in the production enemy simulation; this does not expose a Jungle area.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local EnemyStats = require(f.Shared.Util.EnemyStats)
local Kinds = require(f.Shared.Util.EnemyKinds)
local Spawn = require(f.S.SpawnDirector.SpawnRules)
local Models = require(folderProxy("src/client", "Client").Controllers.EnemyRenderer.SpriteModels)
local names = { "BabyTriceratops", "Gallimimus", "Lystrosaurus", "Pyroraptor" }
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.ExperienceService).setPaused(true)
require(f.S.MapService).setMovementCheck(false)
require(f.S.CombatService).protect(f.me, 10000)
require(f.S.CombatService).protect(f.peer, 10000)
f.peer.Character.HumanoidRootPart.Position = Vector3.new(-80, 100, -65)
describe("Native Jungle pursuit enemies", function()
	it(
		"keeps their native zone restriction out of ordinary Crash eligibility and preserves snapshot identities",
		function()
			for _, name in names do
				local kind = assert(Kinds.get(name))
				expect(kind.nativeZoneId).toBe(2)
				expect(EnemyStats.canSpawn(kind, 1, 0)).toBe(false)
				expect(EnemyStats.canSpawn(kind, 1, 0, 0)).toBe(false)
				expect(EnemyStats.canSpawn(kind, 1, 0, 2)).toBe(true)
				expect(Kinds.byTypeId(kind.typeId).id).toBe(name)
				for _, group in Spawn.groupsFor(1, 0) do
					for _, unit in group.units do
						expect(unit.enemy == name).toBe(false)
					end
				end
			end
		end
	)
	it("uses original units, independent per-wave growth and native collision radii", function()
		local health = { 2, 4, 3, 4 }
		local gain = { 2, 2.5, 3, 5 }
		local speed = { 20, 25, 17.5, 35 }
		for index, name in names do
			Enemy.killAll()
			local kind = assert(Kinds.get(name))
			expect(kind.hp).toBe(health[index])
			expect((kind.speed + kind.speedMax) / 2).toBeNear(speed[index])
			expect(kind.hurtRadius).toBeNear(3.2)
			expect(kind.hitRadius).toBeNear(1.60312)
			local id = assert(Enemy.spawn(name, 40, 0, 2, 3, nil, nil, 0, 10))
			expect(Enemy.getMaxHealth(id)).toBeNear((health[index] + gain[index] * 9) * 2)
			local _, damage = Enemy.getMultipliers(id)
			expect(damage).toBeNear((1 + 0.6 * 9) * 3)
		end
	end)
	it("moves every family towards a real player and credits only actual personal kills", function()
		for _, name in names do
			Enemy.killAll()
			local at = f.me.Character.HumanoidRootPart.Position
			local id = assert(Enemy.spawn(name, at.X + 40, at.Z, 100, 0, nil, nil, 1))
			local before = (Enemy.getPosition(id) - at).Magnitude
			f.world.advance(0.3, 1 / 60)
			expect((Enemy.getPosition(id) - at).Magnitude < before).toBe(true)
			local count = f.Data.get(f.me).nativeCounts.enemiesKilled
			assert(Enemy.damage(id, 1e9, f.me))
			expect(f.Data.get(f.me).nativeCounts.enemiesKilled).toBe(count + 1)
		end
		expect(#f.world.errors).toBe(0)
	end)
	it("uses visible declared fallback art while original Jungle images stay pending", function()
		for _, name in names do
			local kind = assert(Kinds.get(name))
			expect(kind.nativeArtPending).toBe(true)
			local art = Models.artOf(kind)
			expect(art.image).toBe(f.Config.Sprites.enemyImages[kind.look].image)
			expect(Models.build(kind.typeId).sprite.picture.Image).toBe(art.image)
		end
		expect(f.Run.getNativeZoneId()).toBe(0)
	end)
end)
