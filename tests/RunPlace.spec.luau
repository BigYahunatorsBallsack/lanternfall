-- End-to-end test of the run place (Paket 15): players arrive with tickets from the hub, the run waits for the group
-- (or starts with who is here after the wait), takes over everyone's character and weapon pick and caps the danger
-- level; late players join the next run, and "Back to hub" teleports back to the hub server they came from (any hub
-- server if that one is full). TeleportService is simulated (tests/helpers/RobloxMock); real server and client
-- bootstraps, saved data in MemoryStore.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)
local PlaceRules = require(Shared.Util.PlaceRules)
local PlayerDataService = require(Services.PlayerDataService)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)
PlayerDataService.useStore(MemoryStore.new(ProfileTemplate.new()))
local PlaceService = require(Services.PlaceService)
PlaceService.useRole("Run", true, { name = "Test", hub = 111, run = 222 })

runScript(ServerScriptService.Server, "init.server.luau")
local RunDirector = require(Services.RunDirector)
local RunPlaceService = require(Services.RunPlaceService)
local SpawnDirector = require(Services.SpawnDirector)
local WeaponService = require(Services.WeaponService)

local TeleportService = game:GetService("TeleportService")
local weapon = Config.Classes.SparkMage.startWeapons[#Config.Classes.SparkMage.startWeapons]

local function ticket()
	local options = DangerRules.defaultOptions()
	options.danger = 5 -- nobody has it open: the run place caps it
	return PlaceRules.runTicket({
		partyId = "party-9",
		leader = 2,
		group = { 1, 2, 3 },
		options = options,
		picks = {
			[1] = { classId = "SparkMage", weaponId = weapon },
			[2] = { classId = "BladeWarden" },
		},
		hubJobId = "hub-job-1",
	})
end

local me = world.addPlayer("Owner", 1, true, ticket())
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local RunStateController = require(Client.Controllers.RunStateController)

local function status(): string
	return world.gui("Lobby", "Status"):FindFirstChildOfClass("TextLabel").Text
end

local function hasToast(prefix: string): boolean
	for _, object in world.gui("Notify"):GetDescendants() do
		if object.ClassName == "TextLabel" and string.sub(object.Text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local peer
local third

describe("run place", function()
	it("waits for the group and shows the way back", function()
		world.advance(1)
		expect(RunDirector.getPhase()).toBe("Lobby")
		expect(status()).toBe("Waiting for your group (1/3)...")
		expect(world.gui("Lobby", "BackToHub").Visible).toBe(true)
		expect(world.gui("Lobby", "Ready").Visible).toBe(true)
		expect(world.gui("Lobby", "HubActions").Visible).toBe(false)
		peer = world.addPlayer("Peer", 2, false, ticket())
		world.advance(1)
		expect(RunDirector.getPhase()).toBe("Lobby")
		expect(status()).toBe("Waiting for your group (2/3)...")
	end)

	it("starts with whoever is here after the wait, with their picks and a capped danger level", function()
		world.advance(Config.Places.runPlace.waitForGroupSeconds)
		expect(RunPlaceService.hasLaunched()).toBe(true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		expect(#RunDirector.getParticipants()).toBe(2)
		expect(RunDirector.getParticipantClassId(me)).toBe("SparkMage")
		expect(RunDirector.getParticipantClassId(peer)).toBe("BladeWarden")
		expect(WeaponService.getWeapons(me)[1].id).toBe(weapon)
		expect(RunDirector.getRunOptions().danger).toBe(0)
	end)

	it("queues a late player for the next run and keeps everyone in the run", function()
		third = world.addPlayer("Third", 3, false, ticket())
		world.advance(0.5)
		expect(RunStateController.getPlayer(3).ready).toBe(true)
		expect(RunDirector.getParticipantState(third)).toBe(nil)
		world.fireServerAs(me, "ReturnToHub")
		world.advance(0.3)
		expect(hasToast("Not possible during your run")).toBe(true)
		expect(#world.teleports).toBe(0)
	end)

	it("sends a player back to their hub server, or any hub server if it is full", function()
		world.fireServerAs(third, "ReturnToHub")
		world.advance(0.3)
		expect(#world.teleports).toBe(1)
		local teleport = world.teleports[1]
		expect(teleport.placeId).toBe(111)
		expect(teleport.players[1]).toBe(third)
		expect(teleport.options.ServerInstanceId).toBe("hub-job-1")
		local back = PlaceRules.parseHubTicket(teleport.options.TeleportData, 3, 4)
		expect(back.partyId).toBe("party-9")
		expect(back.leader).toBe(2)
		expect(RunStateController.getPlayer(3).ready).toBe(false)
		TeleportService.TeleportInitFailed:Fire(third, Enum.TeleportResult.GameFull, "Full")
		world.advance(Config.Places.teleport.retryDelaySeconds + 0.3)
		expect(#world.teleports).toBe(2)
		expect(world.teleports[2].options.ServerInstanceId).toBe(nil)
		world.removePlayer(third)
		world.advance(0.3)
	end)

	it("offers Back to hub on the results", function()
		RunDirector.endRun("Victory")
		world.advance(0.3)
		local button = world.gui("Results", "BackToHub")
		expect(button.Visible).toBe(true)
		world.click(button)
		world.advance(0.3)
		expect(#world.teleports).toBe(3)
		expect(world.teleports[3].players[1]).toBe(me)
		expect(button.Text).toBe("TELEPORTING...")
	end)

	it("ran without script errors", function()
		expect(#world.errors).toBe(0)
	end)
end)
