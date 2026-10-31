-- End-to-end test of Paket 23 in the hub: the same player can be invited again only after
-- Config.Security.reinviteSeconds, so nobody can flood someone with invite popups. Studio hub (no teleports) in a
-- simulated Roblox (tests/helpers/RobloxMock), saved data in MemoryStore.

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

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.step()
world.advance(0.5)

describe("party invites", function()
	it("refuses a second invite to the same player right after the first", function()
		world.fireServerAs(peer, "InviteToParty", 1)
		world.advance(0.3)
		expect(PartyService.getView(me).invite.fromId).toBe(2)
		world.fireServerAs(me, "AnswerInvite", 2, false)
		world.advance(0.3)
		expect(PartyService.getView(me).invite).toBe(nil)
		world.fireServerAs(peer, "InviteToParty", 1)
		world.advance(0.3)
		expect(PartyService.getView(me).invite).toBe(nil)
	end)

	it("allows it again after the cooldown", function()
		world.advance(Config.Security.reinviteSeconds)
		world.fireServerAs(peer, "InviteToParty", 1)
		world.advance(0.3)
		expect(PartyService.getView(me).invite.fromId).toBe(2)
		world.fireServerAs(me, "AnswerInvite", 2, true)
		world.advance(0.3)
		expect(#PartyService.getMembers(me)).toBe(2)
	end)

	it("ran without script errors", function()
		expect(#world.errors).toBe(0)
	end)
end)
