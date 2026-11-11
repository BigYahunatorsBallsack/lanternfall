--!strict
-- The receiving run server revalidates pet picks from untrusted teleport data before granting inventory.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
Config.Classes.BeastMaster.available = true -- test-only character-art gate
local S = game:GetService("ServerScriptService").Server.Services
local Data = require(S.PlayerDataService)
local template = require(S.PlayerDataService.ProfileTemplate).new()
table.insert(template.classes, "BeastMaster")
for _, rule in require(Shared.Config.PetAccess).items do
	if rule.challengeId then
		template.achievements["Brotato:" .. rule.challengeId] = true
	end
end
Data.useStore(require(S.PlayerDataService.MemoryStore).new(template))
require(S.PlaceService).useRole("Run", true, { name = "Test", hub = 111, run = 222 })
runScript(game:GetService("ServerScriptService").Server, "init.server.luau")
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
require(S.SpawnDirector).setPaused(true)
require(S.StructureService).setPaused(true)
Run.setHoldWaves(true)
local raw = require(Shared.Util.PlaceRules).runTicket({
	partyId = "pet-transport",
	leader = 1,
	group = { 1, 2, 3 },
	options = require(Shared.Util.DangerRules).defaultOptions(),
	picks = {
		[1] = { classId = "BeastMaster", petId = "BotOMine" },
		[2] = { classId = "BeastMaster", petId = "Ratzilla" },
		[3] = { classId = "BeastMaster", petId = "WatchmanPistol", weaponId = "WatchmanPistol" },
	},
})
local players = {
	world.addPlayer("Owner", 1, true, raw),
	world.addPlayer("Peer", 2, false, raw),
	world.addPlayer("Third", 3, false, raw),
}
world.advance(Config.Run.flow.allReadyCountdownSeconds + 2)
describe("Native pet run-place arrival", function()
	it("starts with a validated pet selection from the hub", function()
		expect(Run.getPhase()).toBe("Running")
		expect(Stats.getItemCounts(players[1]).BotOMine).toBe(1)
		expect(#Weapons.getWeapons(players[1])).toBe(0)
	end)
	it("rejects valid-pet-but-invalid-start and forged weapon picks, retaining the legitimate default", function()
		for _, player in { players[2], players[3] } do
			local items = Stats.getItemCounts(player)
			expect(items.BonkDog).toBe(1)
			expect(items.Ratzilla).toBe(1)
			expect(items.Lootworm).toBe(1)
			expect(#Weapons.getWeapons(player)).toBe(0)
		end
		expect(#world.errors).toBe(0)
	end)
end)
