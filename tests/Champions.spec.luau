-- End-to-end test of the champions (WP10 part 2, Brotato's elites with phases): each one called with the debug
-- button attacks, shows its HP bar, changes phase and drops a legendary crate without ending the run; the Abbot lays
-- eggs; and the run's elite wave (11 or 12) brings one champion with 75 % HP that grows with the wave. Real server
-- and client bootstraps in a simulated Roblox (tests/helpers/RobloxMock), like tests/Boss.spec.luau. Look and feel:
-- Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local BossService = require(Services.BossService)
local CombatService = require(Services.CombatService)
local EnemySim = require(Services.EnemySim)
local LootService = require(Services.LootService)
local RunDirector = require(Services.RunDirector)
local UpgradeService = require(Services.UpgradeService)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RunSchedule = require(game:GetService("ReplicatedStorage").Shared.Util.RunSchedule)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local EliteWaves = Config.Enemies.eliteWaves

local function controller(name)
	return require(folderProxy("src/client", "Client").Controllers[name])
end

local function heal()
	CombatService.healPlayer(me, 1e6)
end

-- Runs a debug button (healing first: champions hit hard).
local function click(name)
	heal()
	world.click(world.gui("Debug", name))
	world.advance(0.2)
end

local function pickupsOf(kind: string): number
	local count = 0
	for _, pickup in LootService.getPickups() do
		if pickup.kind == kind then
			count += 1
		end
	end
	return count
end

-- Advances up to `seconds` in small steps (healing the player) until `check` is true.
local function waitFor(seconds: number, check: () -> boolean): boolean
	local waited = 0
	while waited < seconds do
		if check() then
			return true
		end
		heal()
		world.advance(0.1)
		waited += 0.1
	end
	return check()
end

local function countOf(enemyId: string): number
	local ids = {}
	local count = 0
	for k = 1, EnemySim.collectIds(ids) do
		if EnemySim.getKind(ids[k]) == enemyId then
			count += 1
		end
	end
	return count
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

describe("champions", function()
	it("plans one elite wave in wave 11 or 12 with one champion", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(3.5)
		expect(RunDirector.getPhase()).toBe("Running")
		local plan = BossService.getEliteWaves()
		local waves = 0
		for wave, ids in plan do
			waves += 1
			expect(table.find(EliteWaves.slots[1], wave) ~= nil).toBe(true)
			expect(#ids).toBe(EliteWaves.count)
			expect(Config.Enemies.champions[ids[1]] ~= nil).toBe(true)
		end
		expect(waves).toBe(EliteWaves.activeSlots)
		LootService.setDropsPaused(true)
		click("ToggleWeapons")
		click("ToggleSpawning")
		click("HoldWaves")
	end)

	it("brings every champion: it attacks, shows its bar, changes phase and drops a legendary crate", function()
		for index, championId in EliteWaves.order do
			click("KillEnemies") -- what the last one summoned
			local kind = Config.Enemies.champions[championId]
			click("SpawnChampion")
			local champions = BossService.getBosses()
			expect(#champions).toBe(1)
			expect(champions[1].bossId).toBe(championId)
			expect(champions[1].role).toBe("Champion")
			-- grown like a champion of the first elite wave, though this is wave 1
			local _, elite = EnemySim.getKind(champions[1].id)
			expect(elite).toBe(true)
			expect(EnemySim.getMaxHealth(champions[1].id) > kind.hp * 1000).toBe(true)
			local shotsBefore = EnemySim.getShotCount()
			local attacked = waitFor(10, function()
				local warnings = controller("BossController").getCounts()
				return warnings > 0 or EnemySim.getShotCount() > shotsBefore
			end)
			if not attacked then
				error(`{championId} never attacked`)
			end
			expect(string.find(controller("BossController").getBarText(), kind.displayName, 1, true) ~= nil).toBe(true)
			click("HurtBoss")
			click("HurtBoss")
			local changed = waitFor(6, function()
				local list = BossService.getBosses()
				return list[1] ~= nil and list[1].phase >= 2
			end)
			if not changed then
				error(`{championId} did not change phase`)
			end
			click("HurtBoss")
			click("HurtBoss")
			expect(#BossService.getBosses()).toBe(0)
			world.advance(0.3)
			expect(RunDirector.getPhase()).toBe("Running")
			local _, waiting = UpgradeService.getCrate(me)
			expect(pickupsOf("Legendary") + waiting).toBe(index) -- on the floor, or already picked up
		end
	end)

	it("lets the Abbot lay its eggs", function()
		click("KillEnemies")
		-- the debug order goes round: call champions until the Abbot comes
		for _ = 1, #EliteWaves.order do
			click("SpawnChampion")
			if BossService.getBosses()[1].bossId == "Abbot" then
				break
			end
			click("KillEnemies")
		end
		expect(BossService.getBosses()[1].bossId).toBe("Abbot")
		local laid = waitFor(6, function()
			return countOf("BroodEgg") > 0
		end)
		expect(laid).toBe(true)
		click("KillEnemies")
		expect(#BossService.getBosses()).toBe(0)
	end)

	it("gives each champion its own move: the Brood Matron's acid pools stay on the floor", function()
		click("KillEnemies")
		for _ = 1, #EliteWaves.order do
			click("SpawnChampion")
			if BossService.getBosses()[1].bossId == "BroodMatron" then
				break
			end
			click("KillEnemies")
		end
		expect(BossService.getBosses()[1].bossId).toBe("BroodMatron")
		local pooled = waitFor(8, function()
			return controller("BossController").getPoolCount() > 0
		end)
		expect(pooled).toBe(true)
		waitFor(1.5, function()
			return false
		end)
		expect(controller("BossController").getPoolCount() > 0).toBe(true) -- still there after its strike
		click("KillEnemies")
	end)

	it("brings its champion with the elite wave, with 75 % HP grown by the wave", function()
		click("SkipWave")
		expect(RunDirector.getPhase()).toBe("Shop")
		pickLevels()
		local eliteWave = next(BossService.getEliteWaves()) :: number
		local championId = BossService.getEliteWaves()[eliteWave][1]
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Running")
		click("HoldWaves") -- the timer runs again for the skip
		RunDirector.skipTo(RunSchedule.wave(eliteWave - 1).endsAt)
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Shop")
		pickLevels()
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.3)
		expect(RunDirector.getWave()).toBe(eliteWave)
		expect(BossService.getPendingCount()).toBe(EliteWaves.count)
		world.advance(EliteWaves.introSeconds + 0.2)
		local champions = BossService.getBosses()
		expect(#champions).toBe(1)
		expect(champions[1].bossId).toBe(championId)
		expect(champions[1].wave).toBe(true)
		local kind = Config.Enemies.champions[championId]
		local steps = Config.Run.spawn.growth.hpSteps[eliteWave]
		local expected = (kind.hp + kind.hpPerWave * steps) * EliteWaves.reducedHpShare
		local maxHp = EnemySim.getMaxHealth(champions[1].id)
		expect(math.abs(maxHp / expected - 1) < 0.01).toBe(true)
		local before = pickupsOf("Legendary")
		local _, waitingBefore = UpgradeService.getCrate(me)
		for _ = 1, 4 do
			click("HurtBoss")
		end
		world.advance(0.3)
		expect(#BossService.getBosses()).toBe(0)
		expect(RunDirector.getPhase()).toBe("Running") -- a champion's death does not end the run
		local _, waiting = UpgradeService.getCrate(me)
		expect(pickupsOf("Legendary") + waiting).toBe(before + waitingBefore + 1)
	end)
end)
