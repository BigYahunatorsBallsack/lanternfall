-- End-to-end test of the hub's teleports in the published game (Paket 15): Play solo and the party run reserve a run
-- server and teleport with a ticket (group, options, character picks), failed teleports are retried and then given
-- up, and players coming back from the run place form their party again. TeleportService is simulated
-- (tests/helpers/RobloxMock records the teleports); real server and client bootstraps, saved data in MemoryStore.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local PlaceRules = require(Shared.Util.PlaceRules)
local PlayerDataService = require(Services.PlayerDataService)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)
PlayerDataService.useStore(MemoryStore.new(ProfileTemplate.new()))
local PlaceService = require(Services.PlaceService)
PlaceService.useRole("Hub", true, { name = "Test", hub = 111, run = 222 })
game.JobId = "hub-job-1"

runScript(ServerScriptService.Server, "init.server.luau")
local PartyService = require(Services.PartyService)
local RunDirector = require(Services.RunDirector)

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
local third = world.addPlayer("Third", 3, false)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local TeleportService = game:GetService("TeleportService")

local function isClass(id)
	return Config.Classes[id] ~= nil
end

local function isWeapon(id)
	return Config.Weapons[id] ~= nil
end

local function hasToast(prefix: string): boolean
	for _, object in world.gui("Notify"):GetDescendants() do
		if object.ClassName == "TextLabel" and string.sub(object.Text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function lastTeleport()
	return world.teleports[#world.teleports]
end

describe("hub teleports", function()
	it("sends a solo player to a reserved run server with their pick", function()
		world.click(world.gui("Lobby", "Play"))
		world.advance(0.3)
		expect(#world.teleports).toBe(1)
		local teleport = lastTeleport()
		expect(teleport.placeId).toBe(222)
		expect(#teleport.players).toBe(1)
		expect(teleport.players[1]).toBe(me)
		expect(string.sub(teleport.options.ReservedServerAccessCode, 1, 10)).toBe("access-222")
		local ticket = PlaceRules.parseRunTicket(teleport.options.TeleportData, 1, 4, isClass, isWeapon)
		expect(ticket ~= nil).toBe(true)
		expect(#ticket.group).toBe(1)
		expect(ticket.picks[1].classId).toBe(RunDirector.getSelectedClassId(me))
		expect(ticket.hubJobId).toBe("hub-job-1")
		expect(PartyService.isTeleporting(me)).toBe(true)
		expect(world.gui("Lobby", "Play").Text).toBe("TELEPORTING...")
		expect(RunDirector.getPhase()).toBe("Lobby") -- nothing runs on the hub
	end)

	it("ignores more presses while teleporting and gives up after the timeout", function()
		world.fireServerAs(me, "PlayFromHub", "Solo")
		world.advance(0.3)
		expect(#world.teleports).toBe(1)
		world.advance(Config.Places.teleport.timeoutSeconds)
		expect(PartyService.isTeleporting(me)).toBe(false)
		expect(hasToast("The teleport took too long")).toBe(true)
		expect(world.gui("Lobby", "Play").Text).toBe("PLAY SOLO")
	end)

	it("teleports a party together with everyone's character and weapon", function()
		PlayerDataService.unlockAll(third)
		world.advance(0.3)
		world.fireServerAs(third, "SelectClass", "SparkMage")
		local weapon = Config.Classes.SparkMage.startWeapons[#Config.Classes.SparkMage.startWeapons]
		world.fireServerAs(third, "SelectStartWeapon", "SparkMage", weapon)
		world.fireServerAs(peer, "InviteToParty", 3)
		world.fireServerAs(third, "AnswerInvite", 2, true)
		world.fireServerAs(peer, "SetRunOptions", 1, true, 100, 100, 100, 100)
		world.advance(0.3)
		world.fireServerAs(peer, "PlayFromHub", "Party")
		world.advance(Config.Places.party.startCountdownSeconds + 0.5)
		expect(#world.teleports).toBe(2)
		local teleport = lastTeleport()
		expect(#teleport.players).toBe(2)
		local ticket = PlaceRules.parseRunTicket(teleport.options.TeleportData, 3, 4, isClass, isWeapon)
		expect(ticket.leader).toBe(2)
		expect(ticket.picks[3].classId).toBe("SparkMage")
		expect(ticket.picks[3].weaponId).toBe(weapon)
		expect(ticket.options.danger).toBe(1)
		expect(ticket.options.endless).toBe(true)
		expect(#ticket.partyId > 0).toBe(true)
		-- they arrive on the run place: gone from the hub
		world.removePlayer(peer)
		world.removePlayer(third)
		world.advance(0.3)
		expect(#PartyService.getView(me).players).toBe(0)
	end)

	it("retries a failing teleport, then tells the player", function()
		world.teleportError = "HTTP 503 (Service Unavailable)"
		world.fireServerAs(me, "PlayFromHub", "Solo")
		world.advance(Config.Places.teleport.retryDelaySeconds * Config.Places.teleport.attempts + 0.5)
		world.teleportError = nil
		expect(#world.teleports).toBe(2)
		expect(PartyService.isTeleporting(me)).toBe(false)
		expect(hasToast("The teleport failed")).toBe(true)
	end)

	it("tries again when Roblox reports a flood, and stops on a refusal", function()
		world.fireServerAs(me, "PlayFromHub", "Solo")
		world.advance(0.3)
		expect(#world.teleports).toBe(3)
		TeleportService.TeleportInitFailed:Fire(me, Enum.TeleportResult.Flooded, "Too many teleports")
		world.advance(Config.Places.teleport.retryDelaySeconds + 0.3)
		expect(#world.teleports).toBe(4)
		expect(PartyService.isTeleporting(me)).toBe(true)
		TeleportService.TeleportInitFailed:Fire(me, Enum.TeleportResult.Unauthorized, "Not allowed")
		world.advance(0.3)
		expect(#world.teleports).toBe(4)
		expect(PartyService.isTeleporting(me)).toBe(false)
	end)

	it("puts a party back together when it comes back from the run place", function()
		local ticket = PlaceRules.hubTicket({ partyId = "run-7", leader = 5, group = { 4, 5 } })
		local four = world.addPlayer("Four", 4, false, ticket)
		world.advance(0.3)
		expect(#PartyService.getMembers(four)).toBe(1)
		local five = world.addPlayer("Five", 5, false, ticket)
		world.advance(0.3)
		expect(#PartyService.getMembers(four)).toBe(2)
		expect(PartyService.getLeader(four)).toBe(5)
		expect(PartyService.getLeader(five)).toBe(5)
		-- a stranger with a forged ticket for that party does not get in
		local forged = PlaceRules.hubTicket({ partyId = "run-7", leader = 5, group = { 4, 5 } })
		local six = world.addPlayer("Six", 6, false, forged)
		world.advance(0.3)
		expect(#PartyService.getMembers(six)).toBe(1)
	end)

	it("ran without script errors", function()
		expect(#world.errors).toBe(0)
	end)
end)
