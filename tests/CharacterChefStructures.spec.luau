--!strict
-- Real Chef pickups/attacks from stable 1.2.0.1 facts; fixture availability does not certify missing gear/artwork.
-- chef_explosion_stats.tres MD5 e392dabe977d5e25542333841ccd1ab3; chef_burning_data.tres 3ae69eaa4b71c9fc99d28fce91cb9637.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
Config.Classes.Chef.available = true -- fixture-only, after startup validation
local S = Server.Services
local Run = require(S.RunDirector)
local Weapons = require(S.WeaponService)
local Combat = require(S.CombatService)
local Stats = require(S.StatService)
local Enemy = require(S.EnemySim)
local Loot = require(S.LootService)
local me = world.addPlayer("Chef", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
require(S.PlayerDataService).unlockAll(me)
assert(Run.selectClass(me, "Chef"))
assert(Weapons.selectStartWeapon(me, "Chef", "Chopper"))
assert(Run.selectClass(peer, "DuelMaestro"))
Run.setHoldWaves(true)
Run.setReady(me, true)
Run.setReady(peer, true)
world.advance(3.5)
require(S.SpawnDirector).setPaused(true)
require(S.ExperienceService).setPaused(true)
Loot.setDropsPaused(true)
for _, player in { me, peer } do
	for _, weapon in Weapons.getWeapons(player) do
		Weapons.removeWeapon(player, weapon.uid)
	end
end
Enemy.killAll()
assert(Stats.addStats(me, { maxHp = 20 - Stats.getStat(me, "maxHp") }))
assert(Stats.addStats(peer, { maxHp = 20 - Stats.getStat(peer, "maxHp") }))
peer.Character.HumanoidRootPart.Position = Vector3.new(200, 0, 200)
describe("Native Chef structure hitboxes", function()
	it("applies the same non-elemental bonus to a real deployed turret", function()
		Enemy.killAll()
		assert(Stats.addStats(me, { critChance = -100 }))
		assert(Stats.addItem(me, "BrassSentry"))
		Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
		for _, player in { me, peer } do
			world.fireServerAs(player, "SetShopReady", true)
		end
		world.advance(1)
		assert(Run.isActive())
		for _, weapon in Weapons.getWeapons(me) do
			Weapons.removeWeapon(me, weapon.uid)
		end
		require(S.SpawnDirector).setPaused(true)
		Enemy.killAll()
		local turret = require(S.StructureService).getSnapshot()[1]
		assert(turret and turret.kind == "BrassSentry")
		local id = assert(Enemy.spawn("Brute", turret.x + 5, turret.z, 100, 1, nil, nil, 0))
		Weapons.structureBurn(me, id, 1, 5, {})
		local hp = Enemy.getHealth(id)
		world.advance(0.8)
		local dealt = hp - Enemy.getHealth(id) - 1 -- one burn tick of 1 (Brotato: every 0.5 s)
		local base = require(S.StructureService.Rules).damage(Config.Structures.kinds.BrassSentry, Stats.getSheet(me))
		expect(dealt >= base * 3).toBe(true)
		expect(dealt % (base * 3)).toBe(0)
	end)
end)
