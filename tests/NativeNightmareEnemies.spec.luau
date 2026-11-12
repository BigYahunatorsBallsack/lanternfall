--!strict
-- Implemented Nightmare enemy families use source stats and native multi-projectile animation timing; pending families are absent.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.NightmareEnemies)
local Kinds = require(Shared.Util.EnemyKinds)
local Stats = require(Shared.Util.EnemyStats)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local function newWorld()
	local S = Config.Simulation
	return World.new({
		cellSize = S.spatialHashCellSize,
		maxEnemies = 200,
		playerRadius = S.playerRadius,
		contactMargin = S.contactMargin,
		separationStiffness = S.separationStiffness,
		separationPasses = S.separationPasses,
		obstacleSteerMargin = S.obstacleSteerMargin,
		keepDistanceTolerance = S.keepDistanceTolerance,
		minX = -100,
		maxX = 100,
		minZ = -100,
		maxZ = 100,
		obstacles = {},
	})
end
local function shoot(id)
	local world = newWorld()
	local kind = table.clone(Kinds.get(id))
	kind.speed = 0
	kind.speedMax = 0
	kind.wander = nil
	kind.stayInRange = nil
	kind.anchored = true
	local actor = world:spawn(kind, 0, 0, kind.hp, kind.contactDamage, kind.ranged.projectileDamage)
	local count = 0
	local first = 0
	for frame = 1, 240 do
		world:step(1 / 60, { 20 }, { 0 }, 1)
		if world.shotCount > 0 then
			if first == 0 then
				first = frame / 60
			end
			expect(world.shotCount).toBe(kind.ranged.projectileCount)
			count += world.shotCount
		end
	end
	return world, actor, first, count
end
describe("Native Nightmare enemy families", function()
	it("activates all seven source families with distinct type ids and no source-only pending families", function()
		local seen = {}
		for _, id in C.implemented do
			local kind = Kinds.get(id)
			expect(kind ~= nil).toBe(true)
			expect(kind.minDanger).toBe(6)
			expect(seen[kind.typeId]).toBe(nil)
			seen[kind.typeId] = true
			expect(Kinds.byTypeId(kind.typeId).id).toBe(id)
			local f = C.enemies[id].stats
			expect(kind.hp).toBe(f.health)
			expect(kind.hpPerWave).toBe(f.health_increase_each_wave)
			expect(kind.damagePerWave).toBe(f.damage_increase_each_wave)
		end
		for _, id in C.pending do
			expect(Kinds.get(id)).toBe(nil)
		end
	end)
	it("uses five Dire Junkies and original material/drop rules instead of normal Junkies", function()
		local parent = Kinds.get("BloatedSpawner")
		local child = Kinds.get("DireJunkie")
		expect(parent.split.enemy).toBe("DireJunkie")
		expect(parent.split.count).toBe(5)
		expect(child.hp).toBe(15)
		expect(child.hpPerWave).toBe(8)
		expect(child.loot.consumableChance).toBe(0)
		expect(child.xp).toBe(1)
	end)
	it("fires two Dire Junkie projectiles after the full first cooldown plus its animation key", function()
		local _, _, first, count = shoot("DireJunkie")
		expect(first >= 2 - 1 / 6 + 0.4).toBe(true)
		expect(first <= 2 + 1 / 6 + 0.4 + 1 / 60).toBe(true)
		expect(count).toBe(2)
	end)
	it("fires three Horned Spitter projectiles and grows their damage independently of contact", function()
		local _, _, first, count = shoot("HornedSpitter")
		expect(first >= 80 / 60 - 1 / 6 + 0.8).toBe(true)
		expect(first <= 80 / 60 + 1 / 6 + 0.8 + 1 / 60).toBe(true)
		expect(count).toBe(3)
		local _, contact, shot = Stats.growth(Kinds.get("HornedSpitter"), 20)
		expect(contact).toBe(20)
		expect(shot).toBe(24.75)
	end)
	it("keeps source radius defaults and a fifty-percent independent two-shot ranged reaction", function()
		local fly = Kinds.get("HornedFly")
		expect(C.enemies.HornedFly.circles.body).toBe(10)
		expect(fly.speed).toBeNear(325 * Config.Player.moveSpeed / 450)
		expect(fly.retaliate.count).toBe(2)
		expect(fly.retaliate.chance).toBe(0.5)
		expect(fly.retaliate.rangedOnly).toBe(true)
		expect(fly.retaliate.randomDirections).toBe(true)
	end)
	it("transfers an in-progress native shooting animation to the charmed faction without restarting it", function()
		local source = newWorld()
		local target = newWorld()
		local kind = table.clone(Kinds.get("DireJunkie"))
		kind.anchored = true
		kind.wander = nil
		local id = source:spawn(kind, 0, 0, kind.hp, 1, 1)
		local index = source.indexOf[id]
		local clock = source.shootingClocks[index]
		clock.stage = "Animation"
		clock.age = 0.3
		clock.fired = false
		expect(source:transferTo(target, id)).toBe(true)
		local moved = target.shootingClocks[target.indexOf[id]]
		expect(moved.age).toBe(0.3)
		expect(moved.stage).toBe("Animation")
		target:step(0.11, { 20 }, { 0 }, 1)
		expect(target.shotCount).toBe(2)
	end)
end)
