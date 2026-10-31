-- End-to-end test of Paket 19 "First Night" on the hub (Paket 15): a new player is teleported to a run server with a
-- First Night ticket, a player in a party with others is not, and in Studio (no teleports) the hub runs it itself.
-- TeleportService is simulated (tests/helpers/RobloxMock); real server and client bootstraps, data in MemoryStore.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local PlaceRules = require(Shared.Util.PlaceRules)
local FirstNightService = require(Services.FirstNightService)
local PlayerDataService = require(Services.PlayerDataService)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)
PlayerDataService.useStore(MemoryStore.new(ProfileTemplate.new()))
local PlaceService = require(Services.PlaceService)
PlaceService.useRole("Hub", true, { name = "Test", hub = 111, run = 222 })
FirstNightService.allowStudio(true)

runScript(ServerScriptService.Server, "init.server.luau")
local RunDirector = require(Services.RunDirector)

local function isClass(id)
	return Config.Classes[id] ~= nil
end

local function isWeapon(id)
	return Config.Weapons[id] ~= nil
end

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")

describe("First Night on the hub", function()
	it("teleports a new player to a run server with a First Night ticket", function()
		world.advance(0.5)
		expect(#world.teleports).toBe(0)
		world.advance(Config.FirstNight.startDelaySeconds + 0.3)
		expect(#world.teleports).toBe(1)
		local teleport = world.teleports[1]
		expect(teleport.placeId).toBe(222)
		expect(teleport.players[1]).toBe(me)
		local ticket = PlaceRules.parseRunTicket(teleport.options.TeleportData, 1, 4, isClass, isWeapon)
		expect(ticket.options.firstNight).toBe(true)
		expect(ticket.options.enemyDamage).toBe(Config.FirstNight.options.enemyDamage)
		expect(RunDirector.getPhase()).toBe("Lobby") -- the hub does not run it
		expect(RunDirector.getRunOptions().firstNight).toBe(nil)
	end)

	it("runs it in the hub server when it cannot teleport (Studio)", function()
		PlaceService.useRole("Hub", false, { name = "Test", hub = 111, run = 222 })
		local peer = world.addPlayer("Peer", 2, false)
		world.advance(Config.FirstNight.startDelaySeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Countdown")
		world.advance(Config.Run.flow.countdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(RunDirector.getRunOptions().firstNight).toBe(true)
		local participants = RunDirector.getParticipants()
		expect(#participants).toBe(1)
		expect(participants[1]).toBe(peer)
	end)
end)
