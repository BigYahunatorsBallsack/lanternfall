--!strict
-- Exercises the screenshot-led preparation flow against the real server, including locks and back navigation.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
world.addPlayer("Owner", 1, true)
world.step()
local Client = folderProxy("src/client", "Client")
require(Client.Controllers.WeaponRenderer).start = function() end
runScript(Client, "init.client.luau")
world.advance(0.5)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Run = require(Server.Services.RunDirector)
local State = require(Client.Controllers.RunStateController)
local Choice = require(Client.Controllers.CharacterChoice)

describe("Reference menu flow", function()
	it("opens character, weapon and difficulty choices without starting a run", function()
		expect(world.gui("Lobby", "MainMenu").Visible).toBe(true)
		world.click(world.gui("Lobby", "Start"))
		expect(world.gui("Lobby", "MainMenu").Visible).toBe(false)
		local id = State.getLocalPlayer().classId
		world.click(world.gui("Lobby", id))
		expect(world.gui("Lobby", "StartingWeapons").Visible).toBe(true)
		local weapon = Config.Classes[id].startWeapons[1]
		world.click(world.gui("Lobby", `Start_{weapon}`))
		world.advance(0.4)
		expect(world.gui("Lobby", "Danger").Visible).toBe(true)
		expect(Run.getPhase()).toBe("Lobby")
		world.click(world.gui("Lobby", "LobbyBack"))
		expect(world.gui("Lobby", "StartingWeapons").Visible).toBe(true)
	end)
	it("keeps locked characters on the character page and exposes collection and party", function()
		world.click(world.gui("Lobby", "LobbyBack"))
		for id, class in Config.Classes do
			if class.available and not Choice.isUnlocked(id) then
				world.click(world.gui("Lobby", id))
				expect(world.gui("Lobby", "Classes").Visible).toBe(true)
				expect(world.gui("Lobby", "StartingWeapons").Visible).toBe(false)
				break
			end
		end
		world.click(world.gui("Lobby", "LobbyBack"))
		world.click(world.gui("Lobby", "OpenCollection"))
		expect(world.gui("Lobby", "Collection").Visible).toBe(true)
		world.click(world.gui("Lobby", "LobbyBack"))
		world.click(world.gui("Lobby", "OpenParty"))
		expect(world.gui("Lobby", "Players").Visible).toBe(true)
		assert(#world.errors == 0, table.concat(world.errors, "\n"))
	end)
end)
