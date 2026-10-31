-- End-to-end test of the boss package (WP10): a test boss in an early wave (its warnings, HP bar, phases and the
-- legendary crate it drops), the legendary crate itself, and the boss wave at the end of the run that is won by
-- killing its boss. Real server and client bootstraps in a simulated Roblox (tests/helpers/RobloxMock), like
-- tests/Loot.spec.luau. Look and feel: Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local BossService = require(Services.BossService)
local CombatService = require(Services.CombatService)
local EnemySim = require(Services.EnemySim)
local LootService = require(Services.LootService)
local MapService = require(Services.MapService)
local RunDirector = require(Services.RunDirector)
local UpgradeService = require(Services.UpgradeService)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RunSchedule = require(game:GetService("ReplicatedStorage").Shared.Util.RunSchedule)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local function controller(name)
	return require(folderProxy("src/client", "Client").Controllers[name])
end

local function heal()
	CombatService.healPlayer(me, 1e6)
end

-- Runs a debug button (healing first: a boss hits hard, at most once per hit protection).
local function click(name)
	heal()
	world.click(world.gui("Debug", name))
	world.advance(0.2)
end

local function position(): Vector3
	return MapService.getRootPosition(me) :: Vector3
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

-- Advances `seconds` in small steps, healing the player in between (a boss alive hits hard).
local function advanceHealing(seconds: number)
	for _ = 1, math.round(seconds / 0.1) do
		heal()
		world.advance(0.1)
	end
	heal()
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

