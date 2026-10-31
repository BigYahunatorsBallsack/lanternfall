-- End-to-end test of progress and unlocks (Paket 13): locked characters cannot be picked, the lobby's danger level is
-- capped by what someone has opened with their character, a finished run pays Embers and achievements (results
-- screen, lobby record, achievement window), and the debug button unlocks everything.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

runScript(ServerScriptService.Server, "init.server.luau")
local PlayerDataService = require(Services.PlayerDataService)
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)
local WeaponService = require(Services.WeaponService)

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
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

describe("progress", function()
	it("shows locked characters with what unlocks them and refuses them", function()
		local button = world.gui("Lobby", "ManyHands")
		expect(string.find(button.Text, "LOCKED: Reach wave 10", 1, true) ~= nil).toBe(true)
		expect(world.gui("Lobby", "BladeWarden").Text).toBe("Blade Warden")
		world.click(button)
		world.advance(0.3)
		expect(RunStateController.getLocalPlayer().classId).toBe(Config.Run.flow.defaultClassId)
		expect(hasToast("This character is not unlocked yet")).toBe(true)
	end)

	it("caps the lobby's danger level at what someone has opened", function()
		world.click(world.gui("Lobby", "Danger3"))
		world.advance(0.3)
		expect(RunStateController.get().options.danger).toBe(0)
		expect(hasToast("Danger 3 is locked")).toBe(true)
		-- the peer has won danger 2 with Blade Warden: danger 3 opens for the whole lobby
		PlayerDataService.get(peer).characterStats.BladeWarden = { runs = 1, wins = 1, bestWave = 20, bestDanger = 2 }
		world.fireServerAs(peer, "SetRunOptions", 3, false, 100, 100, 100)
		world.advance(0.3)
		expect(RunStateController.get().options.danger).toBe(3)
		world.fireServerAs(me, "SetRunOptions", 4, false, 100, 100, 100)
		world.advance(0.3)
		expect(RunStateController.get().options.danger).toBe(3)
		-- the peer leaves: nobody has it open any more
		world.removePlayer(peer)
		world.advance(0.3)
		expect(RunStateController.get().options.danger).toBe(0)
	end)

	it("pays Embers and achievements for a finished run", function()
		world.fireServerAs(me, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		WeaponService.setPaused(true)
		world.advance(125)
		RunDirector.endRun("Defeat")
		world.advance(0.5)
		local minutes = math.floor(RunStateController.get().results.survivedSeconds / 60)
		expect(minutes >= 0).toBe(true)
		-- B11 part 2: a defeat that could still be retried is saved once the results are over
		local rewards = world.gui("Results", "Rewards")
		expect(rewards.Visible).toBe(true)
		expect(rewards.Text).toBe("Embers are saved when the results end, unless the wave is retried")
		local data = PlayerDataService.get(me)
		expect(data.achievements.FirstNight).toBe(nil)
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
		expect(data.achievements.FirstNight).toBe(true)
		local embers = minutes * Config.Economy.embers.perMinuteSurvived + 50
		expect(data.embers).toBe(embers + Config.Quests.streak.days[1].embers) -- Paket 18: login streak day 1
		expect(hasToast("Achievement: First Night")).toBe(true)
		expect(hasToast(`Run saved: +{embers} Embers`)).toBe(true)
		expect(string.find(world.gui("Lobby", "Record").Text, `{data.embers} Embers`, 1, true) ~= nil).toBe(true)
	end)

	it("lists the achievements in a window", function()
		local open = world.gui("Lobby", "OpenAchievements")
		expect(open.Text).toBe(`ACHIEVEMENTS 1/{#Config.Progress.achievements}`)
		world.click(open)
		expect(world.gui("Lobby", "Achievements").Visible).toBe(true)
		local row = world.gui("Lobby", "Achievement_DeepNight")
		expect(
			string.find(row.Text, `Deep Into the Night · {PlayerDataService.get(me).stats.bestWave}/10`, 1, true)
				~= nil
		).toBe(true)
		expect(string.find(row.Text, "unlocks Many Hands", 1, true) ~= nil).toBe(true)
		expect(string.find(world.gui("Lobby", "Achievement_FirstNight").Text, "DONE", 1, true) ~= nil).toBe(true)
		world.click(world.gui("Lobby", "CloseAchievements"))
		expect(world.gui("Lobby", "Achievements").Visible).toBe(false)
	end)

	it("unlocks everything with the debug button", function()
		world.fireServerAs(me, "DebugCommand", "UnlockAll")
		world.advance(0.3)
		expect(world.gui("Lobby", "ManyHands").Text).toBe("Many Hands")
		world.click(world.gui("Lobby", "ManyHands"))
		world.advance(0.3)
		expect(RunStateController.getLocalPlayer().classId).toBe("ManyHands")
		world.click(world.gui("Lobby", "Danger5"))
		world.advance(0.3)
		expect(RunStateController.get().options.danger).toBe(5)
		expect(PlayerDataService.isUnlocked(me, "items", "LanternCodex")).toBe(true)
	end)

	it("finished without any runtime error", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n\n"))
		end
	end)
end)
