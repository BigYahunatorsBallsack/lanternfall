--!strict
-- Actual radial/death services exercised through a registered source-backed normal Dimetrodon; original art and full physics acceptance remain open.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Combat = require(f.S.WeaponService.BrotatoCombat)
local C = require(f.Shared.Config.NativeDimetrodon)
local function start()
	f.start("WatchmanPistol")
	f.Weapons.setPaused(true)
	require(f.S.StructureService).setPaused(true)
	require(f.S.MapService).setMovementCheck(false)
	require(f.S.CombatService).protect(f.me, 10000)
	require(f.S.CombatService).protect(f.peer, 10000)
	f.me.Character.HumanoidRootPart.Position = Vector3.new(0, 100, 0)
	f.peer.Character.HumanoidRootPart.Position = Vector3.new(80, 100, 80)
end
local function spawn()
	return assert(Enemy.spawn("Dimetrodon", -40, 0, 1000, 2, nil, nil, 0, 10))
end
local function hit(id, kind, pet)
	local w = {
		ownerId = f.me.UserId,
		id = "probe",
		state = {},
		config = { kind = kind, scaling = {} },
		stats = { critChance = 0, damage = 1e9, petSourceShootsProjectiles = pet },
	}
	local ctx = {
		random = function()
			return 0.9
		end,
		enemyPosition = function()
			local p = Enemy.getPosition(id)
			return p.X, p.Z
		end,
		hit = function()
			return Enemy.damage(id, 1e9, f.me)
		end,
	}
	return Combat.hit(w, ctx, id)
