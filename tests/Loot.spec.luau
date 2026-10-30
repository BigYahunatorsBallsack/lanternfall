-- End-to-end test of the loot package (B6): fruits, crates and the crate choice at the wave end, the bag for orbs
-- left at the end of a wave, Looters and Trees. Real server and client bootstraps in a simulated Roblox
-- (tests/helpers/RobloxMock), like tests/Smoke.spec.luau. Look and feel: Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local CombatService = require(Services.CombatService)
local EnemySim = require(Services.EnemySim)
local ExperienceService = require(Services.ExperienceService)
local LootService = require(Services.LootService)
local MapService = require(Services.MapService)
local RunDirector = require(Services.RunDirector)
local ShopService = require(Services.ShopService)
local StatService = require(Services.StatService)
local UpgradeService = require(Services.UpgradeService)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local function controller(name)
	return require(folderProxy("src/client", "Client").Controllers[name])
end

local function click(name)
	world.click(world.gui("Debug", name))
	world.advance(0.2)
end

local function position(): Vector3
	return MapService.getRootPosition(me) :: Vector3
end

local function standAt(x, z)
	local root = me.Character.HumanoidRootPart
	root.Position = Vector3.new(x, root.Position.Y, z)
	root.AssemblyLinearVelocity = Vector3.zero
end

local function toastTexts()
	local texts = {}
	for _, object in world.gui("Notify"):GetDescendants() do
		if object.ClassName == "TextLabel" then
			table.insert(texts, object.Text)
		end
	end
	return table.concat(texts, " | ")
end

-- Ids and kinds of the living enemies.
local function enemies(): { { id: number, kind: string } }
	local ids = {}
	local list = {}
	for i = 1, EnemySim.collectIds(ids) do
		table.insert(list, { id = ids[i], kind = (EnemySim.getKind(ids[i])) :: string })
	end
	return list
end

local function countKind(kind: string): number
	local count = 0
	for _, enemy in enemies() do
		if enemy.kind == kind then
			count += 1
		end
	end
	return count
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

-- Picks the first card of every open level-up choice.
local function pickLevels()
	for _ = 1, 30 do
		local offer = UpgradeService.getOffer(me)
		if not offer then
			break
		end
		world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
		world.click(world.gui("LevelUp", "Card1"))
		world.advance(0.1)
	end
end

local function nextWave()
	pickLevels()
	world.fireServerAs(me, "SetShopReady", true)
	world.advance(0.3)
	expect(RunDirector.getPhase()).toBe("Running")
end

