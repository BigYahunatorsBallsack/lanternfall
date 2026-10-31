-- End-to-end test of saved player data (Paket 12): loading on join (with a v1 profile upgraded to the current schema),
-- the lobby record, a finished run saved to the record, saving on leave and loading again on rejoin, the debug reset,
-- and kicks when a profile cannot be loaded or another server takes it. PlayerDataService runs on MemoryStore here
-- (same calls as ProfileStore); real saving needs Studio with API access in the test experience.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PlayerDataService = require(Services.PlayerDataService)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)

local store = MemoryStore.new(ProfileTemplate.new())
local function keyOf(userId)
	return Config.Save.keyPrefix .. tostring(userId)
end
store:put(keyOf(1), {
	schemaVersion = 1,
	embers = 0,
	talents = { toughness = 0, power = 0, reach = 0, greed = 0, rescuer = 0, rerolls = 0 },
	classes = { "BladeWarden", "SparkMage" },
	difficultyUnlocked = "Normal",
	cosmetics = { owned = {}, equipped = {} },
	stats = { runs = 3, kills = 900, bossKills = 1, bestTime = 640 },
	quests = { day = "", list = {} },
	streak = { lastLogin = 0, count = 0 },
	pass = { season = 1, xp = 0, premium = false, claimed = {} },
	receipts = {},
})
PlayerDataService.useStore(store)

runScript(ServerScriptService.Server, "init.server.luau")
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)
local WeaponService = require(Services.WeaponService)

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local ProfileCard = require(Client.Controllers.ProfileCard)

local function recordText()
	return world.gui("Lobby", "Record").Text
end

describe("player data", function()
	it("loads a v1 profile upgraded to the current schema", function()
		local data = PlayerDataService.get(me)
		expect(data ~= nil).toBe(true)
		expect(data.schemaVersion).toBe(ProfileTemplate.SCHEMA_VERSION)
		expect(data.stats.runs).toBe(3)
		expect(data.stats.wins).toBe(0)
		expect(data.stats.bestDanger).toBe(-1)
		expect(PlayerDataService.isLoaded(peer)).toBe(true)
		expect(PlayerDataService.get(peer).stats.runs).toBe(0)
	end)

	it("shows the saved record in the lobby", function()
		local info = ProfileCard.get()
		expect(info ~= nil).toBe(true)
		expect(info.runs).toBe(3)
		expect(info.saveMode).toBe("Memory")
		expect(recordText()).toBe("3 runs · 0 wins · best wave 0\n900 kills · 1 bosses")
		expect(world.gui("Lobby", "SaveMode").Visible).toBe(true)
	end)

	it("adds a won run to everyone's record and saves it", function()
		world.fireServerAs(me, "SetReady", true)
		world.fireServerAs(peer, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		WeaponService.setPaused(true)
		local saves = store.saves
		RunDirector.endRun("Victory")
		world.advance(0.5)
		local data = PlayerDataService.get(me)
		expect(data.stats.runs).toBe(4)
		expect(data.stats.wins).toBe(1)
		expect(data.stats.bestWave).toBe(1)
		expect(data.stats.bestDanger).toBe(0)
		local classId = RunDirector.getParticipantClassId(me)
		expect(data.characterStats[classId].wins).toBe(1)
		expect(PlayerDataService.get(peer).stats.wins).toBe(1)
		expect(store.saves >= saves + 2).toBe(true)
		expect(store:peek(keyOf(1)).stats.wins).toBe(1)
		expect(ProfileCard.get().wins).toBe(1)
	end)

	it("saves on leave and loads the same data on rejoin", function()
		PlayerDataService.get(peer).embers = 77
		world.removePlayer(peer)
		world.step()
		expect(PlayerDataService.isLoaded(peer)).toBe(false)
		expect(store.active[keyOf(2)]).toBe(nil)
		expect(store:peek(keyOf(2)).embers).toBe(77)

		peer = world.addPlayer("Peer", 2, false)
		world.advance(0.2)
		local data = PlayerDataService.get(peer)
		expect(data.embers).toBe(77)
		expect(data.stats.wins).toBe(1)
	end)

	it("resets the saved data with the debug button, only in the lobby", function()
		world.fireServerAs(peer, "DebugCommand", "ResetProfile")
		world.step()
		expect(PlayerDataService.get(peer).stats.runs).toBe(0)
		expect(PlayerDataService.get(peer).embers).toBe(0)
		expect(store:peek(keyOf(2)).stats.runs).toBe(0)
	end)

	it("kicks a player whose data cannot be loaded", function()
		store:refuse(keyOf(3), true)
		local third = world.addPlayer("Third", 3, false)
		world.advance(0.2)
		expect(third.KickMessage).toBe(Config.Save.kickLoadFailed)
		expect(third.Parent).toBe(nil)
		expect(PlayerDataService.isLoaded(third)).toBe(false)
	end)

	it("kicks a player when another server takes their profile", function()
		store:takeOver(keyOf(2))
		world.advance(0.2)
		expect(peer.KickMessage).toBe(Config.Save.kickSessionEnded)
		expect(PlayerDataService.isLoaded(peer)).toBe(false)
	end)
end)
