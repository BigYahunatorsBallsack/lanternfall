-- End-to-end test of Paket 20 analytics: a new player goes through the onboarding funnel in order (joined, moved,
-- first kill, first level-up, 3 minutes, first run ended, back in the lobby, second run), waves send progression
-- events, Embers from the login streak, the run and the Ember shop send economy events, and the custom events (cards,
-- shop buys, what downed a player, retry wave, run end) carry their fields. The mock's AnalyticsService records every
-- call in world.analytics (tests/helpers/RobloxMock). Real server and client bootstraps, saved data in MemoryStore.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PlayerDataService = require(Services.PlayerDataService)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)
PlayerDataService.useStore(MemoryStore.new(ProfileTemplate.new()))

runScript(ServerScriptService.Server, "init.server.luau")
local AnalyticsService = require(Services.AnalyticsService)
local EnemySim = require(Services.EnemySim)
local LootService = require(Services.LootService)
local RunDirector = require(Services.RunDirector)
local ShopService = require(Services.ShopService)
local SpawnDirector = require(Services.SpawnDirector)
local UpgradeService = require(Services.UpgradeService)
local WeaponService = require(Services.WeaponService)

local me = world.addPlayer("Owner", 1, true)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
LootService.setDropsPaused(true)

local function calls(method: string, player: Player?): { any }
	local out = {}
	for _, call in world.analytics do
		if call.method == method and (player == nil or call.player == player) then
			table.insert(out, call)
		end
	end
	return out
end

local function funnelSteps(player: Player): string
	local names = {}
	for _, call in calls("LogOnboardingFunnelStepEvent", player) do
		table.insert(names, `{call.args[1]}:{call.args[2]}`)
	end
	return table.concat(names, ",")
end

local function custom(name: string, player: Player?): { any }
	local out = {}
	for _, call in calls("LogCustomEvent", player) do
		if call.args[1] == name then
			table.insert(out, call)
		end
	end
	return out
end

local function field(call, index: number): string?
	local fields = call.args[3]
	return fields and fields[`CustomField0{index}`]
end

local function economy(sku: string): any
	for _, call in calls("LogEconomyEvent", me) do
		if call.args[6] == sku then
			return call
		end
	end
	return nil
end

local function progression(method: string, wave: number): number
	local count = 0
	for _, call in calls(method, me) do
		if call.args[1] == "Danger0" and call.args[2] == wave then
			count += 1
		end
	end
	return count
end

