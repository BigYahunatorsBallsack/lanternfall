-- End-to-end test of the danger levels and endless mode (B11): the lobby panel sets the options for the whole lobby,
-- danger 5 makes enemies stronger and brings two bosses, and in endless mode the run goes on past the boss wave
-- until nobody is left, which counts as a win. Real server and client bootstraps in a simulated Roblox
-- (tests/helpers/RobloxMock), like tests/Boss.spec.luau. Look and feel: Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local BossService = require(Services.BossService)
local CombatService = require(Services.CombatService)
local DangerService = require(Services.DangerService)
local EnemySim = require(Services.EnemySim)
local LootService = require(Services.LootService)
local MapService = require(Services.MapService)
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)
local SpawnRules = require(Services.SpawnDirector.SpawnRules)
local UpgradeService = require(Services.UpgradeService)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)
local RunSchedule = require(Shared.Util.RunSchedule)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local function heal()
	CombatService.healPlayer(me, 1e6)
end

local function click(name)
	heal()
	world.click(world.gui("Debug", name))
	world.advance(0.2)
end

local function pickLevels()
	for _ = 1, 40 do
		if not (UpgradeService.getOffer(me) or UpgradeService.getCrate(me)) then
			break
		end
		world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
		if UpgradeService.getCrate(me) then
			world.click(world.gui("LevelUp", "Take"))
		else
			world.click(world.gui("LevelUp", "Card1"))
		end
		world.advance(0.1)
	end
end

local function nextWave()
	pickLevels()
	world.fireServerAs(me, "SetShopReady", true)
	world.advance(0.3)
	expect(RunDirector.getPhase()).toBe("Running")
end

-- Max HP of a freshly spawned enemy of `enemyId` next to the player.
local function spawnedHp(enemyId: string): number
	click("KillEnemies")
	expect(SpawnDirector.spawnEnemy(enemyId, MapService.getRootPosition(me) :: Vector3)).toBe(true)
	local ids = {}
	local count = EnemySim.collectIds(ids)
	expect(count).toBe(1)
	return EnemySim.getMaxHealth(ids[1])
end

describe("danger levels", function()
	it("picks danger level and endless mode in the lobby for everyone", function()
		local state = function()
			return require(folderProxy("src/client", "Client").Controllers.RunStateController).get()
		end
		expect(state().options.danger).toBe(0)
		world.click(world.gui("Lobby", "Danger5"))
		world.advance(0.3)
		world.click(world.gui("Lobby", "Endless"))
		world.advance(0.3)
		expect(state().options.danger).toBe(5)
		expect(state().options.endless).toBe(true)
		expect(world.gui("Lobby", "Endless").Text).toBe("ENDLESS: ON")
		-- out of range is refused by the remote
		world.fireServerAs(me, "SetRunOptions", 9, true, 100, 100, 100)
		world.advance(0.3)
		expect(state().options.danger).toBe(5)
	end)

	it("leaves the new enemies out below danger 1", function()
		for _, group in SpawnRules.groupsAt(10.5, 0) do
			expect(DangerRules.isNewEnemy(group.enemy)).toBe(false)
		end
		local any = false
		for _, group in SpawnRules.groupsAt(10.5, 1) do
			any = any or DangerRules.isNewEnemy(group.enemy)
		end
		expect(any).toBe(true)
	end)

	it("makes enemies 40 % stronger on danger 5", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(3.5)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(RunDirector.getDifficulty()).toBe("Danger 5 · Endless")
		LootService.setDropsPaused(true)
		click("ToggleWeapons")
		click("ToggleSpawning")
		click("HoldWaves")
		expect(spawnedHp("Brute")).toBeNear(Config.Enemies.types.Brute.hp * 1.4)
		local challenges = 0
		for _ in DangerService.getPlan() do
			challenges += 1
		end
		expect(challenges).toBe(3)
	end)

	it("brings two bosses with 75 % HP, and killing them does not end an endless run", function()
		click("SkipToBoss")
		expect(RunDirector.getPhase()).toBe("Shop")
		nextWave()
		expect(RunDirector.getWave()).toBe(20)
		world.advance(Config.Enemies.bossWave.introSeconds + 0.3)
		local bosses = BossService.getBosses()
		local count = 0
		for _, boss in bosses do
			if boss.role == "Boss" then
				count += 1
				local kind = Config.Enemies.bosses[boss.bossId]
				expect(EnemySim.getMaxHealth(boss.id)).toBeNear(kind.hp * 0.75 * 1.4)
			end
		end
		expect(count).toBe(2)
		for _ = 1, 4 do
			click("HurtBoss")
		end
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(RunDirector.getWave()).toBe(20)
	end)

	it("goes on with endless waves that grow by Brotato's endless factor", function()
		click("KillEnemies")
		click("HoldWaves") -- the timer runs again for the skip
		click("SkipWave")
		expect(RunDirector.getPhase()).toBe("Shop")
		nextWave()
		click("HoldWaves")
		expect(RunDirector.getWave()).toBe(21)
		local hpGrowth = SpawnRules.growth("Brute", 21)
		local dangerHp = DangerRules.multipliers(RunDirector.getRunOptions(), 21)
		expect(dangerHp).toBeNear(1.4 * (1 + 0.02 * 2.25))
		expect(spawnedHp("Brute")).toBeNear(Config.Enemies.types.Brute.hp * hpGrowth * dangerHp)
		expect(world.gui("HUD", "WaveTitle").Text).toBe("WAVE 21")
	end)

	it("counts dying in an endless wave as a win", function()
		click("KillEnemies")
		RunDirector.setParticipantState(me, "Out")
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Ended")
		local results = require(folderProxy("src/client", "Client").Controllers.RunStateController).get().results
		expect(results.outcome).toBe("Victory")
		expect(results.wave).toBe(21)
	end)
end)
