-- End-to-end test of Paket 19 "First Night" in a single server: a new player's first join goes straight into the
-- short, easier solo run (3 waves, First Night label and options), the hints follow the run (move, weapons and orbs,
-- shop, Looter), the Looter wave brings a Looter, surviving the last wave wins without counting as a win, the lobby gets
-- its options back and the lobby hint shows once. A second player who joins someone does not get one; Skip ends a
-- First Night and marks it done. Real server and client bootstraps, saved data in MemoryStore.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local RunSchedule = require(Shared.Util.RunSchedule)
local FirstNightService = require(Services.FirstNightService)
local PlayerDataService = require(Services.PlayerDataService)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)
PlayerDataService.useStore(MemoryStore.new(ProfileTemplate.new()))
FirstNightService.allowStudio(true)

runScript(ServerScriptService.Server, "init.server.luau")
local EnemySim = require(Services.EnemySim)
local LootService = require(Services.LootService)
local RunDirector = require(Services.RunDirector)

local FirstNight = Config.FirstNight

local me = world.addPlayer("Owner", 1, true)
local peer
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local FirstNightController = require(Client.Controllers.FirstNightController)
LootService.setDropsPaused(true)

local function countKind(kind: string): number
	local ids = {}
	local count = 0
	for i = 1, EnemySim.collectIds(ids) do
		if EnemySim.getKind(ids[i]) == kind then
			count += 1
		end
	end
	return count
end

local function hasText(screenName: string, text: string): boolean
	for _, object in world.gui(screenName):GetDescendants() do
		if object.ClassName == "TextLabel" and object.Text == text then
			return true
		end
	end
	return false
end

local function root(player)
	return player.Character.HumanoidRootPart
end

-- Ends the current wave and, unless it was the last one, presses READY in its shop.
local function finishWave(shop: boolean)
	local wave = RunDirector.getWave()
	RunDirector.skipTo(RunSchedule.wave(wave).endsAt)
	world.advance(0.2)
	if shop then
		expect(RunDirector.getPhase()).toBe("Shop")
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.2)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(RunDirector.getWave()).toBe(wave + 1)
	end
end

