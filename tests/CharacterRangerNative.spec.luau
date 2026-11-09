--!strict
-- Original Ranger package and atomic legacy promotion; production services use the same prepared config after art approval.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Art = require(Shared.Util.CharacterArtwork)
local legacy = Config.Classes.NightWatch
local ranger = assert(legacy.pendingNative)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
local originallyLegacy = legacy.available
assert(
	Art.promote(
		legacy,
		ranger,
		{ image = "rbxassetid://123", height = 0.9, ground = 0.04, center = 0.5, nativeVersion = "1.2.0.1" }
	)
)
for _, id in ranger.startWeapons do
	assert(Config.Weapons[id], id).available = true
end
require(S.PlayerDataService).unlockAll(me)
require(S.SpawnDirector).setPaused(true)
Run.setHoldWaves(true)
local function start(id)
	if Run.isOngoing() then
		Run.endRun("Abandoned")
	end
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
	end
	assert(Run.selectClass(me, "NightWatch"))
	assert(Weapons.selectStartWeapon(me, "NightWatch", id))
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
end
describe("Native Ranger adoption", function()
	it("retains the saved id and legacy art until an original provenance-tagged image can promote it", function()
		expect(originallyLegacy).toBe(true)
		expect(ranger.id).toBe("NightWatch")
		expect(ranger.displayName).toBe("Ranger")
		expect(ranger.nativeCodeReady).toBe(true)
		local image = { image = "rbxassetid://123", height = 0.9, ground = 0.04, center = 0.5 }
		expect(Art.valid(image, true)).toBe(false)
		image.nativeVersion = "1.2.0.1"
		expect(Art.valid(image, true)).toBe(true)
		image.image = "rbxassetid://0"
		expect(Art.valid(image, true)).toBe(false)
	end)
	it("runs all fourteen original starts with the selected weapon and guaranteed original Pistol", function()
		for _, id in ranger.startWeapons do
			start(id)
			expect(#Weapons.getWeapons(me)).toBe(2)
			expect(Weapons.getWeapons(me)[2].id).toBe("WatchmanPistol")
			expect(Weapons.getWeapons(me)[1].id).toBe(id)
			expect(Weapons.getWeapons(me)[1].tier).toBe(ranger.startWeaponTiers[id])
			expect(next(Stats.getItemCounts(me))).toBe(nil)
			expect(ranger.stats.range).toBe(50)
			if id == "WatchmanPistol" then
				expect(Stats.getStat(me, "range")).toBe(60)
			end
			expect(Stats.getStat(me, "maxHp")).toBe(7.5)
			local _, maximum = require(S.CombatService).getHp(me)
			expect(maximum).toBe(7)
		end
	end)
	it("scales only the owner's gained stats using the original modifiers", function()
		assert(Stats.addStats(me, { rangedDamage = 4, maxHp = 4 }))
		expect(Stats.getStat(me, "rangedDamage")).toBe(6)
		expect(Stats.getStat(me, "maxHp")).toBe(10.5)
		expect(Stats.getStat(peer, "rangedDamage")).toBe(0)
		local ok, reason = Weapons.addWeapon(me, "RitualDirk", 1)
		expect(ok).toBe(false)
		expect(reason).toBe("CharacterRestriction")
		expect(#world.errors).toBe(0)
	end)
end)
