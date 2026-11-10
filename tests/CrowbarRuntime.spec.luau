--!strict
-- Crowbar deployments are earned by the actual weapon's kills, retain location, and reset at wave boundaries.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Weapons, Enemy = require(S.RunDirector), require(S.WeaponService), require(S.EnemySim)
local Structures = require(S.StructureService)
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
Config.Weapons.Crowbar.available = true
Config.Classes.NightWatch.weaponKind = nil
Run.setHoldWaves(true)
Run.setReady(me, true)
world.advance(3.5)
require(S.SpawnDirector).setPaused(true)
require(S.LootService).setDropsPaused(true)
require(S.CombatService).protect(me, 10000)
for _, w in Weapons.getWeapons(me) do
	Weapons.removeWeapon(me, w.uid)
end
Enemy.killAll()
assert(Weapons.addWeapon(me, "Crowbar", 1))
Structures.setPaused(true)
local last
local lastAt
local function kill()
	local at = me.Character.HumanoidRootPart.Position
	last = assert(Enemy.spawn("Shadeling", at.X + 5, at.Z, 1, 0, nil, nil, 0))
	lastAt = Vector3.new(at.X + 5, at.Y, at.Z)
	world.advance(1.5)
	expect(Enemy.isAlive(last)).toBe(false)
end
local function turrets()
	local found = {}
	for _, row in Structures.getSnapshot() do
		if row.kind == "BloodTurret" then
			table.insert(found, row)
		end
	end
	return found
end
describe("Native Crowbar deployments", function()
	it("spawns the native turret only on the eighteenth kill at the killed actor's position", function()
		for _ = 1, 17 do
			kill()
		end
		expect(#turrets()).toBe(0)
		kill()
		expect(#turrets()).toBe(1)
		local at = lastAt
		expect(turrets()[1].x).toBeNear(at.X)
		expect(turrets()[1].z).toBeNear(at.Z)
		expect(turrets()[1].ownerId).toBe(me.UserId)
		expect(#world.errors).toBe(0)
	end)
	it("uses all four native thresholds and clears the partial count on the next wave", function()
		for tier, threshold in { 16, 14, 12 } do
			for _, w in Weapons.getWeapons(me) do
				Weapons.removeWeapon(me, w.uid)
			end
			assert(Weapons.addWeapon(me, "Crowbar", tier + 1))
			local before = #turrets()
			for _ = 1, threshold - 1 do
				kill()
			end
			expect(#turrets()).toBe(before)
			kill()
			expect(#turrets()).toBe(before + 1)
		end
		for _ = 1, 11 do
			kill()
		end
		Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
		world.advance(0.1)
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(1)
		require(S.SpawnDirector).setPaused(true)
		Enemy.killAll()
		kill()
		expect(#turrets()).toBe(0)
		for _ = 1, 11 do
			kill()
		end
		expect(#turrets()).toBe(1)
	end)

	it("applies shared ten-percent weakness stacks before the blood projectile hit and expires them", function()
		Weapons.setPaused(true)
		Enemy.killAll()
		local projectiles = require(S.StructureService.Projectiles)
		local at = me.Character.HumanoidRootPart.Position
		local id = assert(Enemy.spawn("Brute", at.X + 12, at.Z, 1000, 0, nil, nil, 0))
		local def = Config.Structures.kinds.BloodTurret
		local function shot()
			local before = Enemy.getHealth(id)
			projectiles.launch(me, at, def, { engineering = 0 }, { Vector3.new(1, 0, 0) })
			projectiles.step(0.1)
			return before - Enemy.getHealth(id)
		end
		expect(shot()).toBe(9)
		expect(shot()).toBe(10)
		expect(shot()).toBe(10)
		expect(shot()).toBe(10)
		local _, taken = Enemy.damage(id, 100, me)
		expect(taken).toBe(130)
		world.advance(5.2)
		local _, expired = Enemy.damage(id, 100, me)
		expect(expired).toBe(100)
		expect(#world.errors).toBe(0)
	end)
end)
