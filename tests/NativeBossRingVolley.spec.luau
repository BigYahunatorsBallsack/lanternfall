--!strict
-- Original Therizinosaurus second-phase bullets use one random ring origin and target rotation for the whole batch.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Volley = require(Shared.Util.NativeEnemyVolley)
local function emit(rule, first, second, tx, tz)
	local calls, shots = 0, {}
	Volley.emit(rule, 12, -8, tx or 52, tz or 12, 60, function()
		calls += 1
		return if calls == 1 then first elseif calls == 2 then second else 0.37
	end, function(x, z, dx, dz, speed)
		table.insert(shots, { x, z, dx, dz, speed })
	end)
	return shots
end
local function rule()
	return {
		count = 12,
		spread = 0,
		constantSpread = true,
		offsetX = 0,
		offsetZ = 0,
		speedStep = 0,
		spawnRing = { radius = 10, away = false, baseRandomization = 3.14 },
		aimFromSpawn = { targetRotation = 1.2 },
	}
end
describe("Native boss circle volley", function()
	it("rotates the complete twelve-shot ring by one source batch draw", function()
		local shots = emit(rule(), 0.25, 0.5)
		expect(#shots).toBe(12)
		for i, shot in shots do
			local angle = 3.14 / 4 + (i - 1) * math.pi / 6
			expect(shot[1]).toBeNear(12 + math.cos(angle) * 10)
			expect(shot[2]).toBeNear(-8 + math.sin(angle) * 10)
			expect(shot[5]).toBe(60)
		end
	end)
	it("aims every bullet from its own origin towards the same rotated player target", function()
		local shots = emit(rule(), 0.25, 0.75)
		local angle = 0.6 -- source rand_range(-1.2,1.2) at0.75
		local tx = 12 + 40 * math.cos(angle) - 20 * math.sin(angle)
		local tz = -8 + 40 * math.sin(angle) + 20 * math.cos(angle)
		for _, shot in shots do
			local x, z = tx - shot[1], tz - shot[2]
			local distance = math.sqrt(x * x + z * z)
			expect(shot[3]).toBeNear(x / distance)
			expect(shot[4]).toBeNear(z / distance)
		end
	end)
	it("lets source shoot-from-projectile aim override earlier fan, angle and outward choices", function()
		local r = rule()
		r.spread, r.specificDegrees, r.spawnRing.away = 1, table.create(12, 170), true
		local shots = emit(r, 0.25, 0.5)
		for _, shot in shots do
			local x, z = 52 - shot[1], 12 - shot[2]
			local distance = math.sqrt(x * x + z * z)
			expect(shot[3]).toBeNear(x / distance)
			expect(shot[4]).toBeNear(z / distance)
		end
	end)
	it("does not rotate a legacy fixed ring when the new source policy is absent", function()
		local r = rule()
		r.spawnRing.baseRandomization, r.aimFromSpawn, r.spawnRing.away = nil, nil, true
		local shots = emit(r, 0.25, 0.75)
		expect(shots[1][1]).toBeNear(22)
		expect(shots[1][2]).toBeNear(-8)
		expect(shots[1][3]).toBeNear(1)
		expect(shots[1][4]).toBeNear(0)
	end)
	it("builds the volley from the actual bound second phase and preserves its independent bullet scene", function()
		local C = require(Shared.Config.NativeBossPhases)
		local source = C.actors.Therizinosaurus.shooting
		expect(source.root.projectileSource).toBe("res://projectiles/slash/slash_projectile.tscn")
		expect(source.phaseOne.projectileSource).toBe("res://projectiles/bullet_enemy/enemy_projectile.tscn")
		local r = C.therizinosaurusPhaseOneVolley
		expect(r.count).toBe(12)
		expect(r.spawnRing.radius).toBe(10)
		expect(r.spawnRing.baseRandomization).toBe(3.14)
		expect(r.aimFromSpawn.targetRotation).toBe(1.2)
	end)
end)