describe("analytics", function()
	it("logs Joined and the login streak Embers when the data loads", function()
		expect(funnelSteps(me)).toBe("1:Joined")
		local streak = economy("Day1")
		expect(streak ~= nil).toBe(true)
		expect(streak.args[1]).toBe(Enum.AnalyticsEconomyFlowType.Source)
		expect(streak.args[2]).toBe("Embers")
		expect(streak.args[3]).toBe(Config.Quests.streak.days[1].embers)
		expect(streak.args[4]).toBe(PlayerDataService.get(me).embers)
		expect(streak.args[5]).toBe("TimedReward")
	end)

	it("logs Moved once the character walked a few studs", function()
		local root = me.Character:FindFirstChild("HumanoidRootPart")
		world.advance(Config.Analytics.onboarding.checkSeconds + 0.1)
		root.Position += Vector3.new(Config.Analytics.onboarding.movedStuds + 1, 0, 0)
		world.advance(Config.Analytics.onboarding.checkSeconds + 0.1)
		expect(funnelSteps(me)).toBe("1:Joined,2:Moved")
	end)

	it("starts wave 1 and logs the first kill and level-up", function()
		world.fireServerAs(me, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		WeaponService.setPaused(true)
		RunDirector.setHoldWaves(true)
		expect(progression("LogProgressionStartEvent", 1)).toBe(1)

		local id = EnemySim.spawn("Shadeling", 0, 0, 1, 1)
		EnemySim.damage(id :: number, 1e6, me)
		world.advance(0.1)
		expect(funnelSteps(me)).toBe("1:Joined,2:Moved,3:FirstKill")

		world.click(world.gui("Debug", "GainLevel"))
		world.advance(0.2)
		expect(funnelSteps(me)).toBe("1:Joined,2:Moved,3:FirstKill,4:FirstLevelUp")
	end)

	it("logs Played3Minutes after three minutes in the game", function()
		world.advance(Config.Analytics.onboarding.playedSeconds)
		expect(funnelSteps(me)).toBe("1:Joined,2:Moved,3:FirstKill,4:FirstLevelUp,5:Played3Minutes")
	end)

	it("completes the wave and logs the card offered and picked in the shop", function()
		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Shop")
		expect(progression("LogProgressionCompleteEvent", 1)).toBe(1)
		local offer = UpgradeService.getOffer(me)
		expect(offer ~= nil).toBe(true)
		local picked = (offer :: any)[2]
		world.fireServerAs(me, "ChooseUpgrade", picked.id)
		world.advance(0.2)
		local pickedCalls = custom("CardPicked", me)
		expect(#pickedCalls).toBe(1)
		expect(field(pickedCalls[1], 1)).toBe(picked.stat)
		expect(field(pickedCalls[1], 2)).toBe(tostring(picked.tier))
		expect(field(pickedCalls[1], 3)).toBe("Player")
		expect(#custom("CardOffered", me)).toBe(#(offer :: any))
	end)

	it("logs a shop buy and the start of wave 2", function()
		ShopService.addShards(me, 500)
		local offer = ShopService.getOffers(me)[1]
		world.fireServerAs(me, "BuyShopOffer", offer.id)
		world.advance(0.2)
		local bought = custom("ItemBought", me)
		expect(#bought).toBe(1)
		expect(field(bought[1], 1)).toBe(offer.kind)
		expect(field(bought[1], 2)).toBe(offer.itemId)
		expect(field(bought[1], 3)).toBe("1")

		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(progression("LogProgressionStartEvent", 2)).toBe(1)
	end)

	it("names what downed the player, fails the wave and logs the run end", function()
		local id = EnemySim.spawn("Shadeling", 0, 0, 1, 1)
		EnemySim.teleport(id :: number, EnemySim.getPlayerPosition(me) :: Vector3)
		EnemySim.Contact:Fire(me, 1e6)
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Ended")
		local downs = custom("PlayerDown", me)
		expect(#downs).toBe(1)
		expect(field(downs[1], 1)).toBe("Contact")
		expect(field(downs[1], 2)).toBe("Shadeling")
		expect(field(downs[1], 3)).toBe("2")
		expect(progression("LogProgressionFailEvent", 2)).toBe(1)
		local ended = custom("RunEnded", me)
		expect(#ended).toBe(1)
		expect(field(ended[1], 1)).toBe("Defeat")
		expect(field(ended[1], 2)).toBe("D0")
		expect(field(ended[1], 3)).toBe("1")
		expect(ended[1].args[2] > 0).toBe(true)
		expect(string.find(funnelSteps(me), "6:FirstRunEnded", 1, true) ~= nil).toBe(true)
	end)

	it("logs Retry wave and starts the wave again", function()
		world.fireServerAs(me, "RetryWave")
		world.advance(0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		local retries = custom("RetryWave", me)
		expect(#retries).toBe(1)
		expect(field(retries[1], 1)).toBe("2")
		expect(progression("LogProgressionStartEvent", 2)).toBe(2)
	end)

	it("logs the achievement Embers and Back in lobby after the results", function()
		EnemySim.Contact:Fire(me, 1e6)
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Ended")
		expect(economy("Achievement")).toBe(nil) -- a defeat that can be retried is saved later
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Lobby")
		local achievement = economy("Achievement") -- the first finished run completes an achievement
		expect(achievement ~= nil).toBe(true)
		expect(achievement.args[5]).toBe("Gameplay")
		expect(funnelSteps(me)).toBe(
			"1:Joined,2:Moved,3:FirstKill,4:FirstLevelUp,5:Played3Minutes,6:FirstRunEnded,7:BackInLobby"
		)
	end)

	it("logs SecondRun when the next run starts, and nothing more after that", function()
		world.fireServerAs(me, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		local steps = calls("LogOnboardingFunnelStepEvent", me)
		expect(#steps).toBe(8)
		expect(steps[8].args[2]).toBe("SecondRun")
		RunDirector.endRun("Abandoned")
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
		expect(#calls("LogOnboardingFunnelStepEvent", me)).toBe(8)
	end)

	it("logs the Embers of a recorded run as a source", function()
		local data = PlayerDataService.get(me)
		local before = data.embers
		PlayerDataService.recordRun(me, {
			won = false,
			wave = 9,
			danger = 1,
			classId = "BladeWarden",
			kills = 300,
			bossKills = 0,
			seconds = 600,
			champions = 0,
			revives = 0,
			players = 1,
		})
		local reward = economy("D1")
		expect(reward ~= nil).toBe(true)
		local minutes = 10 * Config.Economy.embers.perMinuteSurvived
		expect(reward.args[3]).toBe(minutes + math.floor(minutes * Config.Progress.embers.perDangerLevel))
		expect(reward.args[5]).toBe("Gameplay")
		expect(data.embers >= before + reward.args[3]).toBe(true)
	end)

	it("logs Embers spent in the Ember shop as a sink", function()
		local data = PlayerDataService.get(me)
		data.embers += 5000
		local lantern
		for _, cosmetic in Config.Cosmetics.lanterns do
			if (cosmetic.price or 0) > 0 and not cosmetic.vip and not cosmetic.reward then
				lantern = cosmetic
				break
			end
		end
		world.fireServerAs(me, "BuyWithEmbers", "Cosmetic", lantern.id)
		world.advance(0.2)
		local spent = economy(`Cosmetic:{lantern.id}`)
		expect(spent ~= nil).toBe(true)
		expect(spent.args[1]).toBe(Enum.AnalyticsEconomyFlowType.Sink)
		expect(spent.args[3]).toBe(lantern.price)
		expect(spent.args[4]).toBe(data.embers)
		expect(spent.args[5]).toBe("Shop")
	end)

	it("keeps the game running when Roblox's AnalyticsService throws", function()
		world.analyticsError = "HTTP 500"
		AnalyticsService.custom(me, "Revived", nil, { 3 })
		world.analyticsError = nil
		local entries = AnalyticsService.getLog()
		expect(string.find(entries[#entries].text, "Revived", 1, true) ~= nil).toBe(true)
	end)

	it("prints the log with the debug button", function()
		world.click(world.gui("Debug", "PrintAnalytics"))
		world.advance(0.2)
		local entries = AnalyticsService.getLog()
		expect(#entries > 0).toBe(true)
		expect(#entries <= Config.Analytics.logSize).toBe(true)
	end)
end)
