--!strict
-- Native Ghost access, personal persistence, exact weapon-local damage and defense through real services.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
-- Sprite delivery is separate; expose the code package only inside this runtime fixture.
Config.Classes.Ghost.available = true
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Data = require(S.PlayerDataService)
local Run = require(S.RunDirector)
local Weapons = require(S.WeaponService)
local Stats = require(S.StatService)
local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
local Choice = require(Client.Controllers.CharacterChoice)
require(S.SpawnDirector).setPaused(true)
Weapons.setPaused(true)
Run.setHoldWaves(true)

describe("Native Ghost package", function()
	it("starts locked on both server and client without an invented purchase requirement", function()
		expect(Data.ownsClass(me, "Ghost")).toBe(false)
		expect(Choice.isUnlocked("Ghost")).toBe(false)
		expect(Run.selectClass(me, "Ghost")).toBe(false)
		expect(Config.Progress.characterPrices.Ghost).toBe(nil)
	end)

	it("unlocks only the triggering profile at exactly sixty Dodge and keeps the completed flag", function()
		Run.setReady(me, true)
		Run.setReady(peer, true)
		world.advance(3.5)
		Stats.addStats(me, { dodge = 59 - Stats.getStat(me, "dodge") })
		expect(Data.ownsClass(me, "Ghost")).toBe(false)
		Stats.addStats(me, { dodge = 1 })
		expect(Data.ownsClass(me, "Ghost")).toBe(true)
		expect(Data.isUnlocked(me, "characters", "Ghost")).toBe(true)
		expect(Choice.isUnlocked("Ghost")).toBe(true)
		expect(Data.ownsClass(peer, "Ghost")).toBe(false)
		Stats.addStats(me, { dodge = -60 })
		expect(Data.ownsClass(me, "Ghost")).toBe(true)
		Run.endRun("Abandoned")
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
		expect(Data.ownsClass(me, "Ghost")).toBe(true)
	end)

	it("uses original starting alternatives and still locks Railgun until the required Wounded win", function()
		assert(Run.selectClass(me, "Ghost"))
		expect(Config.Classes.Ghost.nativeCodeReady).toBe(true)
		expect(Config.Classes.Ghost.description).toBe(
			"+10 Damage with Ethereal weapons\n+30 % Dodge\nDodge is capped at 90%\n-100 Armor"
		)
		expect(require(Shared.Config.CharacterUnlocks).Ghost.requirement).toBe("Reach +60 % Dodge")
		expect(#Config.Classes.Ghost.startWeapons).toBe(4)
		expect(Weapons.selectStartWeapon(me, "Ghost", "Railgun")).toBe(false)
		expect(Weapons.selectStartWeapon(me, "Ghost", "GhostScepter")).toBe(true)
		assert(
			Data.recordRun(
				me,
				{ won = true, wave = 20, danger = 0, classId = "Wounded", kills = 0, bossKills = 0, seconds = 1200 }
			)
		)
		expect(Weapons.selectStartWeapon(me, "Ghost", "Railgun")).toBe(true)
		assert(Weapons.selectStartWeapon(me, "Ghost", "GhostScepter"))
	end)

	it("adds ten flat damage only to Ethereal weapons, with native armor and a ninety-percent dodge cap", function()
		Run.setReady(me, true)
		Run.setReady(peer, true)
		world.advance(3.5)
		local held = Weapons.getWeapons(me)
		expect(#held).toBe(1)
		expect(held[1].id).toBe("GhostScepter")
		expect(Stats.getStat(me, "dodge")).toBe(30)
		expect(Stats.getStat(me, "armor")).toBe(-100)
		local raw = Stats.getSheet(me)
		local sheet = require(Shared.Util.CharacterRules).weaponSheet("Ghost", raw)
		local compute = require(S.WeaponService.WeaponStats).compute
		local ghost = compute(Config.Weapons.GhostScepter, 1, sheet, nil, Config.Player.minWeaponCooldown)
		local plain = compute(Config.Weapons.GhostScepter, 1, raw, nil, Config.Player.minWeaponCooldown)
		expect(ghost.damage).toBeNear(plain.damage + 10)
		local ordinary = compute(Config.Weapons.WatchmanPistol, 1, sheet, nil, Config.Player.minWeaponCooldown)
		local ordinaryPlain = compute(Config.Weapons.WatchmanPistol, 1, raw, nil, Config.Player.minWeaponCooldown)
		expect(ordinary.damage).toBe(ordinaryPlain.damage)
		expect(Stats.getStat(peer, "armor")).toBe(0)
		local statMath = require(Shared.Util.StatMath)
		expect(statMath.dodgeChance(200, raw.dodgeCap)).toBeNear(0.9)
		local preview =
			require(Client.UI.OfferText).stats("GhostScepter", 1, require(Client.Controllers.StatsController).get())
		expect(preview.damage).toBe(ghost.damage)
	end)

	it("uses Ghost's ninety-percent cap in actual hit resolution and retains the ordinary cap for its peer", function()
		local Combat = require(S.CombatService)
		Stats.addStats(me, { dodge = 200 - Stats.getStat(me, "dodge") })
		Stats.addStats(peer, { dodge = 200 - Stats.getStat(peer, "dodge") })
		local random = require(S.RandomService)
		local original = random.number
		local roll = 0.89
		random.number = function()
			return roll
		end
		local ok, err = pcall(function()
			local lost, dodged = Combat.damagePlayer(me, 1)
			expect(lost).toBe(0)
			expect(dodged).toBe(true)
			lost, dodged = Combat.damagePlayer(peer, 1)
			expect(lost > 0).toBe(true)
			expect(dodged).toBe(false)
			roll = 0.9
			world.advance(0.5) -- Brotato: a dodge starts the minimum hit protection too
			lost, dodged = Combat.damagePlayer(me, 1)
			expect(lost > 0).toBe(true)
			expect(dodged).toBe(false)
		end)
		random.number = original
		assert(ok, err)
	end)

	it("retains character and weapon challenge flags when the profile is saved and loaded again", function()
		Stats.addStats(peer, { critChance = 100 })
		expect(Data.ownsClass(peer, "Ghost")).toBe(true)
		expect(Data.isUnlocked(peer, "weapons", "VorpalSword")).toBe(true)
		Run.endRun("Abandoned")
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
		world.removePlayer(peer)
		world.step()
		peer = world.addPlayer("Peer", 2, false)
		world.advance(0.2)
		expect(Data.ownsClass(peer, "Ghost")).toBe(true)
		expect(Data.isUnlocked(peer, "weapons", "VorpalSword")).toBe(true)
		expect(table.find(Data.get(peer).classes, "Ghost")).toBe(nil)
	end)
end)
