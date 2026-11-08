--!strict
-- Brawler's free native package, locked starting alternatives and persistent native weapon unlocks in real services.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
-- Exercise the complete code package while its separately assigned sprite delivery is pending.
assert(Config.Classes.Brawler.nativeCodeReady)
Config.Classes.Brawler.available = true
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Data = require(S.PlayerDataService)
local Run = require(S.RunDirector)
local Weapons = require(S.WeaponService)
local Stats = require(S.StatService)
local WeaponStats = require(S.WeaponService.WeaponStats)
local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.fireServerAs(me, "SelectClass", "Brawler")
world.advance(0.3)
require(S.SpawnDirector).setPaused(true)
Weapons.setPaused(true)
Run.setHoldWaves(true)

describe("Native Brawler package", function()
	it("allows free native Hand but rejects locked Claw both in the UI and on the server", function()
		expect(Config.Classes.Brawler.available).toBe(true)
		expect(Config.Classes.Brawler.free).toBe(true)
		expect(Data.isUnlocked(me, "weapons", "TithePalm")).toBe(true)
		expect(Data.isUnlocked(me, "weapons", "Claw")).toBe(false)
		expect(world.gui("Lobby", "Start_Claw").LockLabel.Visible).toBe(true)
		expect(Weapons.selectStartWeapon(me, "Brawler", "Claw")).toBe(false)
		expect(Weapons.selectStartWeapon(me, "Brawler", "TithePalm")).toBe(true)
	end)

	it("unlocks Claw from a recorded Cryptid win only for that profile", function()
		assert(
			Data.recordRun(
				me,
				{ won = true, wave = 20, danger = 0, classId = "Cryptid", kills = 0, bossKills = 0, seconds = 1200 }
			)
		)
		expect(Data.isUnlocked(me, "weapons", "Claw")).toBe(true)
		expect(Data.isUnlocked(peer, "weapons", "Claw")).toBe(false)
		expect(world.gui("Lobby", "Start_Claw").LockLabel.Visible).toBe(false)
		expect(Weapons.selectStartWeapon(me, "Brawler", "Claw")).toBe(true)
		assert(Weapons.selectStartWeapon(me, "Brawler", "TithePalm"))
	end)

	it("grants the selected weapon and extra Fist, with attack speed only for Unarmed weapons", function()
		Run.setReady(me, true)
		Run.setReady(peer, true)
		world.advance(3.5)
		local held = Weapons.getWeapons(me)
		expect(#held).toBe(2)
		expect(held[1].id).toBe("TithePalm")
		expect(held[2].id).toBe("BrassKnuckles")
		expect(Stats.getStat(me, "attackSpeed")).toBe(0)
		expect(Stats.getStat(me, "dodge")).toBe(18) -- native +15 and the two-Unarmed set bonus of +3
		expect(Stats.getStat(me, "range")).toBe(-50)
		expect(Stats.getStat(me, "rangedDamage")).toBe(-50)
		local sheet = require(Shared.Util.CharacterRules).weaponSheet("Brawler", Stats.getSheet(me))
		local hand = WeaponStats.compute(Config.Weapons.TithePalm, 1, sheet, nil, Config.Player.minWeaponCooldown)
		local plain =
			WeaponStats.compute(Config.Weapons.TithePalm, 1, Stats.getSheet(me), nil, Config.Player.minWeaponCooldown)
		expect(hand.cooldown).toBeNear(plain.cooldown / 1.5)
	end)

	it("persists the native 100-crit challenge after the triggering bonus disappears", function()
		expect(Data.isUnlocked(me, "weapons", "VorpalSword")).toBe(false)
		Stats.addStats(me, { critChance = 100 })
		expect(Data.isUnlocked(me, "weapons", "VorpalSword")).toBe(true)
		Stats.addStats(me, { critChance = -100 })
		expect(Data.isUnlocked(me, "weapons", "VorpalSword")).toBe(true)
		expect(Data.isUnlocked(peer, "weapons", "VorpalSword")).toBe(false)
	end)
end)
