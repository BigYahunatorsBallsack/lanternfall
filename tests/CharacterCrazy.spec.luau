--!strict
-- Crazy is an available native package: original start choices, fixed extra Knife and weapon-local range.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
-- Exercise the complete code package while its separately assigned sprite delivery is pending.
assert(Config.Classes.Crazy.nativeCodeReady)
Config.Classes.Crazy.available = true
local Rules = require(Shared.Util.CharacterRules)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run = require(S.RunDirector)
local Weapons = require(S.WeaponService)
local Stats = require(S.StatService)
local WeaponStats = require(S.WeaponService.WeaponStats)
local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
local Preview = require(Client.UI.OfferText)
require(S.SpawnDirector).setPaused(true)
Weapons.setPaused(true)
Run.setHoldWaves(true)

describe("Native Crazy package", function()
	it("is available by default with every source starting choice and original description", function()
		local class = Config.Classes.Crazy
		expect(class.available).toBe(true)
		expect(class.free).toBe(true)
		expect(class.displayName).toBe("Crazy")
		expect(#class.startWeapons).toBe(8)
		expect(class.description).toBe(
			"+100 Range with Precise weapons\n+25 % Attack Speed\nYou start with 1 Knife\n-30 % Dodge\n-10 Engineering\n-10 Ranged Damage"
		)
		assert(world.gui("Lobby", "Crazy"))
		world.fireServerAs(me, "SelectClass", "Crazy")
		world.fireServerAs(me, "SelectStartWeapon", "Crazy", "Shuriken")
		Run.setReady(me, true)
		Run.setReady(peer, true)
		world.advance(3.5)
		expect(Run.getParticipantClassId(me)).toBe("Crazy")
	end)

	it("grants the chosen weapon plus a Knife and keeps its global stats separate from teammates", function()
		local held = Weapons.getWeapons(me)
		expect(#held).toBe(2)
		expect(held[1].id).toBe("Shuriken")
		expect(held[2].id).toBe("RitualDirk")
		expect(Stats.getStat(me, "attackSpeed")).toBe(25)
		expect(Stats.getStat(me, "dodge")).toBe(-30)
		expect(Stats.getStat(me, "engineering")).toBe(-10)
		expect(Stats.getStat(me, "rangedDamage")).toBe(-10)
		expect(Stats.getStat(me, "range")).toBe(0)
		expect(Stats.getStat(peer, "attackSpeed")).toBe(0)
	end)

	it("shows the same precise-only full range bonus in combat and shop previews, including a full sync", function()
		world.fireServerAs(me, "RequestSync")
		local clientSheet = require(Client.Controllers.StatsController).get()
		local serverSheet = Rules.weaponSheet("Crazy", Stats.getSheet(me))
		for _, id in { "RitualDirk", "Shuriken", "WatchmanPistol" } do
			local weapon = Config.Weapons[id]
			local combat = WeaponStats.compute(weapon, 1, serverSheet, nil, Config.Player.minWeaponCooldown)
			local preview = Preview.stats(id, 1, clientSheet)
			expect(preview.range).toBe(combat.range)
			expect(preview.cooldown).toBe(combat.cooldown)
			local ordinary = WeaponStats.compute(weapon, 1, Stats.getSheet(me), nil, Config.Player.minWeaponCooldown)
			expect(combat.range - ordinary.range).toBe(if id == "WatchmanPistol" then 0 else 10)
		end
	end)
end)
