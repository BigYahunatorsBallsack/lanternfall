--!strict
-- Original Mage package and atomic legacy promotion; production services use the same prepared config after art approval.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Art = require(Shared.Util.CharacterArtwork)
local legacy = Config.Classes.SparkMage
local mage = assert(legacy.pendingNative)
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
		mage,
		{ image = "rbxassetid://123", height = 0.9, ground = 0.04, center = 0.5, nativeVersion = "1.2.0.1" }
	)
)
for _, id in mage.startWeapons do
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
	assert(Run.selectClass(me, "SparkMage"))
	assert(Weapons.selectStartWeapon(me, "SparkMage", id))
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
end
describe("Native Mage adoption", function()
	it("retains the saved id and legacy art until an original provenance-tagged image can promote it", function()
		expect(originallyLegacy).toBe(true)
		expect(mage.id).toBe("SparkMage")
		expect(mage.displayName).toBe("Mage")
		expect(mage.nativeCodeReady).toBe(true)
		local image = { image = "rbxassetid://123", height = 0.9, ground = 0.04, center = 0.5 }
		expect(Art.valid(image, true)).toBe(false)
		image.nativeVersion = "1.2.0.1"
		expect(Art.valid(image, true)).toBe(true)
		image.image = "rbxassetid://0"
		expect(Art.valid(image, true)).toBe(false)
	end)
	it("runs all twelve original starts with Snake and Scared Sausage", function()
		for _, id in mage.startWeapons do
			start(id)
			expect(#Weapons.getWeapons(me)).toBe(1)
			expect(Weapons.getWeapons(me)[1].id).toBe(id)
			expect(Stats.getItemCounts(me).AshSerpent).toBe(1)
			expect(Stats.getItemCounts(me).SmolderingWick).toBe(1)
		end
	end)
	it("scales only the owner's gained stats using the original modifiers", function()
		assert(Stats.addStats(me, { elementalDamage = 4, engineering = 4, meleeDamage = 4, rangedDamage = 4 }))
		expect(Stats.getStat(me, "elementalDamage")).toBe(5)
		expect(Stats.getStat(me, "engineering")).toBe(2)
		expect(Stats.getStat(me, "meleeDamage")).toBe(0)
		expect(Stats.getStat(me, "rangedDamage")).toBe(0)
		expect(Stats.getStat(peer, "elementalDamage")).toBe(0)
		expect(#world.errors).toBe(0)
	end)
end)
