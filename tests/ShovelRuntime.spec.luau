--!strict
-- Shovel's actual killing hitbox carries its crate chance through EnemySim into loot, without leaking to other kills.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Weapons, Enemy = require(S.RunDirector), require(S.WeaponService), require(S.EnemySim)
local Loot, Stats = require(S.LootService), require(S.StatService)
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
Config.Weapons.Shovel.available = true
Config.Classes.NightWatch.weaponKind = nil
Run.setHoldWaves(true)
Run.setReady(me, true)
world.advance(3.5)
require(S.SpawnDirector).setPaused(true)
require(S.CombatService).protect(me, 10000)
for _, weapon in Weapons.getWeapons(me) do
	Weapons.removeWeapon(me, weapon.uid)
end
Enemy.killAll()
assert(Stats.addStats(me, { luck = -100 }))
local Random = require(S.RandomService)
local original = Random.stream
Random.stream = function(channel, player)
	return if channel == "Loot"
		then {
			NextNumber = function()
				return 0
			end,
		}
		else original(channel, player)
end
local function target()
	local at = me.Character.HumanoidRootPart.Position
	local id = assert(Enemy.spawn("Shadeling", at.X + 5, at.Z, 1, 0, nil, nil, 0))
	Enemy.damage(id, Enemy.getHealth(id) - 1, nil)
	return id
end
describe("Native Shovel kill path", function()
	it("digs a regular crate from the actual weapon kill even with negative Luck", function()
		assert(Weapons.addWeapon(me, "Shovel", 1))
		local id = target()
		world.advance(1.5)
		expect(Enemy.isAlive(id)).toBe(false)
		expect(Loot.getCratesThisWave()).toBe(1)
	end)
	it("does not grant the weapon's effect to unrelated damage or another equipped weapon", function()
		local id = target()
		Enemy.damage(id, 10000, me)
		expect(Loot.getCratesThisWave()).toBe(1)
		for _, weapon in Weapons.getWeapons(me) do
			Weapons.removeWeapon(me, weapon.uid)
		end
		assert(Weapons.addWeapon(me, "RitualDirk", 1))
		id = target()
		world.advance(1.5)
		expect(Enemy.isAlive(id)).toBe(false)
		expect(Loot.getCratesThisWave()).toBe(1)
		expect(#world.errors).toBe(0)
	end)
end)
