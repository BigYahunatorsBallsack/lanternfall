--!strict
-- Real six-family attacks and shared native weakness; pending artwork is enabled only inside this isolated fixture.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Enemy, Combat = require(S.EnemySim), require(S.CombatService)
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
Config.Classes.NightWatch.weaponKind = nil
for _, id in { "Spoon", "Cestus", "Sickle", "Trident", "Lute", "Blowgun" } do
	Config.Weapons[id].available = true
end
Run.setHoldWaves(true)
assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
require(S.SpawnDirector).setPaused(true)
require(S.ExperienceService).setPaused(true)
require(S.LootService).setDropsPaused(true)
local function clearWeapons()
	for _, p in { me, peer } do
		for _, w in Weapons.getWeapons(p) do
			Weapons.removeWeapon(p, w.uid)
		end
	end
end
local function clear()
	clearWeapons()
	Enemy.killAll()
	for _, p in { me, peer } do
		local delta = {}
		for stat, value in
			{
				damage = 0,
				meleeDamage = 0,
				rangedDamage = 0,
				elementalDamage = 0,
				knockback = 0,
				curse = 0,
				harvesting = 0,
				range = 0,
				critChance = -100,
				attackSpeed = 0,
				maxHp = 20,
			}
		do
			local gain = (Config.Classes.NightWatch.gainMultipliers or {})[stat] or 1
			delta[stat] = (value - Stats.getStat(p, stat)) / gain
		end
		assert(Stats.addStats(p, delta))
		Combat.protect(p, 10000)
	end
	peer.Character.HumanoidRootPart.Position = Vector3.new(200, 0, 200)
end
local function target(share)
	local at = me.Character.HumanoidRootPart.Position
	local id = assert(Enemy.spawn("Brute", at.X + 5, at.Z, 100, 1, nil, nil, 0))
	if share then
		Enemy.damage(id, Enemy.getHealth(id) * (1 - share), me)
	end
	return id
end
local function hit(id, tier, enemy, owner, seconds)
	owner = owner or me
	assert(Weapons.addWeapon(owner, id, tier))
	local w = Weapons.getWeapons(owner)[1]
	local hp = Enemy.getHealth(enemy)
	world.advance(seconds or 0.1)
	local actual = hp - Enemy.getHealth(enemy)
	Weapons.removeWeapon(owner, w.uid)
	return actual, w.stats
end
describe("Native character starting gear", function()
	it("attacks with every valid tier through actual behaviors and credits its owner", function()
		for _, id in { "Spoon", "Cestus", "Sickle", "Trident", "Lute", "Blowgun" } do
			for tier = Config.Weapons[id].minTier, 4 do
				clear()
				local enemy = target()
				assert(Weapons.addWeapon(me, id, tier))
				world.advance(0.7)
				expect(Weapons.getDamageStats(me)[id].damage > 0).toBe(true)
			end
		end
	end)
	it("forces Spoon's critical hit without critical chance, before burning ticks", function()
		clear()
		local enemy = target()
		Weapons.structureBurn(me, enemy, 1, 5, {})
		Enemy.applyWeakness(enemy, "Lute", 10, 3, 3)
		local dealt, stats = hit("Spoon", 1, enemy)
		expect(dealt).toBe(math.round(math.round(stats.damage * stats.critDamage) * 1.1))
	end)
	it("uses Sickle and Trident boundary bonuses in actual damage", function()
		clear()
		local dealt, stats = hit("Sickle", 1, target(0.3))
		expect(dealt).toBe(math.round(stats.damage * 1.2))
		clear()
		dealt, stats = hit("Trident", 2, target(0.8))
		expect(dealt).toBe(math.round(stats.damage * 1.3))
	end)
	it("shares Lute stacks between owners, combines Blowgun, upgrades its value and expires them", function()
		clear()
		peer.Character.HumanoidRootPart.Position = me.Character.HumanoidRootPart.Position
		local enemy = target()
		for i = 1, 4 do
			hit("Lute", 1, enemy, if i % 2 == 0 then peer else me)
		end
		local hp = Enemy.getHealth(enemy)
		Enemy.damage(enemy, 100, peer)
		expect(Enemy.getHealth(enemy)).toBe(hp - 130)
		hit("Blowgun", 1, enemy, me, 0.2)
		hp = Enemy.getHealth(enemy)
		Enemy.damage(enemy, 100, peer)
		expect(Enemy.getHealth(enemy)).toBe(hp - 150)
		hit("Blowgun", 4, enemy, me, 0.2)
		hp = Enemy.getHealth(enemy)
		Enemy.damage(enemy, 100, peer)
		expect(Enemy.getHealth(enemy)).toBe(hp - 180)
		world.advance(3.2)
		hp = Enemy.getHealth(enemy)
		Enemy.damage(enemy, 100, peer)
		expect(Enemy.getHealth(enemy)).toBe(hp - 100)
	end)
	it("applies active weakness to actual burning ticks as well as weapon damage", function()
		clear()
		local enemy = target()
		Enemy.applyWeakness(enemy, "Lute", 10, 3, 3)
		Enemy.applyWeakness(enemy, "Blowgun", 20, 3, 1)
		local hp = Enemy.getHealth(enemy)
		Weapons.structureBurn(me, enemy, 10, 1, {})
		world.advance(1.1)
		expect(Enemy.getHealth(enemy)).toBe(hp - 13)
	end)

	it("adds target and burning bonuses to vulnerability rather than multiplying them", function()
		clear()
		local enemy = target()
		Enemy.applyWeakness(enemy, "Lute", 10, 3, 3)
		Enemy.applyWeakness(enemy, "Blowgun", 20, 3, 1)
		local hp = Enemy.getHealth(enemy)
		Enemy.damage(enemy, 100, me, 200)
		expect(Enemy.getHealth(enemy)).toBe(hp - 330)
		expect(#world.errors).toBe(0)
	end)
end)
