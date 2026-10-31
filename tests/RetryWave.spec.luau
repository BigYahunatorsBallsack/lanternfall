-- End-to-end test of "Retry wave" (B11 part 2): after a defeat the results offer a retry, which starts the lost wave
-- again with exactly the state it started with (team level and XP, Shards, items, stats, weapons, HP) and every
-- player standing; the defeat is only saved to the record once the results are over. Real server and client
-- bootstraps in a simulated Roblox (tests/helpers/RobloxMock), saved data in MemoryStore.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PlayerDataService = require(Services.PlayerDataService)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)
PlayerDataService.useStore(MemoryStore.new(ProfileTemplate.new()))

runScript(ServerScriptService.Server, "init.server.luau")
local CombatService = require(Services.CombatService)
local ExperienceService = require(Services.ExperienceService)
local RunDirector = require(Services.RunDirector)
local RunStatsService = require(Services.RunStatsService)
local ShopService = require(Services.ShopService)
local SpawnDirector = require(Services.SpawnDirector)
local StatService = require(Services.StatService)
local WeaponService = require(Services.WeaponService)

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)

-- Some item without a limit, for changes during the wave.
local itemId = (function()
	for _, item in Config.Items.list do
		if not item.limit and item.tier == 1 then
			return item.id
		end
	end
	error("no item without a limit")
end)()

local function weaponLine(player)
	local parts = {}
	for _, weapon in WeaponService.getWeapons(player) do
		table.insert(parts, `{weapon.id}:{weapon.tier}`)
	end
	return table.concat(parts, ",")
end

local function snapshot(player)
	local hp, maxHp = CombatService.getHp(player)
	return {
		level = ExperienceService.getLevel(),
		xp = ExperienceService.getProgress().xp,
		shards = ShopService.getShards(player),
		items = StatService.getItemCounts(player)[itemId] or 0,
		maxHpStat = StatService.getStat(player, "maxHp"),
		weapons = weaponLine(player),
		hp = hp,
		maxHp = maxHp,
		kills = RunStatsService.getTally().kills,
	}
end

local atStart

local function loseTheWave()
	RunDirector.setParticipantState(me, "Down")
	RunDirector.setParticipantState(peer, "Down")
	world.advance(0.2)
	expect(RunDirector.getPhase()).toBe("Ended")
end

describe("retry wave", function()
	it("saves the state a wave starts with", function()
		world.fireServerAs(me, "SetReady", true)
		world.fireServerAs(peer, "SetReady", true)
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		SpawnDirector.setPaused(true)
		WeaponService.setPaused(true)
		RunDirector.setHoldWaves(true)
		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Shop")
		ShopService.addShards(me, 40)
		StatService.addItem(me, itemId)
		world.fireServerAs(me, "SetShopReady", true)
		world.fireServerAs(peer, "SetShopReady", true)
		world.advance(0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(RunDirector.getWave()).toBe(2)
		atStart = snapshot(me)
	end)

	it("offers a retry on the results after a defeat", function()
		-- what happens in the lost wave: levels, Shards, an item, a weapon, damage taken, kills
		ExperienceService.grantLevel()
		ExperienceService.grantLevel()
		ShopService.addShards(me, 25)
		StatService.addItem(me, itemId)
		WeaponService.addWeapon(me, WeaponService.getWeapons(me)[1].id)
		RunStatsService.getTally():recordKill("Shadeling")
		world.advance(0.6) -- past the protection the wave starts with
		CombatService.damagePlayer(me, 20)
		local changed = snapshot(me)
		expect(changed.hp < changed.maxHp).toBe(true)
		expect(changed.level).toBe(atStart.level + 2)
		expect(changed.shards).toBe(atStart.shards + 25)
		expect(changed.items).toBe(atStart.items + 1)
		expect(changed.weapons ~= atStart.weapons).toBe(true)

		loseTheWave()
		local retry = world.gui("Results", "RetryWave")
		expect(retry.Visible).toBe(true)
		expect(retry.Text).toBe(`RETRY WAVE 2 ({Config.Run.flow.maxRetries} left)`)
		expect(world.gui("Results", "Rewards").Text).toBe(
			"Embers are saved when the results end, unless the wave is retried"
		)
		expect(PlayerDataService.get(me).stats.runs).toBe(0) -- held back while a retry is possible
	end)

	it("starts the lost wave again with exactly its start state", function()
		world.click(world.gui("Results", "RetryWave"))
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(RunDirector.getWave()).toBe(2)
		expect(RunDirector.getElapsed()).toBeNear(Config.Run.spawn.waves.lengthsSeconds[1], 0.01)
		expect(RunDirector.getParticipantState(me)).toBe("Alive")
		expect(RunDirector.getParticipantState(peer)).toBe("Alive")
		local now = snapshot(me)
		for key, value in atStart do
			expect(`{key}={now[key]}`).toBe(`{key}={value}`)
		end
		expect(world.gui("Results").Enabled).toBe(false)
		expect(PlayerDataService.get(me).stats.runs).toBe(0)
	end)

	it("counts the retries down", function()
		loseTheWave()
		expect(world.gui("Results", "RetryWave").Text).toBe(`RETRY WAVE 2 ({Config.Run.flow.maxRetries - 1} left)`)
	end)

	it("saves the defeat once when the results are over", function()
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Lobby")
		expect(PlayerDataService.get(me).stats.runs).toBe(1)
		expect(PlayerDataService.get(peer).stats.runs).toBe(1)
	end)

	it("finished without any runtime error", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n\n"))
		end
	end)
end)
