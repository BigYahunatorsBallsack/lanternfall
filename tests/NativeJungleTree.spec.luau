--!strict
-- Source neutral Jungle trees retain canonical tree identity, original stats, eighth-hit execution and normal kill listeners.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local Loot = require(f.Shared.Util.LootRules)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
local function tree(hp)
	return assert(Enemy.spawn("Tree", 20, 0, hp or 100, 1, nil, nil, 1, 1, Kinds.treeForZone(2).typeId))
end
describe("Native Jungle neutral tree", function()
	it("registers a distinct source type with the canonical Tree family and no ambient eligibility", function()
		local kind = Kinds.treeForZone(2)
		expect(kind.id).toBe("Tree")
		expect(kind.typeId).toBe(71)
		expect(Kinds.byTypeId(71)).toBe(kind)
		expect(Kinds.treeForZone(0)).toBe(Kinds.get("Tree"))
		expect(kind.specialSpawn).toBe(true)
		expect(kind.hp).toBe(10)
		expect(kind.hpPerWave).toBe(5)
		expect(kind.radius).toBeNear(2.4)
		expect(kind.hurtRadius).toBeNear(4.86621)
		expect(kind.nativeHurtOffsetZ).toBeNear(-3.8)
		expect(kind.hitRadius).toBe(0)
	end)
	it("creates source wave HP without changing the legacy Tree contract", function()
		local id = assert(Enemy.spawn("Tree", 20, 0, 1.125, 1, nil, nil, 1, 4, 71))
		expect(Enemy.getMaxHealth(id)).toBe(28)
		local old = assert(Enemy.spawn("Tree", 30, 0, 1, 0, nil, nil, 0, 4))
		expect(Enemy.getMaxHealth(old)).toBe(50) -- existing20+10*(4-1), unchanged
	end)
	it("uses actual run factors on the native tree constructor and preserves the default zone", function()
		local id = assert(Enemy.spawnNative("Tree", 20, 0, 2))
		expect(Enemy.getMaxHealth(id)).toBe(13) -- two-player HP factor1.3
		expect(Enemy.getKind(id)).toBe("Tree")
		expect(Enemy.spawnNative("Tree", 30, 0)).toBe(nil) -- default Crash tree not yet opted in
	end)
	it("dispatches the actual SpawnDirector tree through the current zone variant", function()
		local oldZone, oldSpawn = f.Run.getNativeZoneId, Enemy.spawnNative
		local called, typeId = 0, nil
		f.Run.getNativeZoneId = function()
			return 2
		end -- test the area binding without advertising a playable Jungle
		Enemy.spawnNative = function(...)
			local id = oldSpawn(...)
			if id then
				called += 1
				local connection
				connection = Enemy.EnemyKilled:Connect(function(info)
					if info.id == id then
						typeId = info.typeId
					end
				end)
				Enemy.damage(id, 10000, f.me)
				connection:Disconnect()
			end
			return id
		end
		local ok, result = pcall(require(f.S.SpawnDirector).spawnTree, Vector3.new(0, 0, 0))
		f.Run.getNativeZoneId, Enemy.spawnNative = oldZone, oldSpawn
		assert(ok, result)
		expect(result).toBe(true)
		expect(called).toBe(1)
		expect(typeId).toBe(71)
	end)
	it("keeps the extra snapshot type disjoint from ordinary, elite and boss types", function()
		local seen = {}
		for _, list in
			{ f.Config.Enemies.types, f.Config.Enemies.bosses, f.Config.Enemies.champions, f.Config.Enemies.zoneTrees }
		do
			for _, kind in list do
				assert(not seen[kind.typeId], `Duplicate type {kind.typeId}`)
				seen[kind.typeId] = true
			end
		end
		for _, kind in f.Config.Enemies.types do
			local elite = assert(Kinds.get(kind.id, true))
			assert(not seen[elite.typeId], `Duplicate elite type {elite.typeId}`)
			seen[elite.typeId] = true
		end
	end)
	it("builds the real client visual by the new snapshot type using the existing fallback art", function()
		local client = folderProxy("src/client", "Client")
		local models = require(client.Controllers.EnemyRenderer.SpriteModels)
		local visual = models.build(71)
		assert(visual.model and visual.sprite and visual.body)
		expect(models.artOf(Kinds.byTypeId(71)).image).toBe(models.artOf(Kinds.get("Tree")).image)
		visual.model:Destroy()
	end)
	it("counts every hit, executes on the eighth eligible hit and emits one canonical kill", function()
		local id, count, info = tree(), 0, nil
		local connection = Enemy.EnemyKilled:Connect(function(kill)
			if kill.id == id then
				count += 1
				info = kill
			end
		end)
		for _ = 1, 7 do
			expect(Enemy.damage(id, 1, f.me, nil, true)).toBe(false)
		end
		expect(Enemy.isAlive(id)).toBe(true)
		expect(Enemy.damage(id, 1, f.me, nil, true)).toBe(true)
		expect(count).toBe(1)
		expect(info.enemyId).toBe("Tree")
		expect(info.typeId).toBe(71)
		expect(info.xp).toBe(3)
		expect(Enemy.damage(id, 1, f.me, nil, true)).toBe(false)
		expect(count).toBe(1)
		connection:Disconnect()
	end)
	it("retains ineligible hitbox counts for the next hit without a hitbox", function()
		local id = tree()
		for _ = 1, 9 do
			expect(Enemy.damage(id, 1, nil, nil, false)).toBe(false)
		end
		expect(Enemy.damage(id, 1, nil, nil, true)).toBe(false)
		expect(Enemy.isAlive(id)).toBe(true)
		expect(Enemy.damage(id, 1, f.me)).toBe(true)
	end)
	it("routes real burning structure damage as a no-hitbox hit, without enabling Lumberjack execution", function()
		Enemy.setTreeHitRule(function()
			return true
		end)
		local id = tree()
		for _ = 1, 7 do
			expect(f.Weapons.structureHit(f.me, id, 1, "Burn")).toBe(false)
		end
		expect(f.Weapons.structureHit(f.me, id, 1, "Burn")).toBe(true)
		Enemy.setTreeHitRule(function()
			return false
		end)
	end)
	it("keeps hit counts per actor across compaction and permits normal lethal damage", function()
		local a, b = tree(), tree()
		for _ = 1, 7 do
			Enemy.damage(a, 1, f.me, nil, true)
		end
		Enemy.remove(a)
		f.world.advance(0.1)
		expect(Enemy.damage(b, 1, f.me, nil, true)).toBe(false)
		expect(Enemy.damage(b, 10000, f.me, nil, true)).toBe(true)
	end)
	it("uses the existing tree one-hit rule independently of the eight-hit threshold", function()
		Enemy.setTreeHitRule(function(player)
			return player == f.me
		end)
		local id = tree()
		expect(Enemy.damage(id, 1, f.me, nil, true)).toBe(true)
		Enemy.setTreeHitRule(function()
			return false
		end)
	end)
	it("shares existing tree loot, material and Charm/boost exclusions", function()
		local kind, id = Kinds.treeForZone(2), tree()
		expect(Loot.dropsOrb(kind, 99, 1)).toBe(true)
		expect(Loot.consumable(kind, 0, 0, 0.5, 0.1)).toBe("Crate")
		expect(Loot.consumable(kind, 0, 0, 0.5, 0.3)).toBe("Fruit")
		expect(Loot.dugCrate(kind, 100, 0, 0)).toBe(false)
		expect(Enemy.tryCharm(f.me, id, { charm = 100000 }, function()
			return 0
		end)).toBe(false)
		expect(kind.nativeCanBeBoosted).toBe(false)
	end)
end)
