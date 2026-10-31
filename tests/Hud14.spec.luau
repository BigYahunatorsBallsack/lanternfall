-- End-to-end test of Paket 14: the settings menu changes and saves settings, the HUD gets the planned elite and horde
-- waves and shows the next one, weapon, item and stat rows have tooltips, the stat panel switches pages, and the
-- results screen lists the local player's weapons with their damage.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

runScript(ServerScriptService.Server, "init.server.luau")
local DangerService = require(Services.DangerService)
local PlayerDataService = require(Services.PlayerDataService)
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)
local StatService = require(Services.StatService)
local WeaponService = require(Services.WeaponService)

local me = world.addPlayer("Owner", 1, true)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local HUDController = require(Client.Controllers.HUDController)
local SettingsController = require(Client.Controllers.SettingsController)
local StatsController = require(Client.Controllers.StatsController)
local Tooltip = require(Client.UI.Tooltip)

local OPTIONS = { danger = 4, endless = false, enemyHp = 100, enemyDamage = 100, enemySpeed = 100 }

describe("settings menu", function()
	it("opens, changes a setting at once and saves it after a moment", function()
		expect(SettingsController.isOpen()).toBe(false)
		world.click(world.gui("Settings", "Gear"))
		expect(SettingsController.isOpen()).toBe(true)
		local shakeRow = world.gui("Settings", "Screen shake")
		local toggle = shakeRow:FindFirstChild("Toggle")
		expect(toggle.Text).toBe("ON")
		world.click(toggle)
		expect(SettingsController.get().shake).toBe(false)
		expect(toggle.Text).toBe("OFF")
		world.click(world.gui("Settings", "Music"):FindFirstChild("Less"))
		expect(math.abs(SettingsController.get().music - (Config.Settings.defaults.music - 0.1)) < 1e-6).toBe(true)
		expect(PlayerDataService.get(me).settings.shake).toBe(true) -- not sent yet
		world.advance(Config.Settings.saveDelaySeconds + 0.5)
		local saved = PlayerDataService.get(me).settings
		expect(saved.shake).toBe(false)
		expect(math.abs(saved.music - SettingsController.get().music) < 1e-6).toBe(true)
		world.click(world.gui("Settings", "Close"))
		expect(SettingsController.isOpen()).toBe(false)
	end)

	it("refuses settings out of range", function()
		world.advance(6) -- past the rate limit window
		world.fireServerAs(me, "SaveSettings", true, true, 5, 0.5)
		world.advance(0.1)
		expect(PlayerDataService.get(me).settings.shake).toBe(false)
	end)
end)

describe("HUD", function()
	it("gets the planned waves and shows the next elite or horde wave", function()
		PlayerDataService.unlockAll(me)
		RunDirector.setOptions(OPTIONS)
		world.fireServerAs(me, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		world.advance(0.5)
		local plan = HUDController.getWavePlan()
		local count = 0
		for _ in DangerService.getPlan() do
			count += 1
		end
		expect(count > 0).toBe(true)
		expect(#plan).toBe(count)
		local preview = world.gui("HUD", "WavePreview")
		expect(preview.Visible).toBe(true)
		local first = plan[1]
		local name = if first.kind == "Horde" then "Horde wave" else "Elite wave"
		local left = first.wave - RunDirector.getWave()
		expect(preview.Text).toBe(if left == 1 then `{name} next` else `{name} in {left}`)
		expect(Tooltip.open(preview)).toBe(true)
		local title, body = Tooltip.getShown()
		expect(title).toBe("COMING UP")
		expect(string.find(body, `Wave {first.wave}`, 1, true) ~= nil).toBe(true)
		Tooltip.hide()
	end)

	it("gives weapons, items and stats tooltips", function()
		local row = world.gui("HUD", "Weapon1")
		expect(row ~= nil).toBe(true)
		expect(Tooltip.open(row)).toBe(true)
		local title, body = Tooltip.getShown()
		expect(title).toBe(row.Text)
		expect(string.find(body, "Damage <b>", 1, true) ~= nil).toBe(true)
		Tooltip.hide()

		local item = Config.Items.list[1]
		StatService.addItem(me, item.id)
		world.advance(0.3)
		local itemRow = world.gui("HUD", item.id)
		expect(Tooltip.open(itemRow)).toBe(true)
		local itemTitle, itemBody = Tooltip.getShown()
		expect(itemTitle).toBe(item.displayName)
		expect(string.find(itemBody, "owned 1", 1, true) ~= nil).toBe(true)
		Tooltip.hide()

		local armorRow = world.gui("Stats", "armor")
		expect(Tooltip.open(armorRow)).toBe(true)
		local statTitle, statBody = Tooltip.getShown()
		expect(statTitle).toBe("Armor")
		expect(string.find(statBody, "less damage", 1, true) ~= nil).toBe(true)
		Tooltip.hide()
	end)

	it("switches the stat panel between primary and secondary stats", function()
		local armorRow = world.gui("Stats", "armor")
		local priceRow = world.gui("Stats", "itemPrice")
		expect(armorRow.Visible).toBe(true)
		expect(priceRow.Visible).toBe(false)
		StatsController.setPage("Secondary")
		expect(armorRow.Visible).toBe(false)
		StatsController.setPage("Primary")
		expect(armorRow.Visible).toBe(true)
	end)
end)

describe("results", function()
	it("lists the local player's weapons with their damage", function()
		WeaponService.setPaused(false)
		SpawnDirector.setPaused(false)
		world.advance(20)
		RunDirector.endRun("Defeat")
		world.advance(0.5)
		local weapons = world.gui("Results", "Weapons")
		local rows = {}
		for _, child in weapons:GetChildren() do
			if child.ClassName == "TextLabel" then
				table.insert(rows, child.Text)
			end
		end
		expect(#rows > 0).toBe(true)
		expect(string.find(rows[1], "damage", 1, true) ~= nil).toBe(true)
		expect(world.gui("Results", "WeaponsTitle").Visible).toBe(true)
	end)
end)
