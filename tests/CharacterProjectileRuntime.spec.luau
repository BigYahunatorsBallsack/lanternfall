--!strict
-- Real ranged starting families and personal material reloads; pending artwork is enabled only inside this isolated fixture.
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
for _, id in { "Blunderbuss", "Javelin", "TranqRifle", "HarpoonGun" } do
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
local function target(share, distance)
	local at = me.Character.HumanoidRootPart.Position
	local id = assert(Enemy.spawn("Brute", at.X + (distance or 5), at.Z, 100, 1, nil, nil, 0))
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

local Snapshot = require(Shared.Net.Snapshot)
local statuses = {}
require(Shared.Net).onClient("EnemySnapshot", function(packet)
	local columns = Snapshot.newColumns()
	local count = Snapshot.decodeInto(packet, columns, 1)
	for i = 1, count do
		statuses[columns.ids[i]] = columns.statuses[i]
	end
end)
local function slowed(id)
	return bit32.band(statuses[id] or 0, Snapshot.STATUS_SLOWED) ~= 0
end
local function atRoot(x, z, kind, speed)
	local at = me.Character.HumanoidRootPart.Position
	return assert(Enemy.spawn(kind or "Shadeling", at.X + x, at.Z + z, 100, 1, nil, nil, speed or 1))
end
describe("Native ranged starts through real services", function()
	it("attacks and credits its owner at every valid source tier", function()
		for _, id in { "Blunderbuss", "Javelin", "TranqRifle", "HarpoonGun" } do
			for tier = Config.Weapons[id].minTier, 4 do
				clear()
				target(nil, if id == "HarpoonGun" then 40 else 5)
				assert(Weapons.addWeapon(me, id, tier))
				world.advance(0.7)
				expect(Weapons.getDamageStats(me)[id].damage > 0).toBe(true)
			end
		end
	end)
	it("applies Javelin's fifth-volley Crit Chance and resets on the next volley", function()
		clear()
		assert(Stats.addStats(me, { attackSpeed = 400, critChance = 100 }))
		local id = target()
		local hp = Enemy.getHealth(id)
		assert(Weapons.addWeapon(me, "Javelin", 1))
		world.advance(1)
		expect(hp - Enemy.getHealth(id)).toBe(4 * 8 + 20)
	end)
	it("slows only enemies near a Tranq impact, exposes snapshot status and recovers after its hold", function()
		clear()
		target()
		local near = atRoot(5, 8)
		local far = atRoot(5, 60)
		assert(Weapons.addWeapon(me, "TranqRifle", 1))
		world.advance(0.3)
		clearWeapons()
		expect(slowed(near)).toBe(true)
		expect(slowed(far)).toBe(false)
		world.advance(3)
		expect(slowed(near)).toBe(false)
	end)
	it("pulls with Harpoon and slows a nearby enemy that its damaging projectile never hits", function()
		clear()
		local id = target(nil, 40)
		local near = atRoot(20, 5)
		local hp = Enemy.getHealth(near)
		local before = Enemy.getPosition(id)
		assert(Weapons.addWeapon(me, "HarpoonGun", 2))
		world.advance(0.3)
		clearWeapons()
		expect(Enemy.getPosition(id).X < before.X).toBe(true)
		expect(slowed(near)).toBe(true)
		expect(Enemy.getHealth(near)).toBe(hp)
		world.advance(1.2)
		expect(slowed(near)).toBe(false)
	end)
	it("reloads only the actual collector's Blunderbuss from a real material pickup", function()
		clear()
		require(S.ExperienceService).setPaused(false)
		local at = me.Character.HumanoidRootPart.Position
		peer.Character.HumanoidRootPart.Position = at + Vector3.new(0, 0, 100)
		local theirs = peer.Character.HumanoidRootPart.Position
		target(nil, 20)
		assert(Enemy.spawn("Brute", theirs.X + 20, theirs.Z, 100, 1, nil, nil, 0))
		assert(Weapons.addWeapon(me, "Blunderbuss", 2))
		assert(Weapons.addWeapon(peer, "Blunderbuss", 2))
		world.advance(0.4)
		local own = Weapons.getDamageStats(me).Blunderbuss.damage
		local other = Weapons.getDamageStats(peer).Blunderbuss.damage
		local material = assert(Enemy.spawn("Shadeling", at.X, at.Z, 1, 1, nil, nil, 0))
		Enemy.damage(material, math.huge, peer)
		world.advance(0.3)
		expect(Weapons.getDamageStats(me).Blunderbuss.damage > own).toBe(true)
		expect(Weapons.getDamageStats(peer).Blunderbuss.damage).toBe(other)
		require(S.ExperienceService).setPaused(true)
		expect(#world.errors).toBe(0)
	end)
end)
