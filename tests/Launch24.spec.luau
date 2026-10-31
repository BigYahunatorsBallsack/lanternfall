-- Tests of Paket 24 (launch package): the launch check (Util/LaunchRules, LaunchService, debug button), the
-- showcase scene and the client capture mode (menus hidden and back, camera shots, the enemy view follows the shot).
-- Real server and client bootstrap in a simulated Roblox (tests/helpers/RobloxMock).

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local LaunchRules = require(ReplicatedStorage.Shared.Util.LaunchRules)

runScript(ServerScriptService.Server, "init.server.luau")
local EnemySim = require(Services.EnemySim)
local LaunchService = require(Services.LaunchService)
local RunDirector = require(Services.RunDirector)
local WeaponService = require(Services.WeaponService)

local me = world.addPlayer("Owner", 1, true)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local CameraController = require(Client.Controllers.CameraController)
local CaptureController = require(Client.Controllers.CaptureController)

local function find(items, key)
	for _, item in items do
		if item.key == key then
			return item
		end
	end
	return nil
end

local hub = Config.Places.experiences[1].hub

describe("launch check", function()
	it("knows a listed place and flags an unknown one", function()
		local known = LaunchRules.check({ gameId = 0, placeId = hub, configProblems = 0 })
		expect(find(known, "Places").ok).toBe(true)
		local unknown = LaunchRules.check({ gameId = 0, placeId = 999, configProblems = 0 })
		expect(find(unknown, "Places").ok).toBe(false)
		expect(find(unknown, "Places").level).toBe("must")
	end)

	it("flags config problems", function()
		local items = LaunchRules.check({ gameId = 0, placeId = hub, configProblems = 2 })
		expect(find(items, "Config").ok).toBe(false)
		expect(string.find(find(items, "Config").text, "2 config problems", 1, true) ~= nil).toBe(true)
	end)

	it("says when a published experience runs on the catch-all store ids", function()
		local unpublished = LaunchRules.check({ gameId = 0, placeId = hub, configProblems = 0 })
		expect(find(unpublished, "StoreExperience").ok).toBe(true)
		local live = LaunchRules.check({ gameId = 4242, placeId = hub, configProblems = 0 })
		local store = find(live, "StoreExperience")
		local exact = false
		for _, experience in Config.Store.experiences do
			exact = exact or experience.gameId == 4242
		end
		expect(store.ok).toBe(exact)
	end)

	it("lists badge ids, music and sounds that are still missing", function()
		local items = LaunchRules.check({ gameId = 0, placeId = hub, configProblems = 0 })
		local openBadges = 0
		for _, id in Config.Badges.experiences[1].ids do
			if id == 0 then
				openBadges += 1
			end
		end
		expect(find(items, "Badges").ok).toBe(openBadges == 0)
		local silent = 0
		for _, track in Config.Audio.music do
			if track.sound == "" then
				silent += 1
			end
		end
		expect(find(items, "Music").ok).toBe(silent == 0)
		local sounds = 0
		for _, id in Config.Audio.ownSounds do
			if id == "" or id == "0" then
				sounds += 1
			end
		end
		expect(find(items, "Sounds").ok).toBe(sounds == 0)
	end)

	it("counts open items and puts them first", function()
		local items = {
			{ key = "A", level = "should", ok = true, text = "fine" },
			{ key = "B", level = "must", ok = false, text = "broken" },
			{ key = "C", level = "should", ok = false, text = "rough" },
		}
		local must, should = LaunchRules.open(items)
		expect(must).toBe(1)
		expect(should).toBe(1)
		local lines = LaunchRules.lines(items)
		expect(lines[1]).toBe("[MUST] broken")
		expect(lines[2]).toBe("[should] rough")
		expect(lines[3]).toBe("[ok] fine")
		expect(string.find(LaunchRules.summary(items), "1 must, 1 should", 1, true) ~= nil).toBe(true)
		expect(LaunchRules.summary({ items[1] })).toBe("Launch check: ready, nothing open")
	end)

	it("runs on the server and from the debug button", function()
		local items = LaunchService.check()
		expect(#items > 5).toBe(true)
		expect(find(items, "Config").ok).toBe(true) -- the real config is clean
		world.click(world.gui("Debug", "LaunchCheck"))
		world.advance(0.2)
		expect(string.find(LaunchService.report(), "Launch check", 1, true) ~= nil).toBe(true)
	end)
end)

describe("showcase scene", function()
	it("stops the waves, fills the weapon slots and spawns a crowd", function()
		world.fireServerAs(me, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		world.advance(1)
		local before = EnemySim.getCount()
		world.fireServerAs(me, "DebugCommand", "Showcase")
		world.advance(0.2)
		expect(RunDirector.isHoldingWaves()).toBe(true)
		local weapons = WeaponService.getWeapons(me)
		expect(#weapons).toBe(math.min(Config.Player.maxWeapons, #WeaponService.getImplemented()))
		for _, weapon in weapons do
			expect(weapon.tier >= Config.Launch.showcase.weaponTier).toBe(true)
		end
		expect(EnemySim.getCount() > before).toBe(true)
	end)
end)

describe("capture mode", function()
	it("hides every menu and brings them back", function()
		local playerGui = me:FindFirstChild("PlayerGui")
		local debug = playerGui:FindFirstChild("Debug")
		expect(debug.Enabled).toBe(true)
		world.click(world.gui("Debug", "CaptureMode"))
		expect(CaptureController.isActive()).toBe(true)
		expect(debug.Enabled).toBe(false)
		for _, child in playerGui:GetChildren() do
			if child.ClassName == "ScreenGui" and child.Name ~= "CaptureHint" then
				expect(child.Enabled).toBe(false)
			end
		end
		CaptureController.toggle()
		expect(CaptureController.isActive()).toBe(false)
		expect(debug.Enabled).toBe(true)
	end)

	it("cycles the camera shots and the enemy view follows", function()
		local pitch, distance = CameraController.getView()
		expect(pitch).toBe(Config.Camera.pitchDegrees)
		expect(distance).toBe(Config.Camera.distance)
		CaptureController.nextShot() -- ignored while capture mode is off
		expect(select(2, CameraController.getView())).toBe(Config.Camera.distance)
		CaptureController.toggle()
		CaptureController.nextShot()
		local shot = Config.Launch.capture.shots[2]
		pitch, distance = CameraController.getView()
		expect(pitch).toBe(shot.pitchDegrees)
		expect(distance).toBe(shot.distance)
		world.advance(0.2)
		CaptureController.toggle()
		expect(select(2, CameraController.getView())).toBe(Config.Camera.distance)
	end)

	it("does nothing for players without admin rights", function()
		me:SetAttribute("LanternfallAdmin", false)
		CaptureController.toggle()
		expect(CaptureController.isActive()).toBe(false)
		me:SetAttribute("LanternfallAdmin", true)
	end)
end)
