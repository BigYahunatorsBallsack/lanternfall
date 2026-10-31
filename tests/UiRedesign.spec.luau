--!strict
-- Navigation and responsive layout must preserve existing lobby commands and profile windows.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local me = world.addPlayer("Owner", 1, true)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local Layout = require(Client.UI.LobbyLayout)
local Run = require(Server.Services.RunDirector)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

describe("UI redesign foundation", function()
	it("shows one lobby page at a time and keeps account actions out of the party list", function()
		expect(world.gui("Lobby", "Choose").Visible).toBe(true)
		expect(world.gui("Lobby", "Danger").Visible).toBe(false)
		expect(world.gui("Lobby", "Players").Visible).toBe(false)
		world.click(world.gui("Lobby", "TabPARTY"))
		expect(world.gui("Lobby", "Players").Visible).toBe(true)
		expect(world.gui("Lobby", "Choose").Visible).toBe(false)
		expect(world.gui("Lobby", "Record").Parent.Name).toBe("Collection")
		world.click(world.gui("Lobby", "TabCOLLECTION"))
		expect(world.gui("Lobby", "Collection").Visible).toBe(true)
		world.click(world.gui("Lobby", "OpenAchievements"))
		expect(require(Client.Controllers.AchievementList).isOpen()).toBe(true)
		world.click(world.gui("Lobby", "TabPLAY"))
		expect(require(Client.Controllers.AchievementList).isOpen()).toBe(false)
	end)
	it("reflows character and starting-weapon grids for portrait without shrinking all text", function()
		workspace.CurrentCamera.ViewportSize = Vector2.new(390, 844)
		Layout.refresh()
		local grid = world.gui("Lobby", "Classes"):FindFirstChildOfClass("UIGridLayout")
		expect(grid.CellSize.X.Scale).toBe(0.5)
		expect(world.gui("Lobby", "Page").Size.X.Offset).toBe(342)
		expect(world.gui("Lobby", "LobbyContent").AutomaticCanvasSize).toBe(Enum.AutomaticSize.Y)
		workspace.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
		Layout.refresh()
		expect(grid.CellSize.X.Scale).toBe(0.2)
	end)
	it("keeps debug controls available but collapsed initially", function()
		expect(world.gui("Debug", "Buttons").Visible).toBe(false)
		expect(world.gui("Debug", "Stats").Visible).toBe(false)
		world.click(world.gui("Debug", "Header"))
		expect(world.gui("Debug", "Buttons").Visible).toBe(true)
		expect(world.gui("Debug", "Stats").Visible).toBe(true)
	end)

	it("keeps collection dialogs and settings reachable in portrait and closes the modal shell", function()
		workspace.CurrentCamera.ViewportSize = Vector2.new(390, 844)
		world.click(world.gui("Lobby", "TabCOLLECTION"))
		for _, entry in
			{
				{ "Achievements", "OpenAchievements" },
				{ "Store", "OpenStore" },
				{ "EmberShop", "OpenEmberShop" },
				{ "Quests", "OpenQuests" },
				{ "Leaderboards", "OpenLeaderboards" },
			}
		do
			world.click(world.gui("Lobby", entry[2]))
			local shell = world.gui("Lobby", entry[1] .. "Dialog")
			expect(shell.Visible).toBe(true)
			expect(world.gui("Lobby", entry[1]).Size.X.Offset <= 350).toBe(true)
			expect(shell.Content.AutomaticCanvasSize).toBe(Enum.AutomaticSize.Y)
			world.click(shell.Dismiss)
			expect(shell.Visible).toBe(false)
		end
		world.click(world.gui("Settings", "Gear"))
		expect(world.gui("Settings", "MenuDialog").Visible).toBe(true)
		expect(world.gui("Settings", "GearHolder"):FindFirstChildOfClass("UIScale")).toBe(nil)
		world.click(world.gui("Settings", "Dismiss"))
		expect(require(Client.Controllers.SettingsController).isOpen()).toBe(false)
		world.click(world.gui("Lobby", "TabPLAY"))
		workspace.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
	end)
	it("keeps character selection, ready and full-capacity shop slots working", function()
		require(Server.Services.PlayerDataService).unlockAll(me)
		world.click(world.gui("Lobby", "CandleScholar"))
		world.advance(0.4)
		expect(Run.getSelectedClassId(me)).toBe("CandleScholar")
		world.click(world.gui("Lobby", "Ready"))
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(Run.getPhase()).toBe("Running")
		expect(world.gui("Shop", "Weapon12") ~= nil).toBe(true)
		assert(#world.errors == 0, table.concat(world.errors, "\n"))
	end)
	it("keeps the complete build behind a toggle and clears the combat HUD between waves", function()
		expect(world.gui("HUD", "Weapons").Visible).toBe(false)
		world.click(world.gui("HUD", "BuildToggle"))
		expect(world.gui("HUD", "Weapons").Visible).toBe(true)
		local Stats = require(Server.Services.StatService)
		for index = 1, 9 do
			Stats.addItem(me, Config.Items.list[index].id)
		end
		world.advance(0.2)
		for index = 1, 9 do
			expect(world.gui("HUD", Config.Items.list[index].id) ~= nil).toBe(true)
		end
		expect(world.gui("HUD", "BuildContent").AutomaticCanvasSize).toBe(Enum.AutomaticSize.Y)
		world.click(world.gui("Debug", "GainLevel"))
		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.2)
		expect(Run.getPhase()).toBe("Shop")
		expect(world.gui("HUD", "Weapons").Visible).toBe(false)
		expect(world.gui("HUD", "Health").Visible).toBe(false)
		expect(world.gui("HUD", "Timer").Visible).toBe(false)
	end)
	it("reflows upgrade choices and returns to the shop after a real server-validated pick", function()
		workspace.CurrentCamera.ViewportSize = Vector2.new(390, 844)
		local grid = world.gui("LevelUp", "Cards"):FindFirstChildOfClass("UIGridLayout")
		expect(world.gui("LevelUp").Enabled).toBe(true)
		expect(grid.FillDirectionMaxCells).toBe(2)
		expect(grid.CellSize.X.Scale).toBe(0.5)
		expect(world.gui("LevelUp", "LevelUpDialog").Content.AutomaticCanvasSize).toBe(Enum.AutomaticSize.Y)
		local Level = require(Client.Controllers.LevelUpController)
		for _ = 1, 10 do
			if not Level.isOpen() then
				break
			end
			world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
			world.click(world.gui("LevelUp", "Card1"))
			world.advance(0.2)
		end
		expect(Level.isOpen()).toBe(false)
		expect(world.gui("Shop", "ShopContent").Visible).toBe(true)
	end)
	it("keeps shop actions outside the scroll canvas and supports portrait and landscape stats", function()
		for _, area in { Vector2.new(390, 844), Vector2.new(844, 390) } do
			workspace.CurrentCamera.ViewportSize = area
			local footer = world.gui("Shop", "ShopFooter")
			expect(footer.Visible).toBe(true)
			expect(footer.Parent).toBe(world.gui("Shop"))
			expect(world.gui("Shop", "Ready").Parent.Parent).toBe(footer)
			local content = world.gui("Shop", "ShopContent")
			expect(content.CanvasSize.Y.Offset > area.Y + content.Size.Y.Offset).toBe(true)
			local offers = world.gui("Shop", "Offers"):FindFirstChildOfClass("UIGridLayout")
			expect(offers.CellSize.X.Offset * 2 + 10 <= footer.Size.X.Offset - 28).toBe(true)
			expect(world.gui("Shop", "EffectDetails").AutomaticCanvasSize).toBe(Enum.AutomaticSize.Y)
			world.click(world.gui("Shop", "StatsToggle"))
			expect(world.gui("Stats").Enabled).toBe(true)
			expect(content.Visible).toBe(false)
			expect(footer.Visible).toBe(false)
			expect(world.gui("Stats", "StatsContent").AutomaticCanvasSize).toBe(Enum.AutomaticSize.Y)
			world.click(world.gui("Shop", "BackToShop"))
			expect(content.Visible).toBe(true)
			expect(footer.Visible).toBe(true)
		end
		workspace.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
		world.click(world.gui("Shop", "Ready"))
		world.advance(0.3)
		expect(Run.getPhase()).toBe("Running")
		expect(world.gui("HUD", "Health").Visible).toBe(true)
	end)
	it("shows all twelve weapon summaries with accessible result actions", function()
		Run.endRun("Defeat")
		world.advance(0.2)
		local weapons = {}
		for i = 1, 12 do
			table.insert(weapons, { id = "SparkBolt", tier = 1, damage = i * 100, kills = i })
		end
		require(game:GetService("ReplicatedStorage").Shared.Net).fireClient("RunSummary", me, {
			teamLevel = 5,
			kills = 50,
			players = { { userId = me.UserId, kills = 50, damageDealt = 1000, damageTaken = 100, weapons = weapons } },
		})
		local count = 0
		for _, child in world.gui("Results", "Weapons"):GetChildren() do
			if child:IsA("TextLabel") then
				count += 1
			end
		end
		expect(count).toBe(12)
		workspace.CurrentCamera.ViewportSize = Vector2.new(390, 844)
		expect(world.gui("Results", "Results").Size.X.Offset).toBe(350)
		expect(world.gui("Results", "PlayAgain").Size.X.Scale).toBe(1)
		expect(world.gui("Results", "ResultsDialog").Content.AutomaticCanvasSize).toBe(Enum.AutomaticSize.Y)
		assert(#world.errors == 0, table.concat(world.errors, "\n"))
	end)
end)