end
describe("Dimetrodon attacks through real services, registered normal actor", function()
	it("keeps source rule geometry and independent native projectile growth", function()
		expect(C.actorRegistered).toBe(true)
		expect(C.radialRule.projectileRadius).toBeNear(1.70294)
		expect(C.radialRule.volley.spawnRing.radius).toBeNear(1.25)
		start()
		local id = spawn()
		local fired = {}
		local c = f.world.getRemote("EnemyShots").OnClientEvent:Connect(function(batch)
			for _, shot in require(f.Shared.Net.ShotFeed).decode(batch).fired do
				table.insert(fired, shot)
			end
		end)
		Enemy.damage(id, 1e9, f.me)
		expect(Enemy.getShotCount()).toBe(8)
		f.world.advance(0.08, 1 / 60)
		c:Disconnect()
		expect(#fired).toBe(8)
		for i, shot in fired do
			local a = (i - 1) * math.pi / 4
			expect(shot.x).toBeNear(-40 + math.cos(a) * 1.25)
			expect(shot.z).toBeNear(math.sin(a) * 1.25)
			expect(shot.dx).toBeNear(math.cos(a))
			expect(shot.dz).toBeNear(math.sin(a))
			expect(shot.speed).toBe(30)
		end
	end)
	it("classifies the actual lethal hit before damage, using the latest recognized source", function()
		for _, data in { { "Melee", nil, 0 }, { "Ranged", nil, 8 }, { "Pet", 0, 0 }, { "Pet", 1, 8 } } do
			start()
			local id = spawn()
			Enemy.noteHurtContact(id, "Melee")
			expect(hit(id, data[1], data[2])).toBe(true)
			expect(Enemy.getShotCount()).toBe(data[3])
		end
	end)
	it("keeps a prior melee flag through an unclassified damage path and suppresses cleanup", function()
		start()
		local id = spawn()
		Enemy.noteHurtContact(id, "Melee")
		Enemy.noteHurtContact(id, "Structure")
		Enemy.damage(id, 1e9, f.me)
		expect(Enemy.getShotCount()).toBe(0)
		spawn()
		Enemy.killAll()
		expect(Enemy.getShotCount()).toBe(0)
	end)
	it("emits one eight-shot landing volley with actual rounded hostile hits", function()
		start()
		local id = spawn()
		local hits = {}
		local c = Enemy.ShotHit:Connect(function(player, damage)
			if player == f.me then
				table.insert(hits, damage)
			end
		end)
		f.world.advance(2.3, 1 / 60)
		c:Disconnect()
		expect(#hits).toBe(8)
		for _, damage in hits do
			expect(damage).toBe(23)
		end
		expect(Enemy.isAlive(id)).toBe(true)
	end)
	it("keeps owner and native damage after Charm, including the later death volley", function()
		start()
		local id = spawn()
		local target = assert(Enemy.spawn("Brute", 0, 0, 1000, 0, nil, nil, 0, 10))
		assert(Enemy.charmSummoned(id, f.me.UserId))
		local shots = {}
		local c = Enemy.CharmShot:Connect(function(owner, event)
			if event.kind == "CharmFire" then
				expect(owner).toBe(f.me.UserId)
				table.insert(shots, event)
			end
		end)
		local before = Enemy.getHealth(target)
		local damage = Enemy.damage
		local projectileHits = 0
		Enemy.damage = function(targetId, amount, ...)
			if targetId == target and amount == 68 then
				projectileHits += 1
			end
			return damage(targetId, amount, ...)
		end
		f.world.advance(2.3, 1 / 60)
		Enemy.damage = damage
		expect(#shots).toBe(8)
		for _, shot in shots do
			expect(shot.speed).toBe(40)
		end
		-- Same global factor2 as the hostile case: round(11.35 * 2 * 3)=68, not round(22.7)*3=69.
		expect(projectileHits).toBe(8)
		expect(before - Enemy.getHealth(target) >= 544).toBe(true)
		-- Expiration uses the actual member's retained origin flag and the friendly projectile system.
		f.world.advance(require(f.Shared.Config.Charm).duration, 1 / 60)
		c:Disconnect()
		local deaths = 0
		for _, shot in shots do
			if shot.speed == 30 then
				deaths += 1
			end
		end
		expect(deaths).toBe(8)
		expect(Enemy.isCharmed(id)).toBe(false)
		expect(#f.world.errors).toBe(0)
	end)
	it("excludes deaths at the strict final half-second boundary", function()
		start()
		local id = spawn()
		local schedule = require(f.Shared.Util.RunSchedule).wave(f.Run.getWave())
		f.Run.skipTo(schedule.endsAt - C.radialRule.deathWaveCutoffSeconds)
		Enemy.damage(id, 1e9, f.me)
		expect(Enemy.getShotCount()).toBe(0)
	end)
	it("retains a melee suppression flag through Charm expiration", function()
		start()
		local id = spawn()
		Enemy.noteHurtContact(id, "Melee")
		assert(Enemy.spawn("Brute", 0, 0, 1000, 0, nil, nil, 0, 10))
		assert(Enemy.charmSummoned(id, f.me.UserId))
		local deaths = 0
		local c = Enemy.CharmShot:Connect(function(_, event)
			if event.kind == "CharmFire" and event.speed == 30 then
				deaths += 1
			end
		end)
		f.world.advance(require(f.Shared.Config.Charm).duration + 0.1, 1 / 60)
		c:Disconnect()
		expect(deaths).toBe(0)
		expect(Enemy.isCharmed(id)).toBe(false)
	end)
	it("recalculates death-shot damage without a temporary buffer bonus", function()
		start()
		local probe = f.Config.Enemies.types.Dimetrodon
		local jump = probe.nativeJump
		probe.nativeJump = nil
		local id = spawn()
		local originalHp = Enemy.getMaxHealth(id)
		probe.nativeJump = jump
		assert(Enemy.spawn("CorruptedBuffer", -40, -10, 1000, 0, nil, nil, 0, 10))
		f.world.advance(1.1, 1 / 60)
		expect(Enemy.getMaxHealth(id) > originalHp).toBe(true)
		local hits = {}
		local c = Enemy.ShotHit:Connect(function(player, damage)
			if player == f.me then
				table.insert(hits, damage)
			end
		end)
		Enemy.damage(id, 1e9, f.me)
		f.world.advance(1.5, 1 / 60)
		c:Disconnect()
		expect(#hits).toBe(1)
		expect(hits[1]).toBe(23)
	end)
end)
