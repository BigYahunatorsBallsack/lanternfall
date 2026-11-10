--!strict
-- Soldier must gate catch-up attacks while existing projectiles and reload clocks continue in the real server.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Fx = require(Shared.Net.WeaponFx)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run = require(S.RunDirector)
local Weapons = require(S.WeaponService)
local Enemy = require(S.EnemySim)
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
Config.Classes.Soldier.available = true
require(S.PlayerDataService).unlockAll(me)
world.fireServerAs(me, "SelectClass", "Soldier")
require(S.SpawnDirector).setPaused(true)
Weapons.setPaused(true)
Run.setHoldWaves(true)
Run.setReady(me, true)
world.advance(3.5)
Enemy.killAll()
for _, weapon in Weapons.getWeapons(me) do
	Weapons.removeWeapon(me, weapon.uid)
end
assert(Weapons.addWeapon(me, "ChainGun", 4))
require(S.StatService).addStats(me, { attackSpeed = 1000 })
local pelletsPerAttack = Weapons.getWeapons(me)[1].stats.count
local fires = 0
world.getRemote("WeaponEffects").OnClientEvent:Connect(function(packet)
	for _, effect in Fx.decode(packet) do
		if effect.kind == "Fire" and effect.weapon == "ChainGun" then
			fires += 1
		end
	end
end)
local here = me.Character.HumanoidRootPart.Position
local id = assert(Enemy.spawn("Brute", here.X + 30, here.Z, 1000, 1))
Enemy.setSpeedFactor(id, 0)

describe("Soldier attack conditions", function()
	it("blocks new fast catch-up shots while allowing already fired projectiles to hit", function()
		Weapons.setPaused(false)
		world.advance(0.14, 1 / 60)
		expect(fires > pelletsPerAttack).toBe(true)
		local before = Enemy.getHealth(id)
		world.fireServerAs(me, "SetMovementIntent", true)
		fires = 0
		world.advance(0.8, 1 / 60)
		expect(fires).toBe(0)
		expect(Enemy.getHealth(id) < before).toBe(true)
	end)

	it("fires immediately after stopping without banking a moving-period catch-up burst", function()
		world.fireServerAs(me, "SetMovementIntent", false)
		fires = 0
		world.advance(1 / Config.Simulation.tickRate, 1 / Config.Simulation.tickRate)
		expect(fires > 0).toBe(true)
		expect(fires <= (Config.Combat.originalWeapons.maxCatchupAttacks + 1) * pelletsPerAttack).toBe(true)
	end)
end)
