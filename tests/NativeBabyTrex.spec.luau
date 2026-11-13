--!strict
-- Native Baby T-Rex integrates flat boosts, rounded damage, separate collider growth and live-player speed caps.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local Kinds = require(game:GetService("ReplicatedStorage").Shared.Util.EnemyKinds)
local C = require(game:GetService("ReplicatedStorage").Shared.Config)
local function make(reference)
	local sim = C.Simulation
	local w = World.new({
		cellSize = sim.spatialHashCellSize,
		maxEnemies = 140,
		playerRadius = sim.playerRadius,
		contactMargin = sim.contactMargin,
		separationStiffness = sim.separationStiffness,
		separationPasses = sim.separationPasses,
		obstacleSteerMargin = sim.obstacleSteerMargin,
		keepDistanceTolerance = sim.keepDistanceTolerance,
		minX = -1000,
		maxX = 1000,
		minZ = -1000,
		maxZ = 1000,
		obstacles = {},
		referencePlayerSpeed = reference,
	})
	local k = assert(Kinds.get("BabyTrex"))
	local id = assert(w:spawn(k, 0, 0, 1000, 10.6, nil, 1.5, 17))
	return w, id, k
end
describe("Native Baby T-Rex", function()
	it("truncates signed native random offsets before final speed rounding and preserves historical kinds", function()
		local Stats = require(f.Shared.Util.EnemyStats)
		local k = assert(Kinds.get("BabyTrex"))
		local pixel = C.Stats.range.studsPerPoint
		expect(Stats.spawnSpeedFactor(k, 0.497, 1) * k.speed / pixel).toBeNear(250)
		expect(Stats.spawnSpeedFactor(k, 0.003, 1) * k.speed / pixel).toBeNear(201)
		expect(Stats.spawnSpeedFactor(k, 0.997, 1.05) * k.speed / pixel).toBeNear(314)
		local old = assert(Kinds.get("Brute"))
		expect(Stats.spawnSpeedFactor(old, 0.497, 1.2)).toBeNear(1.2 * Stats.speedFactor(old, 0.497))
	end)
	it("uses two flat boosts independent of randomized spawn speed and never changes shared kinds", function()
		local w, id, k = make()
		w:step(1, { 900 }, { 0 }, 1)
		local i = w.indexOf[id]
		expect(w.speedBonuses[i]).toBeNear(20 * C.Stats.range.studsPerPoint)
		expect(w.contactDamage[i]).toBe(12)
		expect(w.kinds[i].radius).toBeNear(k.radius * 1.025)
		expect(w.kinds[i].hurtRadius).toBeNear(k.hurtRadius * 1.025)
		w:step(1, { 900 }, { 0 }, 1)
		expect(w.speedBonuses[i]).toBeNear(240 * C.Stats.range.studsPerPoint)
		expect(w.contactDamage[i]).toBe(13)
		expect(w.kinds[i].radius).toBeNear(k.radius * 1.05)
		expect(Kinds.get("BabyTrex").radius).toBeNear(k.radius)
		w:step(10, { 900 }, { 0 }, 1)
		expect(w.speedBonuses[i]).toBeNear(240 * C.Stats.range.studsPerPoint)
	end)

	it("keeps growth in collision queries, preserves boosts on contact and clears state on slot reuse", function()
		local w, id, k = make()
		w:step(2, { 900 }, { 0 }, 1)
		local x, z = w:getPosition(id)
		local out = {}
		expect(w:queryRadius(x + k.hurtRadius * 1.04, z, 0, out)).toBe(1)
		expect(out[1]).toBe(id)
		local damage = w:step(0.01, { x }, { z }, 1)
		expect(damage[1] > 0).toBe(true)
		expect(w.pursuers[w.indexOf[id]].stage).toBe(2)
		w:remove(id)
		w:step(0, {}, {}, 0)
		local nextId = assert(w:spawn(k, 0, 0, 1000, 10.6))
		expect(w.pursuers[w.indexOf[nextId]].stage).toBe(0)
		expect(w.contactDamage[w.indexOf[nextId]]).toBe(11)
		expect(w:getKind(nextId).radius).toBeNear(k.radius)
	end)
	it("caps at 95 percent of the nearest live player's stat speed before additive slows", function()
		local selected
		local w, id = make(function(index)
			selected = index
			return if index == 2 then 10 else 100
		end)
		w:step(0.1, { 800, 30 }, { 0, 0 }, 2)
		expect(selected).toBe(2)
		local x = w:getPosition(id)
		expect(x).toBeNear(0.95)
		w:nativeSlow(id, -50, true, 1)
		w:step(0.1, { 800, 30 }, { 0, 0 }, 2)
		local after = w:getPosition(id)
		-- Native percentage slow truncates the capped pixel speed before taking 50%, then truncates the penalty.
		expect(after - x).toBeNear((9.5 - 4.7) * 0.1)
	end)

	it("clamps additive slow stacks against uncapped base speed while taking percentages from capped speed", function()
		local w, id = make(function()
			return 10
		end)
		w:step(0.1, { 30 }, { 0 }, 1)
		w:nativeSlow(id, -200, true, 1)
		expect(w.nativeSlows.targets[id].bonus).toBe(-190)
	end)
	it("uses the fastest living player for friendly targets and preserves boosts across transfer", function()
		local w, id, k = make(function()
			return 8
		end)
		w:step(2, { 900 }, { 0 }, 1)
		local other = make(function()
			return 8
		end)
		other:clear()
		expect(w:transferTo(other, id)).toBe(true)
		local i = other.indexOf[id]
		expect(other.pursuers[i].stage).toBe(2)
		expect(other.kinds[i].radius).toBeNear(k.radius * 1.05)
		other:step(0.1, { 900 }, { 0 }, 1)
		local vx, vz = other:getMoveInput(id)
		expect(math.sqrt(vx * vx + vz * vz)).toBeNear(7.6)
	end)

	it("uses the live-player fallback after Charm and lets the next boost reset its damage as in the source", function()
		local Friends = require(f.S.EnemySim.CharmedWorld)
		local calls = {}
		local w, id = make(function(index)
			table.insert(calls, index or 0)
			return if index then 80 else 8
		end)
		w:step(1, { 900 }, { 0 }, 1)
		local friends = Friends.new(w.params, { damage = function() end })
		expect(friends:convert(w, id, 1, 0, { contact = 10.6, shot = 0, spawn = {} })).toBe(true)
		local i = friends.world.indexOf[id]
		expect(friends.world.contactDamage[i]).toBe(math.round(10.6 * require(f.Shared.Config.Charm).damageMultiplier))
		table.clear(calls)
		friends.world:step(1, { 900 }, { 0 }, 1)
		expect(friends.world.contactDamage[i]).toBe(13)
		for _, index in calls do
			expect(index).toBe(0)
		end
		expect(#calls > 0).toBe(true)
		local vx, vz = friends.world:getMoveInput(id)
		expect(math.sqrt(vx * vx + vz * vz)).toBeNear(7.6)
		local x, z = friends.world:getPosition(id)
		assert(w:spawn(assert(Kinds.get("Brute")), x, z, 1000, 0))
		friends:step(0, 0, w)
		expect(friends.world.nativeSlows.targets[id].bonus).toBe(-240)
	end)
	it("ticks native boost timers even without a current target", function()
		local w, id = make()
		w:step(2, {}, {}, 0)
		expect(w.pursuers[w.indexOf[id]].stage).toBe(2)
	end)
	it("transmits growth stages without changing other statuses and resets pooled sprite growth", function()
		local Snapshot = require(game:GetService("ReplicatedStorage").Shared.Net.Snapshot)
		local Models = require(folderProxy("src/client", "Client").Controllers.EnemyRenderer.SpriteModels)
		local k = assert(Kinds.get("BabyTrex"))
		local visual = Models.build(k.typeId)
		local baseStuds = visual.sprite.studs
		local status = Snapshot.STATUS_BURNING + Snapshot.STATUS_CHARMED + Snapshot.packPursuerStage(2)
		local columns = Snapshot.newColumns()
		columns.ids[1], columns.xs[1], columns.zs[1], columns.typeIds[1] = 1, 0, 0, k.typeId
		columns.hpFractions[1], columns.flags[1], columns.statuses[1] = 1, 0, status
		local decoded = Snapshot.newColumns()
		Snapshot.decodeInto(Snapshot.encode(1, columns, 1)[1], decoded, 1)
		expect(bit32.btest(decoded.statuses[1], Snapshot.STATUS_CHARMED)).toBe(true)
		Models.setPursuerStage(visual, Snapshot.unpackPursuerStage(decoded.statuses[1]))
		expect(visual.sprite.studs).toBeNear(baseStuds * 1.2)
		expect(visual.radius).toBeNear(k.radius * 1.05)
		local parts, frames = {}, {}
		Models.pose(visual, CFrame.new(), 0, 0, 0, 0, parts, frames, 0)
		expect(frames[1].Position.Z).toBeNear(-0.8)
		Models.reset(visual)
		expect(visual.sprite.studs).toBeNear(baseStuds)
		expect(visual.radius).toBeNear(k.radius)
	end)
	it("runs the real enemy service and keeps the speed cap when a boosted actor is charmed", function()
		local Enemy = require(f.S.EnemySim)
		local Snapshot = require(f.Shared.Net.Snapshot)
		f.start("WatchmanPistol")
		f.Weapons.setPaused(true)
		require(f.S.MapService).setMovementCheck(false)
		for _, player in { f.me, f.peer } do
			require(f.S.CombatService).protect(player, 10000)
		end
		local at = f.me.Character.HumanoidRootPart.Position
		f.peer.Character.HumanoidRootPart.Position = at + Vector3.new(-100, 0, 0)
		local statuses = {}
		local connection = f.world.getRemote("EnemySnapshot").OnClientEvent:Connect(function(packet)
			local decoded = Snapshot.newColumns()
			Snapshot.decodeInto(packet, decoded, 1)
			for i, id in decoded.ids do
				statuses[id] = decoded.statuses[i]
			end
		end)
		local id = assert(Enemy.spawn("BabyTrex", at.X + 150, at.Z, 100, 10, nil, nil, 1, 17))
		f.world.advance(2.2, 1 / 60)
		expect(Snapshot.unpackPursuerStage(statuses[id] or 0)).toBe(2)
		local _, damage = Enemy.getMultipliers(id)
		expect(damage).toBe(127)
		local pos = Enemy.getPosition(id)
		Enemy.damage(id, 1, nil)
		expect(Enemy.tryCharm(f.me, id, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end)).toBe(true)
		local target = assert(Enemy.spawn("Brute", pos.X + 200, pos.Z, 10000, 0, nil, nil, 0))
		f.world.advance(0.3, 1 / 60)
		expect(bit32.btest(statuses[id] or 0, Snapshot.STATUS_CHARMED)).toBe(true)
		expect(Snapshot.unpackPursuerStage(statuses[id] or 0)).toBe(2)
		expect(Enemy.isAlive(target)).toBe(true)
		connection:Disconnect()
		expect(#f.world.errors).toBe(0)
	end)
end)
