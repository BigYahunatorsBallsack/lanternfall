-- End-to-end test of Paket 22 on the client: the graphics setting (Auto, High, Low; GraphicsController) is in the
-- settings menu, saved in the profile and turns the bloom, the optional lights (not your own) and the arena's embers
-- down at Low; EnemyRenderer leaves enemies off the screen where they are (Util/ViewBounds).

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

runScript(ServerScriptService.Server, "init.server.luau")
local CombatService = require(Services.CombatService)
local EnemySim = require(Services.EnemySim)
local PlayerDataService = require(Services.PlayerDataService)
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)
local WeaponService = require(Services.WeaponService)

local me = world.addPlayer("Owner", 1, true)
local other = world.addPlayer("Friend", 2, false)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local EnemyRenderer = require(Client.Controllers.EnemyRenderer)
local GraphicsController = require(Client.Controllers.GraphicsController)
local SettingsController = require(Client.Controllers.SettingsController)

local Graphics = Config.Graphics

local function taggedLight(parent: Instance): PointLight
	local light = Instance.new("PointLight")
	light.Parent = parent
	CollectionService:AddTag(light, Graphics.optionalLightTag)
	return light
end

local function decorLights(): { Instance }
	local lights = {}
	for _, light in CollectionService:GetTagged(Graphics.optionalLightTag) do
		if not light:IsDescendantOf(me.Character) and not light:IsDescendantOf(other.Character) then
			table.insert(lights, light)
		end
	end
	return lights
end

describe("GraphicsController.decide", function()
	it("keeps a chosen level and lets Auto pick Low on phones, low Roblox graphics or a slow run", function()
		expect(GraphicsController.decide("High", true, 1, true)).toBe("High")
		expect(GraphicsController.decide("Low", false, nil, false)).toBe("Low")
		expect(GraphicsController.decide("Auto", false, nil, false)).toBe("High")
		expect(GraphicsController.decide(nil, false, nil, false)).toBe("High")
		expect(GraphicsController.decide("Auto", true, nil, false)).toBe("Low")
		expect(GraphicsController.decide("Auto", false, Graphics.auto.robloxQualityLowAtOrBelow, false)).toBe("Low")
		expect(GraphicsController.decide("Auto", false, Graphics.auto.robloxQualityLowAtOrBelow + 1, false)).toBe(
			"High"
		)
		expect(GraphicsController.decide("Auto", false, nil, true)).toBe("Low")
		local _, reason = GraphicsController.decide("Auto", true, nil, false)
		expect(reason).toBe("auto: touch device")
	end)
end)

