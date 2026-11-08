--!strict
-- Character selection: hovering a tile previews that character in the summary, tiles keep a visible gap.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
world.addPlayer("Owner", 1, true)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RunState = require(Client.Controllers.RunStateController)

describe("Selection hover", function()
	it("previews the hovered character and returns to the chosen one", function()
		workspace.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
		world.click(world.gui("Lobby", "Start"))
		world.advance(0.1)
		local chosen = RunState.getLocalPlayer().classId
		local other = if chosen == "SparkMage" then "NightWatch" else "SparkMage"
		local name = world.gui("Lobby", "SelectedCharacter")
		expect(name.Text).toBe(Config.Classes[chosen].displayName)
		local tile = world.gui("Lobby", "Classes"):FindFirstChild(other)
		tile.MouseEnter:Fire(10, 10)
		expect(name.Text).toBe(Config.Classes[other].displayName)
		tile.MouseLeave:Fire()
		expect(name.Text).toBe(Config.Classes[chosen].displayName)
		local grid = world.gui("Lobby", "Classes"):FindFirstChildOfClass("UIGridLayout")
		expect(grid.CellPadding.X.Offset >= 10).toBe(true)
		assert(#world.errors == 0, table.concat(world.errors, "\n"))
	end)
end)
