--!strict
-- Bull selection, native access, original rule rendering and repeat-run equipment through real services.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
Config.Classes.Bull.available = true -- local art upload remains a separate dependency
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Data = require(S.PlayerDataService)
local Run = require(S.RunDirector)
local Weapons = require(S.WeaponService)
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
require(S.SpawnDirector).setPaused(true)
Weapons.setPaused(true)
Run.setHoldWaves(true)

describe("Native Bull package", function()
	it("unlocks from a real Danger-1 victory and skips the weapon page in both directions", function()
		expect(Config.Classes.Bull.nativeCodeReady).toBe(true)
		expect(Data.ownsClass(me, "Bull")).toBe(false)
		assert(
			Data.recordRun(
				me,
				{ won = true, wave = 20, danger = 1, classId = "NightWatch", kills = 0, bossKills = 0, seconds = 1200 }
			)
		)
		expect(Data.ownsClass(me, "Bull")).toBe(true)
		world.click(world.gui("Lobby", "Start"))
		world.click(world.gui("Lobby", "Bull"))
		world.advance(0.1)
		expect(Run.getSelectedClassId(me)).toBe("Bull")
		expect(world.gui("Lobby", "Danger").Visible).toBe(true)
		expect(world.gui("Lobby", "StartingWeapons").Visible).toBe(false)
		world.click(world.gui("Lobby", "LobbyBack"))
		expect(world.gui("Lobby", "Classes").Visible).toBe(true)
		world.click(world.gui("Lobby", "Bull"))
		expect(world.gui("Lobby", "Danger").Visible).toBe(true)
	end)
	it("renders all three original explosion scaling icons and replaces them when changing character", function()
		local rules = world.gui("Lobby", "CharacterRuleIcons")
		expect(rules.Visible).toBe(true)
		local row = rules.Row5
		local images = {}
		for _, part in row:GetChildren() do
			if part:IsA("Frame") then
				expect(part.Coefficient.Text).toBe("300%")
				images[part.Stat.Illustration:GetAttribute("IconKey")] = true
			end
		end
		expect(images["stat:meleeDamage"]).toBe(true)
		expect(images["stat:rangedDamage"]).toBe(true)
		expect(images["stat:elementalDamage"]).toBe(true)
		world.fireServerAs(me, "SelectClass", "NightWatch")
		expect(rules.Visible).toBe(false)
		world.fireServerAs(me, "SelectClass", "Bull")
		expect(rules.Visible).toBe(true)
	end)
	it("starts weaponless after reset and rejects forged start-weapon requests", function()
		for _ = 1, 2 do
			world.fireServerAs(me, "SelectStartWeapon", "Bull", "WatchmanPistol")
			Run.setReady(me, true)
			world.advance(3.5)
			expect(Run.getPhase()).toBe("Running")
			expect(#Weapons.getWeapons(me)).toBe(0)
			expect(Weapons.addWeapon(me, "WatchmanPistol")).toBe(false)
			Run.endRun("Abandoned")
			world.advance(Config.Run.flow.resultsSeconds + 0.5)
		end
		expect(#world.errors).toBe(0)
	end)
end)