describe("bosses", function()
	it("starts a run with weapons off, spawning paused and the wave timer held", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(3.5)
		expect(RunDirector.getPhase()).toBe("Running")
		LootService.setDropsPaused(true)
		click("ToggleWeapons")
		click("ToggleSpawning")
		click("HoldWaves")
	end)

	it("spawns a test boss with an HP bar and a glowing model", function()
		click("SpawnBoss")
		local bosses = BossService.getBosses()
		expect(#bosses).toBe(1)
		expect(bosses[1].bossId).toBe(Config.Enemies.bossWave.order[1])
		expect(bosses[1].wave).toBe(false)
		advanceHealing(0.5)
		local kind = Config.Enemies.bosses[bosses[1].bossId]
		local text = controller("BossController").getBarText()
		expect(string.find(text, kind.displayName, 1, true) ~= nil).toBe(true)
		expect(string.find(text, `Phase 1 of {#kind.boss.phases}`, 1, true) ~= nil).toBe(true)
		local model = workspace:FindFirstChild("LanternfallEnemies"):FindFirstChild(kind.id)
		expect(model ~= nil).toBe(true)
		local lit = false
		for _, object in model:GetDescendants() do
			lit = lit or object.ClassName == "PointLight"
		end
		expect(lit).toBe(true)
	end)

	it("counts as an elite, ignores knockback and is never moved back onto the spawn ring", function()
		local id = BossService.getBosses()[1].id
		local _, elite = EnemySim.getKind(id)
		expect(elite).toBe(true)
		local before = EnemySim.getPosition(id) :: Vector3
		EnemySim.push(id, Vector3.new(10, 0, 0))
		local after = EnemySim.getPosition(id) :: Vector3
		expect((after - before).Magnitude).toBeNear(0)
	end)

	it("warns on the floor before it strikes, and the circling embers show", function()
		local sawWarning = waitFor(8, function()
			local warnings = controller("BossController").getCounts()
			return warnings > 0
		end)
		expect(sawWarning).toBe(true)
		local _, embers = controller("BossController").getCounts()
		expect(embers).toBe(Config.Enemies.bosses.LanternEater.boss.phases[1].orbit.count)
	end)

	it("hurts the player with its attacks", function()
		heal()
		CombatService.protect(me, 0)
		local _, maxHp = CombatService.getHp(me)
		local hit = false
		for _ = 1, 150 do
			world.advance(0.1)
			local hp = CombatService.getHp(me)
			if hp < maxHp then
				hit = true
				break
			end
		end
		expect(hit).toBe(true)
		heal()
	end)

	it("changes phase at half HP and says so", function()
		click("HurtBoss")
		click("HurtBoss")
		local changed = waitFor(5, function()
			local bosses = BossService.getBosses()
			return bosses[1] ~= nil and bosses[1].phase == 2
		end)
		expect(changed).toBe(true)
		advanceHealing(0.5)
		expect(string.find(controller("BossController").getBarText(), "Phase 2", 1, true) ~= nil).toBe(true)
		local _, embers = controller("BossController").getCounts()
		expect(embers).toBe(0) -- the second phase has no embers
	end)

	it("drops a legendary crate when killed outside the boss wave, and the run goes on", function()
		click("HurtBoss")
		click("HurtBoss")
		expect(#BossService.getBosses()).toBe(0)
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Running")
		local _, waiting = UpgradeService.getCrate(me)
		expect(pickupsOf("Legendary") + waiting).toBe(1) -- on the floor, or already picked up next to it
		expect(controller("BossController").getBarText()).toBe("")
	end)

	it("the second boss rains red circles around the player and runs wild in its last phase", function()
		click("SpawnBoss")
		local bosses = BossService.getBosses()
		expect(bosses[1].bossId).toBe(Config.Enemies.bossWave.order[2])
		local rain = Config.Enemies.bosses.HollowSeer.boss.attacks.Rain
		local sawRain = waitFor(4, function()
			local warnings = controller("BossController").getCounts()
			return warnings >= rain.count
		end)
		expect(sawRain).toBe(true)
		click("HurtBoss")
		click("HurtBoss")
		click("HurtBoss")
		local wild = waitFor(4, function()
			return BossService.getBosses()[1].phase == 3
		end)
		expect(wild).toBe(true)
		local id = BossService.getBosses()[1].id
		local _, _, speed = EnemySim.getMultipliers(id)
		expect(speed).toBeNear(Config.Enemies.bosses.HollowSeer.boss.phases[3].speedMultiplier or 1)
		click("HurtBoss")
		expect(#BossService.getBosses()).toBe(0)
		advanceHealing(0.3)
		expect(RunDirector.getPhase()).toBe("Running")
	end)

	it("heals fully with a legendary crate and opens a Legendary item after the wave", function()
		LootService.setDropsPaused(true)
		for _, pickup in LootService.getPickups() do
			if pickup.kind == "Legendary" then
				local root = me.Character.HumanoidRootPart
				root.Position = Vector3.new(pickup.x, root.Position.Y, pickup.z)
				world.advance(0.2)
			end
		end
		CombatService.protect(me, 0)
		click("HurtSelf")
		click("DropLegendaryCrate")
		world.advance(0.3)
		local hp, maxHp = CombatService.getHp(me)
		expect(hp).toBeNear(maxHp)
		expect(pickupsOf("Legendary")).toBe(0)
		local _, waiting = UpgradeService.getCrate(me)
		expect(waiting).toBe(3) -- one from each test boss and this one
		click("SkipWave")
		expect(RunDirector.getPhase()).toBe("Shop")
		local open = UpgradeService.getCrate(me)
		expect(open ~= nil).toBe(true)
		expect((open :: any).tier).toBe(Config.Loot.legendaryCrate.minTier)
		pickLevels()
	end)

	it("brings a boss with the boss wave and wins when it dies", function()
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Running")
		click("SkipToBoss")
		expect(RunDirector.getPhase()).toBe("Shop")
		pickLevels()
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.3)
		expect(RunDirector.getWave()).toBe(RunSchedule.waveCount())
		expect(BossService.getPendingCount()).toBe(1) -- danger 0: one boss (B11)
		expect(controller("SpawnMarkerRenderer").getCount() > 0).toBe(true)
		world.advance(Config.Enemies.bossWave.introSeconds + 0.2)
		local bosses = BossService.getBosses()
		expect(#bosses).toBe(1)
		expect(bosses[1].wave).toBe(true)
		-- HP grows with the player factor like every enemy: solo the config value
		local kind = Config.Enemies.bosses[bosses[1].bossId]
		expect(EnemySim.getMaxHealth(bosses[1].id)).toBeNear(kind.hp)
		heal()
		for _ = 1, 4 do
			click("HurtBoss")
		end
		world.advance(0.3)
		-- playtest after Paket 24: the vote "continue in endless mode?" first; its time running out wins the run
		expect(RunDirector.getPhase()).toBe("Shop")
		expect(world.gui("EndlessChoice").Enabled).toBe(true)
		world.advance(Config.Run.flow.endlessChoiceSeconds + 0.3)
		expect(RunDirector.getPhase()).toBe("Ended")
		expect(world.gui("Results").Enabled).toBe(true)
	end)
end)
