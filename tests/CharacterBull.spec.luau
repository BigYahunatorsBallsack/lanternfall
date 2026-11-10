--!strict
-- Bull's native hurt explosion in real services; the package stays unavailable until its full access/UI slice lands.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
Config.Classes.Bull.available = true -- test-only access to the in-progress package
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run = require(S.RunDirector)
local Stats = require(S.StatService)
local Combat = require(S.CombatService)
local Weapons = require(S.WeaponService)
local Enemy = require(S.EnemySim)
local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
require(S.PlayerDataService).unlockAll(me)
assert(Run.selectClass(me, "Bull"))
require(S.SpawnDirector).setPaused(true)
require(S.ExperienceService).setPaused(true)
Run.setHoldWaves(true)
Run.setReady(me, true)
Run.setReady(peer, true)
world.advance(3.5)
for _, weapon in Weapons.getWeapons(peer) do
	Weapons.removeWeapon(peer, weapon.uid)
end
Enemy.killAll()

local function target(distance)
	local root = me.Character.HumanoidRootPart.Position
	return assert(Enemy.spawn("Brute", root.X + distance, root.Z, 100, 1))
end
local function setStats(values)
	local delta = {}
	for _, stat in
		{ "damage", "meleeDamage", "rangedDamage", "elementalDamage", "explosionDamage", "critChance", "lifeSteal" }
	do
		delta[stat] = (values[stat] or 0) - Stats.getStat(me, stat)
	end
	Stats.addStats(me, delta)
end

describe("Native Bull hurt explosion", function()
	it("starts without weapons and keeps fixed stats separate from regeneration gain modifiers", function()
		expect(#Weapons.getWeapons(me)).toBe(0)
		expect(Weapons.getMaxWeapons(me)).toBe(0)
		expect(Weapons.addWeapon(me, "WatchmanPistol")).toBe(false)
		expect(Stats.getStat(me, "maxHp")).toBe(30)
		expect(Stats.getStat(me, "armor")).toBe(10)
		expect(Stats.getStat(me, "hpRegen")).toBe(22.5)
		Stats.addStats(me, { hpRegen = 2 })
		expect(Stats.getStat(me, "hpRegen")).toBe(25.5)
	end)
	it("explodes once for actual damage, affects nearby enemies and does not life steal", function()
		setStats({ critChance = -100, lifeSteal = 100 })
		local near, far = target(5), target(40)
		local nearHp, farHp = Enemy.getHealth(near), Enemy.getHealth(far)
		local hp = Combat.getHp(me)
		Combat.drainPlayer(me, 1)
		expect(Enemy.getHealth(near)).toBe(nearHp - 30)
		expect(Enemy.getHealth(far)).toBe(farHp)
		expect(Combat.getHp(me)).toBe(hp - 1)
		Combat.drainPlayer(peer, 1)
		expect(Enemy.getHealth(near)).toBe(nearHp - 30)
	end)
	it("uses the native triple scaling, additive percentage bonuses and x1.5 critical damage", function()
		Enemy.killAll()
		setStats({
			meleeDamage = 2,
			rangedDamage = 4,
			elementalDamage = 5,
			damage = 20,
			explosionDamage = 50,
			critChance = 100,
		})
		local enemy = target(5)
		local hp = Enemy.getHealth(enemy)
		Combat.drainPlayer(me, 1)
		expect(Enemy.getHealth(enemy)).toBe(hp - 161) -- round(round(63 * 1.7) * 1.5)
	end)
	it("does not explode on an absorbed or dodged hit", function()
		Enemy.killAll()
		local enemy = target(5)
		local hp = Enemy.getHealth(enemy)
		Combat.setHitShields(me, 1)
		expect(Combat.drainPlayer(me, 1)).toBe(0)
		expect(Enemy.getHealth(enemy)).toBe(hp)
		Stats.addStats(me, { dodge = 200 })
		local random = require(S.RandomService)
		local original = random.number
		random.number = function()
			return 0.5
		end
		local ok, err = pcall(function()
			local lost, dodged = Combat.damagePlayer(me, 1)
			expect(lost).toBe(0)
			expect(dodged).toBe(true)
			expect(Enemy.getHealth(enemy)).toBe(hp)
		end)
		random.number = original
		assert(ok, err)
	end)
	it("resolves the lethal hurt explosion before its owner is marked down", function()
		Enemy.killAll()
		setStats({ critChance = -100 })
		local enemy = target(5)
		local hp = Enemy.getHealth(enemy)
		Combat.drainPlayer(me, 1000)
		expect(Enemy.getHealth(enemy)).toBe(hp - 30)
		expect(Run.getParticipantState(me)).toBe("Down")
	end)
end)