describe("graphics setting", function()
	it("starts on Auto, which is High on a desktop", function()
		expect(SettingsController.get().graphics).toBe("Auto")
		expect(GraphicsController.getLevel()).toBe("High")
		expect(world.gui("Settings", "Graphics"):FindFirstChild("Choice").Text).toBe("AUTO")
	end)

	it("tags the decor lights and the ember emitter on the server", function()
		expect(#decorLights() > 0).toBe(true)
		local motes = CollectionService:GetTagged(Graphics.motesTag)
		expect(#motes).toBe(1)
		expect(motes[1].Rate).toBe(Config.Map.decor.motes.rate)
		local bloom = Lighting:FindFirstChild("LanternfallBloom")
		expect(bloom ~= nil and bloom.Enabled).toBe(true)
	end)

	it("cycles through the choices in the menu, saves them and turns the extras down at Low", function()
		local own = taggedLight(me.Character.HumanoidRootPart)
		local theirs = taggedLight(other.Character.HumanoidRootPart)
		world.step()
		local choice = world.gui("Settings", "Graphics"):FindFirstChild("Choice")
		world.click(choice)
		expect(SettingsController.get().graphics).toBe("High")
		expect(choice.Text).toBe("HIGH")
		world.click(choice)
		expect(SettingsController.get().graphics).toBe("Low")
		expect(choice.Text).toBe("LOW")
		expect(GraphicsController.isLow()).toBe(true)
		local level, reason = GraphicsController.getLevel()
		expect(level).toBe("Low")
		expect(reason).toBe("chosen")

		expect(Lighting:FindFirstChild("LanternfallBloom").Enabled).toBe(false)
		for _, light in decorLights() do
			expect(light.Enabled).toBe(false)
		end
		expect(own.Enabled).toBe(true) -- your own lantern stays lit
		expect(theirs.Enabled).toBe(false)
		local motes = CollectionService:GetTagged(Graphics.motesTag)[1]
		expect(motes.Rate).toBe(Config.Map.decor.motes.rate * Graphics.low.motesShare)
		-- a light that arrives later follows the level too
		local late = taggedLight(other.Character.HumanoidRootPart)
		expect(late.Enabled).toBe(false)

		world.advance(Config.Settings.saveDelaySeconds + 0.5)
		expect(PlayerDataService.get(me).settings.graphics).toBe("Low")

		world.click(choice) -- back to Auto
		expect(SettingsController.get().graphics).toBe("Auto")
		expect(GraphicsController.isLow()).toBe(false)
		expect(Lighting:FindFirstChild("LanternfallBloom").Enabled).toBe(true)
		expect(theirs.Enabled).toBe(true)
		expect(motes.Rate).toBe(Config.Map.decor.motes.rate)
		world.advance(Config.Settings.saveDelaySeconds + 0.5)
		expect(PlayerDataService.get(me).settings.graphics).toBe("Auto")
		own:Destroy()
		theirs:Destroy()
		late:Destroy()
	end)

	it("lets Auto switch to Low after a slow run and refuses unknown choices on the server", function()
		GraphicsController.setSlowSession(true)
		local level, reason = GraphicsController.getLevel()
		expect(level).toBe("Low")
		expect(reason).toBe("auto: low FPS")
		GraphicsController.setSlowSession(false)
		expect(GraphicsController.isLow()).toBe(false)

		world.advance(6) -- past the rate limit window
		world.fireServerAs(me, "SaveSettings", true, true, 0.5, 0.5, "Ultra")
		world.advance(0.1)
		expect(PlayerDataService.get(me).settings.graphics).toBe("Auto")
		world.advance(6)
		world.fireServerAs(me, "SaveSettings", true, true, 0.5, 0.5, "High")
		world.advance(0.1)
		expect(PlayerDataService.get(me).settings.graphics).toBe("High")
	end)
end)

describe("enemies off the screen", function()
	it("are not placed, while enemies near the camera are", function()
		SpawnDirector.setPaused(true)
		RunDirector.setHoldWaves(true)
		world.fireServerAs(me, "SetReady", true)
		world.fireServerAs(other, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		WeaponService.setPaused(true)
		CombatService.protect(me, 10000)
		CombatService.protect(other, 10000)
		EnemySim.killAll()
		world.advance(0.5)

		local root = me.Character.HumanoidRootPart
		-- the arena is about one screen wide since the playtest after Paket 24: stand at the west wall, so the far
		-- row at the east wall is well off a 16:9 screen
		local arena = Config.Map.arena
		root.Position = Vector3.new(arena.center.X - arena.size / 2 + 8, root.Position.Y, arena.center.Z)
		world.advance(1)
		local x, z = root.Position.X, root.Position.Z
		local far = 0
		for k = 1, 6 do
			if EnemySim.spawn("Shadeling", x + arena.size - 16, z + (k - 3.5) * 6, 100, 0) then
				far += 1
			end
		end
		local near = 0
		for k = 1, 3 do
			if EnemySim.spawn("Shadeling", x + k * 4, z - 10, 100, 0) then
				near += 1
			end
		end
		expect(far).toBe(6)
		expect(near).toBe(3)
		world.advance(1)
		local stats = EnemyRenderer.getStats()
		expect(stats.drawn).toBe(far + near)
		expect(stats.culled).toBe(far)
		expect(#world.errors).toBe(0)
	end)
end)
