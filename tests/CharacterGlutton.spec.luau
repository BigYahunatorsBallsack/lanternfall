--!strict
-- Real Glutton consumption, full-health ordering and isolated damage; native PC 1.2.0.1 facts.
-- glutton_explosion_stats.tres MD5 903aec349462891b556c4a5270294131; glutton_effect_2.tres 4db990389837f06feb52e7a140e29cc1.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
Config.Classes.Glutton.available = true -- fixture-only, after startup validation
local S = Server.Services
local Run = require(S.RunDirector)
local Weapons = require(S.WeaponService)
local Combat = require(S.CombatService)
local Stats = require(S.StatService)
local Enemy = require(S.EnemySim)
local Loot = require(S.LootService)
local me = world.addPlayer("Glutton", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
require(S.PlayerDataService).unlockAll(me)
assert(Run.selectClass(me, "Glutton"))
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
peer.Character.HumanoidRootPart.Position = Vector3.new(200, 0, 200)
local function root()
	return me.Character.HumanoidRootPart.Position
end
local function clear(values)
	Enemy.killAll()
	Combat.healPlayer(me, 1e6)
	local delta = {}
	for _, stat in
		{
			"damage",
			"explosionDamage",
			"meleeDamage",
			"rangedDamage",
			"elementalDamage",
			"lifeSteal",
			"critChance",
			"hpRegen",
		}
	do
		local desired = (values or {})[stat]
		if desired == nil then
			desired = if stat == "critChance" or stat == "hpRegen" then -100 else 0
		end
		delta[stat] = desired - Stats.getStat(me, stat)
	end
	assert(Stats.addStats(me, delta))
end
local function target(x)
	local pos = root()
	return assert(Enemy.spawn("Brute", pos.X + x, pos.Z, 100, 1, nil, nil, 0))
end
local function collect(kind, x)
	assert(Loot.dropPickup(root() + Vector3.new(x or 0, 0, 0), kind))
	world.advance(0.2)
end

describe("Native Glutton consumption", function()
	it("explodes at a fruit's position below full HP, without needing any weapon", function()
		clear()
		Combat.drainPlayer(me, 4)
		local near, far = target(35), target(50)
		local hp, farHp = Enemy.getHealth(near), Enemy.getHealth(far)
		collect("Fruit", 10)
		expect(Enemy.getHealth(near)).toBe(hp - 10)
		expect(Enemy.getHealth(far)).toBe(farHp)
		expect(Stats.getStat(me, "explosionDamage")).toBe(0)
		expect(#Weapons.getWeapons(me)).toBe(0)
	end)

	it("adds the full-health stat before calculating every kind of consumable explosion", function()
		for _, kind in { "Fruit", "Crate", "Legendary" } do
			clear({ meleeDamage = 18 }) -- 10 + 500% of 18 = 100; a 1% bonus is observable
			local id = target(8)
			local hp = Enemy.getHealth(id)
			collect(kind)
			expect(Stats.getStat(me, "explosionDamage")).toBe(1)
			expect(Enemy.getHealth(id)).toBe(hp - 101)
		end
	end)

	it("checks full HP before healing, so a fruit that fills the last missing HP gives no permanent stat", function()
		clear()
		Combat.drainPlayer(me, 1)
		local id = target(8)
		local hp = Enemy.getHealth(id)
		collect("Fruit")
		local current, maximum = Combat.getHp(me)
		expect(current).toBe(maximum)
		expect(Stats.getStat(me, "explosionDamage")).toBe(0)
		expect(Enemy.getHealth(id)).toBe(hp - 10)
	end)

	it("uses fivefold Melee, additive percentage bonuses and its own crit multiplier without life steal", function()
		clear({
			meleeDamage = 2,
			damage = 20,
			explosionDamage = 50,
			critChance = 100,
			lifeSteal = 100,
		})
		Combat.drainPlayer(me, 4)
		local id = target(8)
		local hp = Enemy.getHealth(id)
		collect("Fruit")
		expect(Enemy.getHealth(id)).toBe(hp - 51) -- round(round((10 + 2*5) * 1.7) * 1.5)
		local current, maximum = Combat.getHp(me)
		expect(current).toBe(maximum - 1)
	end)

	it("snapshots each pickup after its own full-health gain before deferred collision", function()
		clear({ meleeDamage = 18 })
		local id = target(8)
		local hp = Enemy.getHealth(id)
		assert(Loot.dropPickup(root(), "Fruit"))
		assert(Loot.dropPickup(root(), "Fruit"))
		world.advance(0.2)
		expect(Stats.getStat(me, "explosionDamage")).toBe(2)
		expect(Enemy.getHealth(id)).toBe(hp - 101 - 102)
	end)

	it("does not explode or award its full-health stat when the co-op peer consumes a fruit", function()
		clear()
		local pos = root()
		peer.Character.HumanoidRootPart.Position = pos + Vector3.new(80, 0, 0)
		local id = target(85)
		local hp = Enemy.getHealth(id)
		assert(Loot.dropPickup(peer.Character.HumanoidRootPart.Position, "Fruit"))
		world.advance(0.2)
		expect(Enemy.getHealth(id)).toBe(hp)
		expect(Stats.getStat(me, "explosionDamage")).toBe(0)
		expect(Stats.getStat(peer, "explosionDamage")).toBe(0)
		expect(#world.errors).toBe(0)
	end)
end)
