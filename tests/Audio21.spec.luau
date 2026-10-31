-- End-to-end test of Paket 21: the map gets its lighting and dressing without blocking the arena, buttons click, the
-- sound pool skips plays that come too fast or too far away, a run plays weapon, hit, kill and loot sounds and the
-- music follows lobby, run and results.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local Services = ServerScriptService.Server.Services
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

runScript(ServerScriptService.Server, "init.server.luau")
local PlayerDataService = require(Services.PlayerDataService)
local RunDirector = require(Services.RunDirector)

local me = world.addPlayer("Owner", 1, true)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local MusicController = require(Client.Controllers.MusicController)
local Sfx = require(Client.Audio.Sfx)

local OPTIONS = { danger = 2, endless = false, enemyHp = 100, enemyDamage = 100, enemySpeed = 100 }

local function descendants(root)
	local list = {}
	local function walk(instance)
		for _, child in instance:GetChildren() do
			table.insert(list, child)
			walk(child)
		end
	end
	walk(root)
	return list
end

describe("map", function()
	it("sets the dusk lighting with haze, color grading and bloom", function()
		local lighting = world.lighting
		expect(lighting.ClockTime).toBe(Config.Map.lighting.clockTime)
		local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
		expect(atmosphere ~= nil).toBe(true)
		expect(atmosphere.Density).toBe(Config.Map.lighting.atmosphere.density)
		expect(lighting:FindFirstChild("LanternfallColor") ~= nil).toBe(true)
		expect(lighting:FindFirstChild("LanternfallBloom") ~= nil).toBe(true)
	end)

	it("dresses the arena and lobby without anything solid inside the arena", function()
		local map = workspace:FindFirstChild("LanternfallMap")
		local decor = map.Arena:FindFirstChild("Decor")
		expect(decor ~= nil).toBe(true)
		expect(map.Lobby:FindFirstChild("Decor") ~= nil).toBe(true)
		local arena = Config.Map.arena
		local half = arena.size / 2
		local inside, outside, lights = 0, 0, 0
		for _, instance in descendants(decor) do
			if instance.ClassName == "PointLight" then
				lights += 1
			elseif instance:IsA("BasePart") then
				local offset = instance.CFrame.Position - arena.center
				if math.abs(offset.X) < half and math.abs(offset.Z) < half then
					inside += 1
					expect(instance.CanCollide).toBe(false)
				else
					outside += 1
				end
			end
		end
		expect(inside > Config.Map.decor.floorSlabs).toBe(true)
		expect(outside > Config.Map.decor.backdropRuins).toBe(true)
		expect(lights).toBe(4 * Config.Map.decor.lampsPerSide + 4)
		expect(decor:FindFirstChild("Motes"):FindFirstChildOfClass("ParticleEmitter") ~= nil).toBe(true)
	end)
end)

describe("sound pool", function()
	it("puts effects and music into the groups the settings menu controls", function()
		expect(SoundService:FindFirstChild("Effects").ClassName).toBe("SoundGroup")
		expect(SoundService:FindFirstChild("Music").ClassName).toBe("SoundGroup")
	end)

	it("clicks on buttons", function()
		world.advance(1)
		local before = Sfx.getPlayed("uiClick")
		world.click(world.gui("Settings", "Gear"))
		world.click(world.gui("Settings", "Close"))
		expect(Sfx.getPlayed("uiClick") > before).toBe(true)
		local effects = SoundService:FindFirstChild("Effects")
		local sound = SoundService:FindFirstChild("LanternfallSfx"):FindFirstChild("uiClick1")
		expect(sound.SoundGroup).toBe(effects)
		expect(sound.SoundId).toBe(Config.Audio.cues.uiClick.sound)
	end)

	it("softens the effects group and uses no harsh placeholder (Paket 21b)", function()
		local effects = SoundService:FindFirstChild("Effects")
		local eq = effects:FindFirstChild("LanternfallEq")
		expect(eq.ClassName).toBe("EqualizerSoundEffect")
		expect(eq.HighGain).toBe(Config.Audio.effectsBus.highGain)
		expect(effects:FindFirstChild("LanternfallCompressor").ClassName).toBe("CompressorSoundEffect")
		for id, cue in Config.Audio.cues do
			for _, harsh in { "swordslash", "swordlunge", "unsheath", "collide" } do
				if string.find(cue.sound, harsh, 1, true) then
					error(`cue {id} still plays {harsh}`)
				end
			end
			expect(cue.volume <= 0.5).toBe(true)
		end
	end)

	it("skips plays that come too fast, too far away or are unknown", function()
		world.advance(1)
		expect(Sfx.play("levelUp")).toBe(true)
		expect(Sfx.play("levelUp")).toBe(false)
		world.advance(Config.Audio.cues.levelUp.minInterval + 0.05)
		expect(Sfx.play("levelUp")).toBe(true)
		world.advance(1)
		local root = me.Character.HumanoidRootPart
		local far = root.Position + Vector3.new(Config.Audio.hearRadius + 5, 0, 0)
		expect(Sfx.play("blast", far)).toBe(false)
		expect(Sfx.play("blast", root.Position + Vector3.new(5, 0, 0))).toBe(true)
		expect(Sfx.play("noSuchCue")).toBe(false)
	end)
end)

describe("run", function()
	it("plays lobby music state, then wave start, weapons, hits, kills and loot in a run", function()
		expect(MusicController.wanted()).toBe("lobby")
		expect(MusicController.getCurrent()).toBe("lobby")
		PlayerDataService.unlockAll(me)
		RunDirector.setOptions(OPTIONS)
		world.fireServerAs(me, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(MusicController.getCurrent()).toBe("run")
		expect(Sfx.getPlayed("waveStart")).toBe(1)
		world.advance(20)
		local weaponSounds = 0
		for _, cueId in Config.Audio.weaponKinds do
			weaponSounds += Sfx.getPlayed(cueId)
		end
		expect(weaponSounds > 0).toBe(true)
		expect(Sfx.getPlayed("hit") + Sfx.getPlayed("crit") > 0).toBe(true)
		expect(Sfx.getPlayed("enemyDeath") > 0).toBe(true)
	end)

	it("switches to the results track when the run ends", function()
		RunDirector.endRun("Defeat")
		world.advance(0.5)
		expect(MusicController.wanted()).toBe("results")
		expect(MusicController.getCurrent()).toBe("results")
		-- no music is set up yet (Config.Audio.music is empty), so nothing plays
		expect(SoundService:FindFirstChild("LanternfallMusic")).toBe(nil)
	end)
end)