describe("loot", function()
	it("starts a run with weapons off, spawning paused and random drops off", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(3.5)
		expect(RunDirector.getPhase()).toBe("Running")
		LootService.setDropsPaused(true) -- the fruits and crates below are dropped by hand
		click("ToggleWeapons")
		click("ToggleSpawning")
		click("HoldWaves")
		expect(EnemySim.getCount()).toBe(0)
	end)

	it("heals with a fruit that is walked over", function()
		CombatService.protect(me, 0) -- no protection left from the run start
		click("HurtSelf")
		local hurt, maxHp = CombatService.getHp(me)
		expect(hurt < maxHp).toBe(true)
		local here = position()
		LootService.dropPickup(here + Vector3.new(40, 0, 0), "Fruit") -- out of reach
		world.advance(0.2)
		expect(pickupsOf("Fruit")).toBe(1)
		local lying = controller("PickupRenderer").getCounts()
		expect(lying).toBe(1)
		expect(#workspace:FindFirstChild("LanternfallPickups"):GetChildren()).toBe(2) -- fruit and leaf
		standAt(here.X + 40, here.Z)
		world.advance(0.2)
		expect(pickupsOf("Fruit")).toBe(0)
		local hp = CombatService.getHp(me)
		expect(hp).toBeNear(math.min(maxHp, hurt + Config.Loot.fruit.heal))
		local _, flying = controller("PickupRenderer").getCounts()
		expect(flying).toBe(1) -- it flies into the player
		world.advance(0.5)
		local lyingAfter, flyingAfter = controller("PickupRenderer").getCounts()
		expect(lyingAfter + flyingAfter).toBe(0)
	end)

	it("keeps a picked-up crate for the end of the wave", function()
		click("DropCrate")
		world.advance(0.2)
		local open, waiting = UpgradeService.getCrate(me)
		expect(open).toBe(nil)
		expect(waiting).toBe(1)
		expect(string.find(toastTexts(), "Crate! It opens after the wave.", 1, true) ~= nil).toBe(true)
		expect(controller("PickupRenderer").getChipText()).toBe("1 crate")
		-- a second crate stays on the floor out of reach; it goes to the player when the wave ends
		LootService.dropPickup(position() + Vector3.new(0, 0, 40), "Crate")
		expect(pickupsOf("Crate")).toBe(1)
	end)

	it("puts the orbs left on the floor at the wave end into the bag", function()
		click("SpawnWave") -- on the spawn ring, far out of pickup reach
		local spawned = EnemySim.getCount()
		expect(spawned > 0).toBe(true)
		local level = ExperienceService.getLevel()
		click("KillEnemies")
		expect(ExperienceService.getOrbCount() > 0).toBe(true)
		click("SkipWave")
		expect(RunDirector.getPhase()).toBe("Shop")
		expect(ExperienceService.getOrbCount()).toBe(0)
		expect(ExperienceService.getBag()).toBe(spawned) -- wave 1: every Shadeling dropped its orb of 1
		expect(ExperienceService.getLevel()).toBe(level) -- no XP yet, it comes with the next waves
		expect(pickupsOf("Crate")).toBe(0) -- the crate on the floor went to the player
	end)

	it("opens the crates one by one before the level-up cards: sell one, take the other", function()
		local open, waiting = UpgradeService.getCrate(me)
		expect(open ~= nil).toBe(true)
		expect(waiting).toBe(1)
		expect(world.gui("LevelUp").Enabled).toBe(true)
		expect(world.gui("LevelUp", "Crate").Visible).toBe(true)
		expect(world.gui("LevelUp", "LevelUp").Visible).toBe(false)
		expect(world.gui("Shop", "Shop").Visible).toBe(false) -- the shop waits too
		local item = Config.Items.byId[(open :: any).itemId]
		expect(world.gui("LevelUp", "CrateCard"):FindFirstChild("CardName").Text).toBe(item.displayName)
		expect(world.gui("LevelUp", "Sell").Text).toBe(`Sell (+{(open :: any).sellPrice} Shards)`)
		local shards = ShopService.getShards(me)
		world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
		world.click(world.gui("LevelUp", "Sell"))
		world.advance(0.2)
		expect(ShopService.getShards(me)).toBe(shards + (open :: any).sellPrice)
		local second, left = UpgradeService.getCrate(me)
		expect(second ~= nil).toBe(true)
		expect(left).toBe(0)
		local itemId = (second :: any).itemId
		local owned = StatService.getItemCounts(me)[itemId] or 0
		world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
		world.click(world.gui("LevelUp", "Take"))
		world.advance(0.2)
		expect(StatService.getItemCounts(me)[itemId]).toBe(owned + 1)
		expect(UpgradeService.getCrate(me)).toBe(nil)
		expect(world.gui("LevelUp", "Crate").Visible).toBe(false)
	end)

	it("lets new orbs take as much again from the bag in the next wave", function()
		nextWave()
		local bag = ExperienceService.getBag()
		expect(controller("PickupRenderer").getChipText()).toBe(`Bag {bag}`)
		click("SpawnWave")
		local killed = EnemySim.getCount()
		click("KillEnemies")
		expect(ExperienceService.getBag()).toBe(math.max(0, bag - killed))
	end)

	it("spawns a Looter that runs away and escapes without dropping anything", function()
		local orbs = ExperienceService.getOrbCount()
		click("SpawnLooter")
		expect(countKind("Looter")).toBe(1)
		local looter = enemies()[1]
		local here = position()
		local start = (EnemySim.getPosition(looter.id) :: Vector3 - here).Magnitude
		world.advance(1)
		expect((EnemySim.getPosition(looter.id) :: Vector3 - here).Magnitude > start).toBe(true)
		world.advance(Config.Loot.looter.lifetimeSeconds)
		expect(countKind("Looter")).toBe(0)
		expect(ExperienceService.getOrbCount()).toBe(orbs)
		expect(#LootService.getPickups()).toBe(0)
	end)

	it("drops a crate and a big orb when a Looter is killed", function()
		LootService.setDropsPaused(false) -- only the enemies below die from here on
		local orbs = ExperienceService.getOrbCount()
		click("SpawnLooter")
		click("KillEnemies")
		expect(pickupsOf("Crate")).toBe(1)
		expect(ExperienceService.getOrbCount()).toBe(orbs + 1)
	end)

	it("grows a Tree that stands still and drops a fruit or crate and an orb", function()
		click("SpawnTree")
		expect(countKind("Tree")).toBe(1)
		local tree = enemies()[1]
		local before = EnemySim.getPosition(tree.id) :: Vector3
		standAt(before.X + 1, before.Z) -- walking into it does not push it
		world.advance(1)
		expect((EnemySim.getPosition(tree.id) :: Vector3 - before).Magnitude).toBeNear(0)
		standAt(before.X + 60, before.Z)
		world.advance(0.2)
		local orbs = ExperienceService.getOrbCount()
		local pickups = #LootService.getPickups()
		click("KillEnemies")
		expect(#LootService.getPickups()).toBe(pickups + 1)
		expect(ExperienceService.getOrbCount()).toBe(orbs + 1)
	end)

	it("plants the wave's trees by itself while the wave runs", function()
		click("HoldWaves") -- the wave timer runs again
		click("ToggleSpawning")
		CombatService.protect(me, 30)
		local wave = RunDirector.getWave()
		local seconds = 0
		while countKind("Tree") == 0 and seconds < 30 and RunDirector.getWave() == wave do
			world.advance(0.5)
			seconds += 0.5
		end
		expect(countKind("Tree") >= 1).toBe(true)
	end)

	it("finished without any runtime error", function()
		expect(#world.errors).toBe(0)
	end)
end)