describe("First Night", function()
	it("starts by itself for a new player", function()
		expect(FirstNightService.isPending(me)).toBe(true)
		expect(RunDirector.getPhase()).toBe("Lobby")
		world.advance(FirstNight.startDelaySeconds + 0.2)
		expect(RunDirector.getPhase()).toBe("Countdown")
		world.advance(Config.Run.flow.countdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		local options = RunDirector.getRunOptions()
		expect(options.firstNight).toBe(true)
		expect(options.enemyHp).toBe(FirstNight.options.enemyHp)
		expect(options.enemyDamage).toBe(FirstNight.options.enemyDamage)
		expect(RunDirector.getDifficulty()).toBe(FirstNight.label)
		expect(#RunDirector.getParticipants()).toBe(1)
	end)

	it("shows the short run on the HUD and the move hint until the character walks", function()
		world.advance(0.2)
		expect(hasText("HUD", `Wave 1 / {FirstNight.waves}`)).toBe(true)
		expect(FirstNightController.getHint()).toBe("move")
		local part = root(me)
		part.Position = part.Position + Vector3.new(FirstNight.moveStuds + 1, 0, 0)
		world.advance(0.1)
		expect(FirstNightController.getHint()).toBe("fight")
		world.advance(FirstNight.hintSeconds + 0.1)
		expect(FirstNightController.getHint()).toBe(nil)
	end)

	it("explains the shop while it is open", function()
		local wave = RunDirector.getWave()
		RunDirector.skipTo(RunSchedule.wave(wave).endsAt)
		world.advance(0.2)
		expect(RunDirector.getPhase()).toBe("Shop")
		expect(FirstNightController.getHint()).toBe("shop")
		expect(hasText("HUD", `Shop · wave 2 / {FirstNight.waves} next`)).toBe(true)
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.2)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(FirstNightController.getHint() ~= "shop").toBe(true)
	end)

	it("brings a Looter in the Looter wave and points it out", function()
		while RunDirector.getWave() < FirstNight.looterWave do
			finishWave(true)
		end
		world.advance(0.2)
		expect(FirstNightController.getHint()).toBe("looter")
		expect(countKind("Looter")).toBe(0)
		world.advance(FirstNight.looterDelaySeconds + 0.2)
		expect(countKind("Looter") >= 1).toBe(true)
		expect(hasText("HUD", `Final wave {FirstNight.waves} / {FirstNight.waves}`)).toBe(true)
	end)

	it("wins after the last wave without counting as a win", function()
		while RunDirector.getWave() < FirstNight.waves do
			finishWave(true)
		end
		finishWave(false)
		expect(RunDirector.getPhase()).toBe("Ended")
		local data = PlayerDataService.get(me) :: any
		expect(data.stats.runs).toBe(1)
		expect(data.stats.wins).toBe(0)
		expect(data.stats.bestDanger).toBe(-1)
		expect(data.characterStats.BladeWarden.wins).toBe(0)
		expect(data.tutorial.firstNight).toBe(true)
		expect(data.achievements.FirstNight).toBe(true)
		expect(FirstNightService.isPending(me)).toBe(false)
		expect(FirstNightController.getHint()).toBe(nil)
	end)

	it("gives the lobby its options back and shows the lobby hint once", function()
		expect(RunDirector.getRunOptions().firstNight).toBe(true)
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Lobby")
		world.advance(0.2)
		expect(FirstNightController.isLobbyHintOpen()).toBe(true)
		expect((PlayerDataService.get(me) :: any).tutorial.lobbyHint).toBe(false)
		world.click(world.gui("FirstNight", "Ok"))
		expect(FirstNightController.isLobbyHintOpen()).toBe(false)
		-- the next run is a normal one
		world.fireServerAs(me, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(RunDirector.getRunOptions().firstNight).toBe(nil)
		expect(RunDirector.getDifficulty() ~= FirstNight.label).toBe(true)
		RunDirector.endRun("Abandoned")
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Lobby")
	end)

	it("does not start one for a newcomer who joins someone", function()
		peer = world.addPlayer("Peer", 2, false)
		world.advance(FirstNight.startDelaySeconds + 0.5)
		expect(FirstNightService.isPending(peer)).toBe(true)
		expect(RunDirector.getPhase()).toBe("Lobby")
	end)

	it("skips a First Night with Skip and marks it done", function()
		expect(FirstNightService.launch(peer)).toBe(true)
		world.advance(Config.Run.flow.countdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(RunDirector.getRunOptions().firstNight).toBe(true)
		world.fireServerAs(me, "SkipFirstNight") -- not in this run
		world.advance(0.1)
		expect(RunDirector.getPhase()).toBe("Running")
		world.fireServerAs(peer, "SkipFirstNight")
		world.advance(0.1)
		expect(RunDirector.getPhase()).toBe("Ended")
		local data = PlayerDataService.get(peer) :: any
		expect(data.tutorial.firstNight).toBe(true)
		expect(data.stats.runs).toBe(0)
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Lobby")
		expect(data.tutorial.lobbyHint).toBe(false) -- sent to the peer's client
		expect(FirstNightController.isLobbyHintOpen()).toBe(false) -- not to mine
	end)

	it("starts one from the debug button", function()
		world.click(world.gui("Debug", "StartFirstNight"))
		world.advance(0.2)
		expect(RunDirector.getPhase()).toBe("Countdown")
		world.advance(Config.Run.flow.countdownSeconds + 0.5)
		expect(RunDirector.getRunOptions().firstNight).toBe(true)
		expect(#RunDirector.getParticipants()).toBe(1)
	end)
end)
