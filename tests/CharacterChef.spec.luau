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
local function root()
	return me.Character.HumanoidRootPart.Position
end
local function clear()
	for _, player in { me, peer } do
		for _, weapon in Weapons.getWeapons(player) do
			Weapons.removeWeapon(player, weapon.uid)
		end
	end
	Enemy.killAll()
	Combat.healPlayer(me, 1e6)
	local delta = {}
	for _, stat in
		{ "damage", "explosionDamage", "meleeDamage", "rangedDamage", "elementalDamage", "lifeSteal", "critChance" }
	do
		local desired = if stat == "critChance" then -100 else 0
		local gain = (Config.Classes.Chef.gainMultipliers or {})[stat] or 1
		delta[stat] = (desired - Stats.getStat(me, stat)) / gain
	end
	assert(Stats.addStats(me, delta))
end
local function target(x)
	local pos = root()
	return assert(Enemy.spawn("Brute", pos.X + x, pos.Z, 100, 1, nil, nil, 0))
end
local function collect(kind, x)
	local pos = root()
	assert(Loot.dropPickup(pos + Vector3.new(x or 0, 0, 0), kind))
	world.advance(0.2)
end
local function hitWith(player, weaponId, burning)
	for _, weapon in Weapons.getWeapons(player) do
		Weapons.removeWeapon(player, weapon.uid)
	end
	assert(Weapons.addWeapon(player, weaponId))
	local id = target(5)
	if burning then
		Weapons.structureBurn(me, id, 1, 5, {})
	end
	local hp = Enemy.getHealth(id)
	local weapon = Weapons.getWeapons(player)[1]
	local expected = weapon.stats.damage
	weapon.cooldownLeft = 0
	world.advance(0.2)
	Weapons.removeWeapon(player, weapon.uid)
	return hp - Enemy.getHealth(id), expected
end

describe("Native Chef consumption and burning targets", function()
	it("uses the pickup origin and burns fresh targets even when the pickup heals nothing", function()
		clear()
		-- at full HP a fruit is only taken when walked over (Brotato ItemPickupArea), so it lies 3 studs away
		local near, far = target(36), target(53)
		local hp, farHp = Enemy.getHealth(near), Enemy.getHealth(far)
		collect("Fruit", 3)
		expect(Enemy.getHealth(near)).toBe(hp - 1) -- native zero base clamps to one
		expect(Enemy.getHealth(far)).toBe(farHp)
		expect(Weapons.isBurning(near)).toBe(true)
		world.advance(0.5) -- one burn tick (Brotato: every 0.5 s)
		-- Mandatory Scared Sausage contributes +1 to the innate base-1 burn; five ticks, no crit.
		expect(Enemy.getHealth(near)).toBe(hp - 1 - 2)
	end)

	it("triggers on ordinary and legendary crates before their end-wave item choice", function()
		for _, kind in { "Crate", "Legendary" } do
			clear()
			local id = target(8)
			local hp = Enemy.getHealth(id)
			collect(kind)
			expect(Enemy.getHealth(id)).toBe(hp - 1)
			expect(Weapons.isBurning(id)).toBe(true)
		end
	end)

	it("scales burn by Elemental and Damage while only the impact can crit", function()
		clear()
		Stats.addStats(me, { elementalDamage = 8, damage = 50, critChance = 200 })
		expect(Stats.getStat(me, "elementalDamage")).toBe(2) -- Chef receives only 25% of gains
		local id = target(8)
		local hp = Enemy.getHealth(id)
		collect("Fruit")
		expect(Enemy.getHealth(id)).toBe(hp - 3) -- round(round(1 * 1.5) * 1.5)
		world.advance(0.5)
		expect(Enemy.getHealth(id)).toBe(hp - 3 - 6) -- (1 + sausage 1 + Elemental 2) * 1.5
	end)

	it("triples only a non-elemental attack against an already-burning enemy", function()
		clear()
		local ordinary, base = hitWith(me, "Chopper", false)
		expect(ordinary).toBe(base)
		Enemy.killAll()
		local burning, burningBase = hitWith(me, "Chopper", true)
		expect(burning).toBe(math.round(burningBase * 3))
		Enemy.killAll()
		local elemental, elementalBase = hitWith(me, "Torch", true)
		expect(elemental).toBe(elementalBase) -- melee kind still has Elemental in its scaling list
	end)

	it("checks each explosion target before igniting it, rather than boosting fresh targets", function()
		clear()
		local burning, fresh = target(8), target(12)
		Weapons.structureBurn(me, burning, 1, 5, {})
		local hp, freshHp = Enemy.getHealth(burning), Enemy.getHealth(fresh)
		collect("Fruit")
		expect(Enemy.getHealth(burning)).toBe(hp - 3)
		expect(Enemy.getHealth(fresh)).toBe(freshHp - 1)
	end)

	it("applies the bonus to item explosions but not Elemental effects or stat strikes", function()
		clear()
		local id = target(8)
		Weapons.structureBurn(me, id, 1, 5, {})
		local hp = Enemy.getHealth(id)
		Weapons.explodeAt(me, root(), 10, {}, 1)
		world.advance(0.1)
		expect(Enemy.getHealth(id)).toBe(hp - 30)
		hp = Enemy.getHealth(id)
		Weapons.explodeAt(me, root(), 10, { elementalDamage = 0 }, 1)
		world.advance(0.1)
		expect(Enemy.getHealth(id)).toBe(hp - 10)
		hp = Enemy.getHealth(id)
		Weapons.strikeEnemy(me, id, 10, {}, 0)
		world.advance(0.1)
		expect(Enemy.getHealth(id)).toBe(hp - 10)
	end)

	it("does not lend its burning-target multiplier to a co-op peer", function()
		clear()
		peer.Character.HumanoidRootPart.Position = root()
		local actual, base = hitWith(peer, "Chopper", true)
		expect(actual).toBe(base)
		peer.Character.HumanoidRootPart.Position = Vector3.new(200, 0, 200)
		expect(#world.errors).toBe(0)
	end)
end)
