-- End-to-end test of the hub lobby in Studio (Paket 15): parties with invites, the leader's danger level, Play solo,
-- Party run, Quick join and the portals. Studio cannot teleport, so each group's run starts in the hub server itself.
-- Real server and client bootstraps in a simulated Roblox (tests/helpers/RobloxMock), saved data in MemoryStore.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PlayerDataService = require(Services.PlayerDataService)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)
PlayerDataService.useStore(MemoryStore.new(ProfileTemplate.new()))
local PlaceService = require(Services.PlaceService)
PlaceService.useRole("Hub", false, { name = "Test", hub = 111, run = 222 })

runScript(ServerScriptService.Server, "init.server.luau")
local PartyService = require(Services.PartyService)
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
local third = world.addPlayer("Third", 3, false)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local RunStateController = require(Client.Controllers.RunStateController)

local function toasts(): { string }
	local texts = {}
	for _, object in world.gui("Notify"):GetDescendants() do
		if object.ClassName == "TextLabel" then
			table.insert(texts, object.Text)
		end
	end
	return texts
end

local function hasToast(prefix: string): boolean
	for _, text in toasts() do
		if string.sub(text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function buttonNamed(container, name: string, rowText: string?)
	for _, object in container:GetDescendants() do
		if object.ClassName == "TextButton" and object.Name == name then
			local label = object.Parent and object.Parent:FindFirstChild("Text")
			if not rowText or (label and string.find(label.Text, rowText, 1, true)) then
				return object
			end
		end
	end
	return nil
end

local function finishRun()
	RunDirector.endRun("Victory")
	world.advance(Config.Run.flow.resultsSeconds + 0.5)
	expect(RunDirector.getPhase()).toBe("Lobby")
end

describe("hub lobby (Studio)", function()
	it("shows portals and the hub buttons instead of READY", function()
		local lobby = workspace:FindFirstChild("LanternfallMap"):FindFirstChild("Lobby")
		expect(lobby:FindFirstChild("PortalSolo") ~= nil).toBe(true)
		expect(lobby:FindFirstChild("PortalParty") ~= nil).toBe(true)
		expect(lobby:FindFirstChild("PortalQuickJoin") ~= nil).toBe(true)
		expect(world.gui("Lobby", "Ready").Visible).toBe(false)
		expect(world.gui("Lobby", "HubActions").Visible).toBe(true)
		expect(world.gui("Lobby", "Play").Text).toBe("PLAY SOLO")
		expect(world.gui("Lobby", "HubList").Visible).toBe(true)
		expect(world.gui("Lobby", "BackToHub").Visible).toBe(false)
	end)

	it("refuses READY on the hub", function()
		world.fireServerAs(third, "SetReady", true)
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Lobby")
	end)

	it("invites from the player list and joins through the popup", function()
		local invite = buttonNamed(world.gui("Lobby", "HubList"), "Invite", "Third")
		expect(invite ~= nil).toBe(true)
		world.click(invite)
		world.advance(0.3)
		expect(PartyService.getView(third).invite.fromId).toBe(1)
		world.fireServerAs(third, "AnswerInvite", 1, false)
		world.advance(0.3)
		expect(PartyService.getView(third).invite).toBe(nil)

		world.fireServerAs(peer, "InviteToParty", 1)
		world.advance(0.3)
		expect(world.gui("Lobby", "Invite").Visible).toBe(true)
		expect(
			string.find(world.gui("Lobby", "Invite"):FindFirstChild("Text").Text, "Peer invites you", 1, true) ~= nil
		).toBe(true)
		world.click(world.gui("Lobby", "Join"))
		world.advance(0.3)
		expect(world.gui("Lobby", "Invite").Visible).toBe(false)
		expect(PartyService.getLeader(me)).toBe(2)
		expect(#PartyService.getMembers(me)).toBe(2)
		expect(world.gui("Lobby", "Play").Text).toBe("LEADER STARTS")
		expect(world.gui("Lobby", "QuickJoin").Visible).toBe(false)
		expect(world.gui("Lobby", "Danger"):FindFirstChild("Title").Text).toBe("DANGER (your leader picks)")
	end)

	it("lets only the leader pick the danger level, capped for the party", function()
		world.fireServerAs(me, "SetRunOptions", 0, true, 100, 100, 100, 100)
		world.advance(0.3)
		expect(hasToast("Only your party leader")).toBe(true)
		expect(PartyService.getOptions(me).endless).toBe(false)
		world.fireServerAs(peer, "SetRunOptions", 3, false, 100, 100, 100, 100)
		world.advance(0.3)
		expect(PartyService.getOptions(me).danger).toBe(0) -- nobody in the party has danger 3 open
		PlayerDataService.unlockAll(peer)
		world.advance(0.3)
		expect(PartyService.getOptions(me).danger).toBe(3)
		expect(world.gui("Lobby", "Danger3").BackgroundColor3 ~= world.gui("Lobby", "Danger0").BackgroundColor3).toBe(
			true
		)
	end)

	it("starts the party run in this server after the leader's countdown", function()
		world.fireServerAs(peer, "PlayFromHub", "Party")
		world.advance(0.3)
		expect(PartyService.getView(me).launchAt ~= nil).toBe(true)
		expect(string.sub(world.gui("Lobby", "Status"):FindFirstChildOfClass("TextLabel").Text, 1, 18)).toBe(
			"Party run starts i"
		)
		world.advance(Config.Places.party.startCountdownSeconds + 0.3)
		expect(RunDirector.getPhase()).toBe("Countdown")
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		local participants = RunDirector.getParticipants()
		expect(#participants).toBe(2)
		expect(RunDirector.getParticipantState(third)).toBe(nil)
		expect(RunDirector.getRunOptions().danger).toBe(3)
		-- another group cannot start while this one plays (Studio runs one group at a time)
		world.fireServerAs(third, "PlayFromHub", "Solo")
		world.advance(0.3)
		expect(RunDirector.getParticipantState(third)).toBe(nil)
		expect(PartyService.getView(third).players[1].status).toBe("Busy")
		finishRun()
	end)

	it("cancels the party countdown when the leader presses again or someone leaves", function()
		world.fireServerAs(peer, "PlayFromHub", "Party")
		world.advance(0.3)
		world.fireServerAs(peer, "PlayFromHub", "Party")
		world.advance(0.3)
		expect(PartyService.getView(me).launchAt).toBe(nil)
		world.fireServerAs(peer, "PlayFromHub", "Party")
		world.advance(0.3)
		world.click(buttonNamed(world.gui("Lobby", "HubList"), "LeaveParty"))
		world.advance(Config.Places.party.startCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Lobby")
		expect(#PartyService.getMembers(me)).toBe(1)
		expect(#PartyService.getMembers(peer)).toBe(1)
		expect(world.gui("Lobby", "Play").Text).toBe("PLAY SOLO")
	end)

	it("forms a quick join group and starts at the lowest danger level", function()
		world.fireServerAs(peer, "SetRunOptions", 2, false, 100, 100, 100, 100)
		world.click(world.gui("Lobby", "QuickJoin"))
		world.advance(0.3)
		expect(PartyService.isQueued(me)).toBe(true)
		expect(world.gui("Lobby", "QuickJoin").Text).toBe("CANCEL QUICK JOIN")
		expect(PartyService.getView(me).queue.startsAt).toBe(nil) -- alone: waiting
		world.fireServerAs(peer, "PlayFromHub", "QuickJoin")
		world.advance(0.3)
		local queue = PartyService.getView(me).queue
		expect(queue.groupSize).toBe(2)
		expect(queue.startsAt ~= nil).toBe(true)
		world.advance(Config.Places.quickJoin.countdownSeconds + 0.5)
		expect(RunDirector.getPhase() == "Countdown" or RunDirector.getPhase() == "Running").toBe(true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		expect(#RunDirector.getParticipants()).toBe(2)
		expect(RunDirector.getParticipantState(third)).toBe(nil)
		expect(RunDirector.getRunOptions().danger).toBe(0) -- my danger 0 beats the peer's 2
		expect(PartyService.isQueued(me)).toBe(false)
		finishRun()
	end)

	it("starts a solo run from the portal", function()
		local gate = workspace.LanternfallMap.Lobby.PortalSolo:FindFirstChild("Gate")
		gate:FindFirstChild("Prompt").Triggered:Fire(third)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		local participants = RunDirector.getParticipants()
		expect(#participants).toBe(1)
		expect(participants[1]).toBe(third)
		-- READY on the results is "Play again" for the one who played
		RunDirector.endRun("Victory")
		world.advance(0.3)
		world.fireServerAs(me, "SetReady", true)
		world.advance(0.3)
		expect(RunStateController.getLocalPlayer().ready).toBe(false)
		world.fireServerAs(third, "SetReady", true)
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Countdown")
		world.fireServerAs(third, "SetReady", false)
		world.advance(0.5)
		expect(RunDirector.getPhase()).toBe("Lobby")
	end)

	it("drops a party when its leader leaves the server", function()
		world.fireServerAs(peer, "InviteToParty", 3)
		world.fireServerAs(third, "AnswerInvite", 2, true)
		world.advance(0.3)
		expect(#PartyService.getMembers(third)).toBe(2)
		world.removePlayer(peer)
		world.advance(0.3)
		expect(#PartyService.getMembers(third)).toBe(1)
		expect(#PartyService.getView(me).players).toBe(1)
	end)

	it("ran without script errors", function()
		expect(#world.errors).toBe(0)
	end)
end)
