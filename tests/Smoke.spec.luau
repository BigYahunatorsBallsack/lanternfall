-- End-to-end smoke test: real server and client bootstraps in a simulated Roblox (tests/helpers/RobloxMock).
-- Catches crashes, wrong module paths, broken remote payloads and flow bugs. Look and feel: Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local RunDirector = require(ServerScriptService.Server.Services.RunDirector)
local MapService = require(ServerScriptService.Server.Services.MapService)
local EnemySim = require(ServerScriptService.Server.Services.EnemySim)
local CombatService = require(ServerScriptService.Server.Services.CombatService)
local WeaponService = require(ServerScriptService.Server.Services.WeaponService)
local ExperienceService = require(ServerScriptService.Server.Services.ExperienceService)
local UpgradeService = require(ServerScriptService.Server.Services.UpgradeService)
local RunStatsService = require(ServerScriptService.Server.Services.RunStatsService)
local LootService = require(ServerScriptService.Server.Services.LootService)
local SpawnDirector = require(ServerScriptService.Server.Services.SpawnDirector)
local BossService = require(ServerScriptService.Server.Services.BossService)
local ShopService = require(ServerScriptService.Server.Services.ShopService)
local ShopRules = require(ServerScriptService.Server.Services.ShopService.ShopRules)
local StatService = require(ServerScriptService.Server.Services.StatService)
local StatMath = require(game:GetService("ReplicatedStorage").Shared.Util.StatMath)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
-- Keep the original broad regression scenario independent of B10 trade-offs and starting items.
-- CharactersB10.spec.luau boots the untouched catalog and exercises every actual character end to end.
Config.Classes.SparkMage.stats = { attackSpeed = 10 }
Config.Classes.SparkMage.gainMultipliers = nil
Config.Classes.SparkMage.startItems = nil
Config.Classes.SparkMage.startWeapon = "SparkBolt"
Config.Classes.SparkMage.startWeapons = { "SparkBolt" }

local Format = require(game:GetService("ReplicatedStorage").Shared.Util.Format)
local RunSchedule = require(game:GetService("ReplicatedStorage").Shared.Util.RunSchedule)

-- Random fruits and crates (B6) would open crate choices before the level-up cards here; tests/Loot.spec.luau covers them.
LootService.setDropsPaused(true)
-- B12 has separate structure integration tests; do not kill this scenario's projectile-test enemies.
require(ServerScriptService.Server.Services.StructureService).setPaused(true)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local function phase()
	return RunDirector.getPhase()
end

local function inZone(player, zone)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and MapService.isInZone(root.Position, zone)
end

local function firstText(screenName, objectName)
	local object = world.gui(screenName, objectName)
	assert(object, `{screenName}/{objectName} not found`)
	return object:FindFirstChildOfClass("TextLabel").Text
end

local function enemyRenderer()
	return require(folderProxy("src/client", "Client").Controllers.EnemyRenderer)
end

-- Enemy models the client currently shows (released models are unparented).
local function drawnModels()
	local folder = workspace:FindFirstChild("LanternfallEnemies")
	return if folder then folder:GetChildren() else {}
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

-- Weapon parts the client currently shows, by name (OrbitBlade, SparkBolt, Shockwave).
local function weaponParts(name)
	local folder = workspace:FindFirstChild("LanternfallWeapons")
	local count = 0
	for _, part in if folder then folder:GetChildren() else {} do
		if part.Name == name then
			count += 1
		end
	end
	return count
end

local function weaponRows()
	local lines = {}
	for _, row in world.gui("HUD", "WeaponRows"):GetChildren() do
		if row.ClassName == "TextLabel" then
			table.insert(lines, row.Text)
		end
	end
	return table.concat(lines, " | ")
end

local function itemRows()
	local lines = {}
	for _, row in world.gui("HUD", "ItemRows"):GetChildren() do
		if row.ClassName == "TextLabel" then
			table.insert(lines, row.Text)
		end
	end
	return table.concat(lines, " | ")
end

local function clientController(name)
	return require(folderProxy("src/client", "Client").Controllers[name])
end

-- Orb parts the client currently shows.
local function orbParts()
	local folder = workspace:FindFirstChild("LanternfallXpOrbs")
	return if folder then #folder:GetChildren() else 0
end

local function card(index)
	return world.gui("LevelUp", `Card{index}`)
end

-- Clicks the first card of every open choice until none is left; returns the cards picked.
local function pickAll()
	local picked = {}
	for _ = 1, 50 do
		local offer = UpgradeService.getOffer(me)
		if not offer then
			break
		end
		world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
		table.insert(picked, offer[1])
		world.click(card(1))
		world.advance(0.1)
	end
	return picked
end

local function teamText()
	local rows = world.gui("HUD", "Rows")
	local lines = {}
	for _, row in rows:GetChildren() do
		if row.ClassName == "TextLabel" then
			table.insert(lines, row.Text)
		end
	end
	return table.concat(lines, " | ")
end

describe("smoke", function()
	it("boots server and client without errors", function()
		expect(#world.errors).toBe(0)
		expect(world.gui("Lobby").Enabled).toBe(true)
		expect(world.gui("HUD").Enabled).toBe(false)
		expect(world.gui("Results").Enabled).toBe(false)
		expect(world.gui("Debug").Enabled).toBe(true)
		expect(firstText("Lobby", "Status")).toBe("Pick a class and press READY")
	end)

	it("builds the map and spawns the player in the lobby", function()
		expect(workspace:FindFirstChild("LanternfallMap") ~= nil).toBe(true)
		expect(inZone(me, "Lobby")).toBe(true)
	end)

	it("switches class from the lobby", function()
		world.click(world.gui("Lobby", "SparkMage"))
		world.advance(0.5)
		expect(world.gui("Lobby", "SparkMage").BackgroundColor3 == world.gui("Lobby", "Ready").TextColor3).toBe(false)
		local rows = world.gui("Lobby", "Rows"):GetChildren()
		local found = false
		for _, row in rows do
			if row.ClassName == "TextLabel" and string.find(row.Text, "Spark Mage", 1, true) then
				found = true
			end
		end
		expect(found).toBe(true)
	end)

	it("starts a run after READY", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(0.2)
		expect(phase()).toBe("Countdown")
		expect(string.find(firstText("Lobby", "Status"), "Run starts in", 1, true) ~= nil).toBe(true)
		world.advance(3.2)
		expect(phase()).toBe("Running")
		expect(world.gui("HUD").Enabled).toBe(true)
		expect(world.gui("Lobby").Enabled).toBe(false)
		expect(inZone(me, "Arena")).toBe(true)
	end)

	it("arms the player with the class weapon and switches weapons off for the enemy tests", function()
		expect(weaponRows()).toBe("Spark Bolt I")
		expect(world.gui("HUD", "WeaponsTitle").Text).toBe("WEAPONS")
		local weapon = WeaponService.getWeapons(me)[1]
		expect(weapon.stats.cooldown).toBeNear(Config.Weapons.SparkBolt.base.cooldown / 1.1) -- Spark Mage: +10 % Attack Speed
		ExperienceService.setPaused(true) -- no level-up cards in the way until the level-up tests below
		world.click(world.gui("Debug", "ToggleWeapons"))
		world.advance(0.2)
		expect(WeaponService.isPaused()).toBe(true)
		expect(world.gui("HUD", "WeaponsTitle").Text).toBe("WEAPONS (OFF)")
	end)

	it("counts the wave down and stops the wave timer with the debug button", function()
		world.advance(5)
		expect(firstText("HUD", "Timer")).toBe("00:15") -- wave 1 lasts 20 s
		world.click(world.gui("Debug", "HoldWaves"))
		CombatService.protect(me, 4) -- weapons are off
		world.advance(3)
		expect(RunDirector.isHoldingWaves()).toBe(true)
		expect(firstText("HUD", "Timer")).toBe("00:15")
		expect(phase()).toBe("Running")
		expect(string.match(teamText(), "^Owner · alive · %d+ HP$") ~= nil).toBe(true)
		expect(string.match(world.gui("HUD", "HpText").Text, "^%d+ / 100$") ~= nil).toBe(true) -- Spark Mage: no bonus
	end)

	it("spawns enemies on a ring around the player and draws them", function()
		CombatService.protect(me, 8) -- weapons are off; the touch test below needs the player alive
		world.advance(8) -- the first wave starts calm
		expect(EnemySim.getCount() >= 5).toBe(true)
		local root = me.Character.HumanoidRootPart.Position
		for _, enemyId in { 1, 2, 3 } do
			local position = EnemySim.getPosition(enemyId)
			local distance = (position - root).Magnitude
			-- spawned 45-60 studs away and walked towards the player since
			expect(position.Y).toBe(Config.Map.arena.center.Y)
			expect(distance < Config.Run.spawn.ringMax + 1).toBe(true)
		end
		world.advance(0.5)
		local models = drawnModels()
		expect(#models).toBe(enemyRenderer().getStats().drawn)
		expect(#models >= EnemySim.getCount() - 2 and #models <= EnemySim.getCount()).toBe(true)
		for _, model in models do
			expect(model.Name).toBe("Shadeling") -- only Shadelings before minute 2
			expect(
				math.abs(model.Body.Position.Y - Config.Map.arena.center.Y - Config.Enemies.types.Shadeling.radius) < 1
			).toBe(true)
		end
		expect(world.bulkMoves > 0).toBe(true)
	end)

	it("chases the player until it touches them", function()
		local contacts = 0
		CombatService.healPlayer(me, 1e6) -- full HP: since the playtest after Paket 24 a crowd hurts a lot
		local hpBefore = CombatService.getHp(me)
		local connection = EnemySim.Contact:Connect(function(player, damage)
			expect(player).toBe(me)
			-- grows a little with the growth steps; normal enemies' damage times damageScale (Run.spawn.growth)
			expect(damage).toBeNear(
				Config.Enemies.types.Shadeling.contactDamage * (Config.Run.spawn.growth.damageScale or 1),
				0.1
			)
			contacts += 1
		end)
		world.advance(2) -- since the playtest after Paket 24 a crowd kills a still player within a few seconds
		connection:Disconnect()
		expect(contacts > 0).toBe(true)
		-- every touch hurts, at most once per hit protection window
		local lost = hpBefore - CombatService.getHp(me)
		local hitsAllowed = math.ceil(2 / Config.Player.hitInvulnerability) + 1
		expect(lost > 0).toBe(true)
		local hit = Config.Enemies.types.Shadeling.contactDamage * (Config.Run.spawn.growth.damageScale or 1)
		expect(lost <= hitsAllowed * hit * 1.1).toBe(true)
		CombatService.protect(me, 1e6) -- keep the rest of the smoke test alive
		local root = me.Character.HumanoidRootPart.Position
		local id, distance = EnemySim.nearest(root)
		expect(id ~= nil).toBe(true)
		expect(distance).toBeNear(Config.Enemies.types.Shadeling.radius + Config.Simulation.playerRadius, 0.6)
	end)

	it("hits and kills enemies with the debug buttons", function()
		local kills = 0
		local connection = EnemySim.EnemyKilled:Connect(function(info)
			expect(info.killer).toBe(me)
			expect(info.xp).toBe(Config.Enemies.types.Shadeling.xp)
			kills += 1
		end)
		local before = EnemySim.getCount()
		world.click(world.gui("Debug", "HitNearby"))
		world.advance(0.2)
		expect(string.find(toastTexts(), "Hit ", 1, true) ~= nil).toBe(true)
		expect(kills).toBe(0) -- a Shadeling survives one hit
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.5)
		connection:Disconnect()
		expect(kills >= before).toBe(true)
		expect(EnemySim.getCount() <= 1).toBe(true) -- one may have spawned since
		expect(#drawnModels() <= 1).toBe(true)
	end)

	it("pauses spawning and spawns a test wave up to the cap", function()
		world.click(world.gui("Debug", "ToggleSpawning"))
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(3)
		expect(EnemySim.getCount()).toBe(0)
		world.click(world.gui("Debug", "SpawnWave"))
		world.click(world.gui("Debug", "SpawnWave"))
		world.click(world.gui("Debug", "SpawnWave"))
		world.advance(0.5)
		expect(EnemySim.getCount()).toBe(Config.Run.spawn.cap.base)
		expect(#drawnModels()).toBe(Config.Run.spawn.cap.base)
		expect(string.find(toastTexts(), "The enemy limit is reached", 1, true) ~= nil).toBe(true)
		world.click(world.gui("Debug", "ToggleSpawning"))
		world.advance(0.2)
	end)

	it("shows enemy and performance numbers to admins", function()
		world.advance(1.2)
		local stats = world.gui("Debug", "Stats")
		expect(stats ~= nil).toBe(true)
		local cap = Config.Run.spawn.cap.base
		local culled = enemyRenderer().getStats().culled
		expect(stats.Enemies.Text).toBe(`Enemies {cap} / {cap} · drawn {cap} ({culled} off screen) · shots 0`)
		expect(string.find(stats.Server.Text, "Server step", 1, true) ~= nil).toBe(true)
		expect(string.find(stats.Network.Text, "KB/s", 1, true) ~= nil).toBe(true)
		-- Paket 22: frame time, memory (Roblox's Stats service is missing in tests) and the graphics level
		expect(string.find(stats.Fps.Text, "frame", 1, true) ~= nil).toBe(true)
		expect(stats.Memory.Text).toBe("Memory ? MB · instances ?")
		expect(stats.Graphics.Text).toBe("Graphics High (auto)")
	end)

	it("shoots Spark Bolts that kill enemies once weapons are on", function()
		local kills = 0
		local connection = EnemySim.EnemyKilled:Connect(function(info)
			if info.killer == me then
				kills += 1
			end
		end)
		world.click(world.gui("Debug", "ToggleWeapons"))
		local numbers = require(folderProxy("src/client", "Client").Controllers.DamageNumberController)
		local particlesBefore = world.particlesEmitted or 0
		local mostBolts, mostNumbers = 0, 0
		for _ = 1, 30 do
			world.advance(0.1)
			mostBolts = math.max(mostBolts, weaponParts("SparkBolt"))
			mostNumbers = math.max(mostNumbers, numbers.getCount())
		end
		connection:Disconnect()
		expect(WeaponService.isPaused()).toBe(false)
		expect(kills > 0).toBe(true)
		expect(mostBolts > 0).toBe(true)
		expect(mostNumbers > 0).toBe(true) -- damage numbers over the hit enemies
		expect((world.particlesEmitted or 0) > particlesBefore).toBe(true) -- death bursts
		expect(WeaponService.getDamageStats(me).SparkBolt.kills).toBe(kills)
	end)

	it("draws the six original weapons, tiers and debug swaps", function()
		-- Explicit fixtures: new catalog entries must not change this original visual regression.
		local function most(name, seconds)
			local best = 0
			for _ = 1, seconds / 0.1 do
				world.advance(0.1)
				best = math.max(best, weaponParts(name))
			end
			return best
		end
		assert(WeaponService.addWeapon(me, "BoomerangAxe"))
		world.click(world.gui("Debug", "SpawnWave"))
		expect(most("BoomerangAxe", 3) > 0).toBe(true)
		expect(weaponRows()).toBe("Spark Bolt I | Boomerang Axe I")
		assert(WeaponService.addWeapon(me, "ChainLightning"))
		world.click(world.gui("Debug", "SpawnWave"))
		expect(most("ChainLightning", 3) > 0).toBe(true)
		assert(WeaponService.addWeapon(me, "OrbitBlades"))
		world.advance(0.2)
		expect(weaponParts("OrbitBlade")).toBe(Config.Weapons.OrbitBlades.base.count)
		expect(weaponParts("OrbitBladeBody")).toBe(Config.Weapons.OrbitBlades.base.count) -- brass under each edge
		world.click(world.gui("Debug", "TierUpWeapons"))
		world.advance(0.2)
		expect(weaponRows()).toBe("Spark Bolt II | Boomerang Axe II | Chain Lightning II | Orbit Blades II")
		assert(WeaponService.addWeapon(me, "Shockwave")) -- Shockwave
		world.advance(0.2)
		assert(WeaponService.addWeapon(me, "ThornTrail")) -- Thorn Trail: six weapons like Brotato
		world.advance(0.2)
		expect(#WeaponService.getWeapons(me)).toBe(Config.Player.maxWeapons)
		world.click(world.gui("Debug", "AddWeapon"))
		world.advance(0.2)
		expect(string.find(toastTexts(), "All weapon slots are full", 1, true) ~= nil).toBe(true)
		world.advance(1)

		world.click(world.gui("Debug", "NextWeapon"))
		expect(#WeaponService.getWeapons(me)).toBe(1)
		for _, weapon in WeaponService.getWeapons(me) do
			WeaponService.removeWeapon(me, weapon.uid)
		end
		assert(WeaponService.addWeapon(me, "ThornTrail"))
		world.advance(0.2)
		expect(weaponRows()).toBe("Thorn Trail I")
		expect(weaponParts("ThornPatch") > 0).toBe(true)
		expect(weaponParts("Thorn") > 0).toBe(true)
		for _, weapon in WeaponService.getWeapons(me) do
			WeaponService.removeWeapon(me, weapon.uid)
		end
		assert(WeaponService.addWeapon(me, "Shockwave"))
		world.click(world.gui("Debug", "SpawnWave"))
		expect(most("Shockwave", 4) > 0).toBe(true)
		expect(weaponRows()).toBe("Shockwave I")

		for _, weapon in WeaponService.getWeapons(me) do
			WeaponService.removeWeapon(me, weapon.uid)
		end
		for _, id in { "SparkBolt", "BoomerangAxe", "ChainLightning", "OrbitBlades" } do
			assert(WeaponService.addWeapon(me, id))
		end
		world.advance(1.1) -- debug buttons allow 5 clicks per second
		for _ = 1, Config.Player.maxWeaponTier do
			world.click(world.gui("Debug", "TierUpWeapons"))
		end
		world.advance(0.2)
		expect(weaponParts("OrbitBlade")).toBe(Config.Weapons.OrbitBlades.base.count + 2)
		world.advance(1)
		world.click(world.gui("Debug", "EvolveWeapons"))
		world.advance(0.2)
		expect(weaponRows()).toBe("Starfire | Boomerang Axe IV | Chain Lightning IV | Blade Storm")
		expect(string.find(toastTexts(), "Starfire, Blade Storm", 1, true) ~= nil).toBe(true)
		expect(weaponParts("OrbitBlade")).toBe(Config.Evolutions.BladeStorm.stats.count)
		local items = itemRows()
		expect(string.find(items, "Focus", 1, true) ~= nil and string.find(items, "Armor Plate", 1, true) ~= nil).toBe(
			true
		)
		expect(world.gui("HUD", "ItemsTitle").Text).toBe("ITEMS (2)")
		world.click(world.gui("Debug", "SpawnWave"))
		expect(most("Explosion", 3) > 0).toBe(true) -- Starfire blasts, drawn by Visuals/Explosion since B5
	end)

	it("drops XP orbs that the player picks up for the whole team", function()
		ExperienceService.setPaused(false)
		world.click(world.gui("Debug", "ToggleSpawning"))
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.5)
		pickAll()
		local orbsBefore = ExperienceService.getOrbCount()
		local before = ExperienceService.getProgress()
		local root = me.Character.HumanoidRootPart.Position
		local near = EnemySim.spawn("Shadeling", root.X + 3, root.Z, 1, 1)
		local far = EnemySim.spawn("Shadeling", root.X + 35, root.Z, 1, 1)
		EnemySim.damage(near, 1000, me)
		EnemySim.damage(far, 1000, me)
		world.advance(0.2)
		local after = ExperienceService.getProgress()
		expect(ExperienceService.getOrbCount()).toBe(orbsBefore + 1) -- the far orb still lies there
		expect(after.level > before.level or after.xp == before.xp + Config.Enemies.types.Shadeling.xp).toBe(true)
		local lying = clientController("XpOrbRenderer").getCounts()
		expect(lying).toBe(ExperienceService.getOrbCount())
		expect(orbParts() >= lying).toBe(true)
		expect(world.gui("HUD", "XpText").Text).toBe(`LV {after.level}`)
		world.advance(0.5)
		pickAll()
	end)

	it("keeps level-ups for the end of the wave", function()
		local level = ExperienceService.getLevel()
		world.click(world.gui("Debug", "GainLevel"))
		world.advance(0.1)
		expect(ExperienceService.getLevel()).toBe(level + 1)
		expect(UpgradeService.getOffer(me)).toBe(nil)
		expect(world.gui("LevelUp").Enabled).toBe(false)
		expect(world.gui("HUD", "XpText").Text).toBe(`LV {level + 1} · +1 at wave end`)
	end)

	it("ends the wave: enemies fade, the shop opens and the level-up cards come first", function()
		world.click(world.gui("Debug", "SpawnWave"))
		world.advance(0.2)
		expect(EnemySim.getCount() > 0).toBe(true)
		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.2)
		expect(phase()).toBe("Shop")
		expect(EnemySim.getCount()).toBe(0)
		expect(#drawnModels()).toBe(0)
		expect(firstText("HUD", "Timer")).toBe(Format.time(Config.Shop.phaseSeconds))
		expect(string.find(teamText(), "picking", 1, true) ~= nil).toBe(true)
		local hp, maxHp = CombatService.getHp(me)
		expect(hp).toBe(maxHp) -- everyone heals when a wave ends
		expect(world.gui("Shop").Enabled).toBe(true)
		expect(world.gui("Shop", "Shop").Visible).toBe(false) -- the cards come first
	end)

	it("opens level-up cards on the screen between waves and applies the pick", function()
		local offer = UpgradeService.getOffer(me)
		expect(offer ~= nil).toBe(true)
		expect(#offer).toBe(Config.Run.levelUp.cardCount)
		expect(world.gui("LevelUp").Enabled).toBe(true)
		expect(string.match(world.gui("LevelUp", "Title").Text, "^LEVEL %d+$") ~= nil).toBe(true)
		expect(card(1):FindFirstChild("CardName").Text ~= "").toBe(true)
		expect(CombatService.isChoosing(me)).toBe(true)
		expect(me.Character.Humanoid.WalkSpeed).toBe(0) -- nobody walks between waves
		expect(world.gui("Backdrop").Enabled).toBe(true) -- the arena is hidden
		expect(world.gui("Backdrop", "Title").Text).toBe(`WAVE {RunDirector.getWave()} CLEARED`)
		expect(world.gui("Backdrop", "Hint").Text).toBe("Pick your level-ups")
		expect(string.find(teamText(), "picking", 1, true) ~= nil).toBe(true)
		world.click(card(1)) -- too soon after the cards appeared: ignored
		world.advance(0.1)
		expect(UpgradeService.getOffer(me)).toBe(offer)
		world.advance(Config.Run.levelUp.inputDelaySeconds)
		local chosen = offer[1]
		expect(Config.Stats.byId[chosen.stat].primary).toBe(true) -- level-ups are stat cards (Brotato)
		expect(card(1):FindFirstChild("Detail").Text).toBe(StatMath.format(chosen.stat, chosen.amount))
		expect(world.gui("Stats").Enabled).toBe(true) -- the stat panel sits next to the cards
		local before = StatService.getStat(me, chosen.stat)
		world.click(card(1))
		world.advance(0.2)
		expect(UpgradeService.getOffer(me) ~= offer).toBe(true)
		expect(StatService.getStat(me, chosen.stat)).toBe(before + chosen.amount)
		expect(clientController("StatsController").get()[chosen.stat]).toBe(before + chosen.amount)
		pickAll() -- the leftover orbs of the wave may have brought another level
		expect(UpgradeService.getOffer(me)).toBe(nil)
		expect(world.gui("LevelUp").Enabled).toBe(false)
		expect(CombatService.isChoosing(me)).toBe(false)
	end)

	it("rerolls the cards for Shards and picks the first card when the time runs out", function()
		world.click(world.gui("Debug", "AddShards"))
		world.click(world.gui("Debug", "GainLevel"))
		world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
		local first = UpgradeService.getOffer(me)
		local price = ShopRules.rerollPrice(RunDirector.getWave(), 0)
		local shards = ShopService.getShards(me)
		expect(world.gui("LevelUp", "Reroll").Text).toBe(`Reroll ({price} Shards)`)
		world.click(world.gui("LevelUp", "Reroll"))
		world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
		local second = UpgradeService.getOffer(me)
		expect(second ~= first).toBe(true)
		for _, newCard in second do
			for _, oldCard in first do
				expect(newCard.stat ~= oldCard.stat).toBe(true)
			end
		end
		expect(ShopService.getShards(me)).toBe(shards - price)
		local nextPrice = ShopRules.rerollPrice(RunDirector.getWave(), 1)
		expect(world.gui("LevelUp", "Reroll").Text).toBe(`Reroll ({nextPrice} Shards)`)
		world.advance(Config.Run.levelUp.autoPickSeconds)
		expect(UpgradeService.getOffer(me)).toBe(nil)
		expect(CombatService.isChoosing(me)).toBe(false)
	end)

	it("sells weapons and items for Shards in the shop, rerolls and starts the next wave on READY", function()
		local shop = clientController("ShopController")
		expect(shop.isShopping()).toBe(true)
		expect(world.gui("Backdrop", "Hint").Text).toBe("Spend your Shards")
		expect(world.pressAction("LanternfallDash")).toBe(Enum.ContextActionResult.Sink)
		expect(me.Character.HumanoidRootPart:FindFirstChild("LanternfallDash")).toBe(nil) -- no dash in the shop
		expect(world.gui("Shop", "Shop").Visible).toBe(true)
		local offers = ShopService.getOffers(me)
		expect(#offers).toBe(Config.Shop.slots)
		expect(string.find(world.gui("Shop", "Offer1"):FindFirstChild("Price").Text, "Shards", 1, true) ~= nil).toBe(
			true
		)

		local shards = ShopService.getShards(me)
		local first = offers[1]
		if shards < first.price then
			world.click(world.gui("Shop", "Offer1")) -- too poor: nothing happens
			world.advance(0.2)
			expect(first.sold).toBe(false)
		end
		world.click(world.gui("Debug", "AddShards"))
		world.advance(0.2)
		shards = ShopService.getShards(me)
		expect(world.gui("Shop", "ShardsText").Text).toBe(`{shards} Shards`)
		world.click(world.gui("Shop", "Offer1"))
		world.advance(0.2)
		expect(first.sold).toBe(true)
		expect(ShopService.getShards(me)).toBe(shards - first.price)
		expect(world.gui("Shop", "Offer1"):FindFirstChild("Badge").Text).toBe("SOLD")
		if first.kind == "Weapon" then
			local found = false
			for _, weapon in WeaponService.getWeapons(me) do
				if weapon.id == first.itemId and weapon.tier == first.tier then
					found = true
				end
			end
			expect(found).toBe(true)
		else
			expect(StatService.getItemCounts(me)[first.itemId] >= first.count).toBe(true)
			expect(string.find(itemRows(), Config.Items.byId[first.itemId].displayName, 1, true) ~= nil).toBe(true)
		end
		world.click(world.gui("Shop", "Offer1")) -- sold: nothing more happens
		world.advance(0.2)
		expect(ShopService.getShards(me)).toBe(shards - first.price)

		local kept = ShopService.getOffers(me)[2]
		world.click(world.gui("Shop", "Lock2"))
		world.advance(0.2)
		expect(kept.locked).toBe(true)
		expect(world.gui("Shop", "Lock2").Text).toBe("LOCKED")
		shards = ShopService.getShards(me)
		local price = shop.get().rerollPrice
		world.click(world.gui("Shop", "Reroll"))
		world.advance(0.2)
		expect(ShopService.getShards(me)).toBe(shards - price)
		expect(ShopService.getOffers(me) ~= offers).toBe(true)
		expect(ShopService.getOffers(me)[1]).toBe(kept) -- locked offers stay through a reroll
		expect(shop.get().rerollPrice > price).toBe(true)
		world.advance(1)

		-- selling and merging weapons: tap a weapon, then Sell or Merge
		for index = #WeaponService.getWeapons(me), 2, -1 do
			WeaponService.removeWeapon(me, WeaponService.getWeapons(me)[index].uid)
		end
		WeaponService.addWeapon(me, "Shockwave")
		WeaponService.addWeapon(me, "Shockwave")
		ShopService.addShards(me, 0) -- sends the shop with the new weapons
		world.advance(0.2)
		expect(shop.get().weapons[2].canMerge).toBe(true)
		world.click(world.gui("Shop", "Weapon2"))
		world.advance(0.1)
		expect(world.gui("Shop", "Merge").Visible).toBe(true)
		world.click(world.gui("Shop", "Merge"))
		world.advance(0.2)
		local weapons = WeaponService.getWeapons(me)
		expect(#weapons).toBe(2)
		expect(weapons[2].id).toBe("Shockwave")
		expect(weapons[2].tier).toBe(2)
		expect(weaponRows()).toBe(`{weaponRows():match("^[^|]+")}| Shockwave II`)
		shards = ShopService.getShards(me)
		local sellPrice = shop.get().weapons[2].sellPrice
		expect(sellPrice > 0).toBe(true)
		expect(world.gui("Shop", "Sell").Text).toBe(`Sell (+{sellPrice})`) -- the merged weapon stays selected
		world.click(world.gui("Shop", "Sell"))
		world.advance(0.2)
		expect(#WeaponService.getWeapons(me)).toBe(1)
		expect(ShopService.getShards(me)).toBe(shards + sellPrice)
		world.click(world.gui("Shop", "Weapon1"))
		world.advance(0.1)
		world.click(world.gui("Shop", "Sell")) -- never the last weapon
		world.advance(0.2)
		expect(#WeaponService.getWeapons(me)).toBe(1)
		expect(string.find(toastTexts(), "last weapon", 1, true) ~= nil).toBe(true)
		world.advance(1)

		-- every Config.Shop.freeRerollAfterBuys purchases earn a free reroll
		ShopService.addShards(me, 5000)
		world.advance(0.2)
		local bought = 0
		for _ = 1, 3 do
			for index, offer in ShopService.getOffers(me) do
				if not offer.sold and not offer.blocked and bought < Config.Shop.freeRerollAfterBuys then
					world.click(world.gui("Shop", `Offer{index}`))
					world.advance(0.3)
					if offer.sold then
						bought += 1
					end
				end
			end
			if bought < Config.Shop.freeRerollAfterBuys then
				world.click(world.gui("Shop", "Reroll"))
				world.advance(0.3)
			end
		end
		expect(bought).toBe(Config.Shop.freeRerollAfterBuys)
		expect(shop.get().freeRerolls).toBe(1)
		expect(shop.get().rerollPrice).toBe(0)
		expect(world.gui("Shop", "Reroll").Text).toBe("Reroll (free)")
		shards = ShopService.getShards(me)
		world.click(world.gui("Shop", "Reroll"))
		world.advance(0.3)
		expect(ShopService.getShards(me)).toBe(shards)
		expect(shop.get().freeRerolls).toBe(0)
		world.advance(1)

		-- phone screens: compact layout, the stats behind a button
		expect(shop.isCompact()).toBe(false)
		local camera = workspace.CurrentCamera
		local fullSize = camera.ViewportSize
		camera.ViewportSize = Vector2.new(844, 390)
		ShopService.addShards(me, 0)
		world.advance(0.2)
		expect(shop.isCompact()).toBe(true)
		expect(world.gui("Stats").Enabled).toBe(false)
		world.click(world.gui("Shop", "StatsToggle"))
		world.advance(0.1)
		expect(world.gui("Stats").Enabled).toBe(true)
		expect(world.gui("Shop", "Shop").Visible).toBe(false)
		world.click(world.gui("Shop", "BackToShop"))
		world.advance(0.1)
		expect(world.gui("Shop", "Shop").Visible).toBe(true)
		camera.ViewportSize = fullSize
		ShopService.addShards(me, 0)
		world.advance(0.2)
		expect(shop.isCompact()).toBe(false)
		expect(world.gui("Stats").Enabled).toBe(true)

		-- a locked offer waits in the next shop at its old price
		kept = ShopService.getOffers(me)[3]
		local keptPrice = kept.price
		world.click(world.gui("Shop", "Lock3"))
		world.advance(0.2)

		local wave = RunDirector.getWave()
		expect(string.find(teamText(), "shopping", 1, true) ~= nil).toBe(true)
		world.click(world.gui("Shop", "Ready"))
		world.advance(0.2)
		expect(phase()).toBe("Running")
		expect(RunDirector.getWave()).toBe(wave + 1)
		expect(world.gui("Backdrop").Enabled).toBe(false)
		local speed = Config.Player.moveSpeed * StatMath.speedFactor(StatService.getStat(me, "speed"))
		expect(me.Character.Humanoid.WalkSpeed).toBeNear(speed) -- walking again, with the Speed bought or picked
		expect(world.gui("Stats").Enabled).toBe(false)
		expect(world.gui("Shop", "Shop").Visible).toBe(false)
		expect(world.gui("HUD", "WaveTitle").Text).toBe(`WAVE {wave + 1}`)
		expect(ShopService.getOffers(me)[1]).toBe(nil)

		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.2)
		expect(phase()).toBe("Shop")
		local next = ShopService.getOffers(me)[1]
		expect(next.id).toBe(kept.id)
		expect(next.price).toBe(keptPrice)
		expect(next.locked).toBe(true)
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.2)
		expect(phase()).toBe("Running")
		WeaponService.addWeapon(me, "SparkBolt") -- the tests below expect a Spark Bolt next to the first weapon
	end)

	it("lets items change HP, speed and weapon damage, stacking without limit", function()
		local weaponBefore = WeaponService.getWeapons(me)[1]
		local before = StatService.getSheet(me)
		local _, maxHpBefore = CombatService.getHp(me)
		for _ = 1, 3 do
			expect(StatService.addItem(me, "Might")).toBe(true) -- +5 % Damage, -10 Max HP each
		end
		expect(StatService.addItem(me, "Vitality")).toBe(true) -- +30 Max HP, -1 % Damage
		expect(StatService.addItem(me, "EelFin")).toBe(true) -- +10 % Speed, +3 % Life Steal, -8 Luck
		expect(StatService.addItem(me, "IronShackle")).toBe(true) -- limited to 1
		expect(select(2, StatService.addItem(me, "IronShackle"))).toBe("Limit")
		world.advance(0.2)
		local after = StatService.getSheet(me)
		expect(after.damage).toBe(before.damage + 15 - 1 + 15)
		expect(after.maxHp).toBe(before.maxHp - 30 + 30)
		expect(after.speed).toBe(before.speed + 10 - 3)
		local _, maxHp = CombatService.getHp(me)
		expect(maxHp).toBe(maxHpBefore + after.maxHp - before.maxHp)
		expect(me.Character.Humanoid.WalkSpeed).toBeNear(Config.Player.moveSpeed * StatMath.speedFactor(after.speed))
		local weapon = WeaponService.getWeapons(me)[1]
		expect(weapon.id).toBe(weaponBefore.id)
		expect(weapon.stats.damage / weaponBefore.stats.damage).toBeNear(
			(1 + after.damage / 100) / (1 + before.damage / 100)
		)
		expect(weapon.stats.lifeSteal).toBeNear(after.lifeSteal / 100)
		expect(string.find(itemRows(), "Might x", 1, true) ~= nil).toBe(true)
		ExperienceService.setPaused(true) -- no cards in the way for the rest of the smoke test
		world.click(world.gui("Debug", "ToggleSpawning"))
		world.advance(0.2)
	end)

	local function controller(name)
		return require(folderProxy("src/client", "Client").Controllers[name])
	end

	local function standAt(x, z)
		local root = me.Character.HumanoidRootPart
		root.Position = Vector3.new(x, root.Position.Y, z)
		root.AssemblyLinearVelocity = Vector3.zero
	end

	local function bonusText()
		local label = world.gui("HUD", "Bonuses")
		return if label and label.Visible then label.Text else ""
	end

	local function tierSum()
		local total = 0
		for _, weapon in WeaponService.getWeapons(me) do
			total += weapon.tier
		end
		return total
	end

	-- One more of an item unless the player owns its limit already (the shop test above buys random offers).
	-- Returns how many the player owns now.
	local function give(itemId)
		StatService.addItem(me, itemId)
		return StatService.getItemCounts(me)[itemId] or 0
	end

	it("runs item effects: standing still, per X, timers, crit kills, dodges and chests", function()
		local EffectService = require(ServerScriptService.Server.Services.EffectService)
		local wasPaused = SpawnDirector.isPaused()
		SpawnDirector.setPaused(true)
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.3)
		local center = Config.Map.arena.center
		standAt(center.X, center.Z)
		local root = me.Character.HumanoidRootPart

		-- Iron Vigil: +8 Armor while standing still (limit 1), shown over the HP bar
		root.AssemblyLinearVelocity = Vector3.new(16, 0, 0)
		world.advance(0.5)
		local armor = StatService.getStat(me, "armor")
		expect(give("IronVigil")).toBe(1)
		root.AssemblyLinearVelocity = Vector3.zero
		world.advance(0.5)
		expect(EffectService.getMoveState(me)).toBe("Still")
		expect(StatService.getStat(me, "armor")).toBe(armor + 8)
		expect(string.find(bonusText(), "+8 Armor (standing still)", 1, true) ~= nil).toBe(true)
		root.AssemblyLinearVelocity = Vector3.new(16, 0, 0)
		world.advance(0.5)
		expect(EffectService.getMoveState(me)).toBe("Moving")
		expect(StatService.getStat(me, "armor")).toBe(armor)
		expect(string.find(bonusText(), "standing still", 1, true)).toBe(nil)
		root.AssemblyLinearVelocity = Vector3.zero

		-- Bone Charm: +10 Max HP per different weapon
		local kinds, seen = 0, {}
		for _, weapon in WeaponService.getWeapons(me) do
			if not seen[weapon.id] then
				seen[weapon.id] = true
				kinds += 1
			end
		end
		local maxHp = StatService.getStat(me, "maxHp")
		give("BoneCharm")
		world.advance(0.1)
		expect(StatService.getStat(me, "maxHp")).toBe(maxHp + 10 * kinds)

		-- Field Censer: +2 HP Regeneration every 5 s of the wave
		give("FieldCenser")
		local regen = StatService.getStat(me, "hpRegen")
		world.advance(5.3)
		expect(StatService.getStat(me, "hpRegen") >= regen + 2).toBe(true)

		-- Hunter's Tally x3: crit kills give Shards (orbs are paused, so only the item pays)
		StatService.addStats(me, { critChance = 100 })
		for _ = 1, 3 do
			give("HuntersTally")
		end
		expect(select(2, StatService.addItem(me, "HuntersTally"))).toBe("Limit")
		local shards = ShopService.getShards(me)
		for k = 1, 16 do
			local angle = k / 16 * 2 * math.pi
			EnemySim.spawn("Shadeling", center.X + math.cos(angle) * 4, center.Z + math.sin(angle) * 4, 0.2, 1)
		end
		world.advance(3)
		expect(EnemySim.getCount()).toBe(0)
		expect(ShopService.getShards(me) > shards).toBe(true)
		StatService.addStats(me, { critChance = -100 })

		-- Pulse Draught: dodging heals 50 HP half the time, with a text over the character
		expect(give("PulseDraught")).toBe(1)
		CombatService.setHpFraction(me, 0.5)
		local hp = CombatService.getHp(me)
		for _ = 1, 20 do
			CombatService.Dodged:Fire(me)
		end
		world.advance(0.1)
		expect(CombatService.getHp(me) > hp).toBe(true)
		local shown = table.concat(controller("ProcTextController").getShown(), " | ")
		expect(string.find(shown, "+50 HP", 1, true) ~= nil).toBe(true)

		-- Satchel: +15 Shards per copy for a chest
		local satchels = give("Satchel")
		shards = ShopService.getShards(me)
		LootService.drop(Vector3.new(root.Position.X + 1, root.Position.Y, root.Position.Z))
		world.advance(0.3)
		expect(#LootService.getChests()).toBe(0)
		expect(ShopService.getShards(me) >= shards + 15 * satchels).toBe(true)

		-- the debug button gives the effect items one after another
		world.click(world.gui("Debug", "AddEffectItem"))
		world.advance(0.2)
		expect(string.find(toastTexts(), ": ", 1, true) ~= nil).toBe(true)
		SpawnDirector.setPaused(wasPaused)
	end)

	it("runs wave end, shop and next-wave effects and the shop stats", function()
		local rings = give("OathRing")
		give("GildedPlume")
		expect(give("TitheBox")).toBe(1)
		expect(give("MourningVeil")).toBe(1)
		expect(give("EmberAnvil")).toBe(1)
		local bells = give("JesterBell")
		for _ = 1, 5 do
			give("PawnTicket")
		end
		expect(StatService.getStat(me, "itemPrice")).toBe(-25) -- 5 at most
		local damage = StatService.getStat(me, "damage")
		local xpGain = StatService.getStat(me, "xpGain")
		local tiers = tierSum()
		local canUpgrade = false
		for _, weapon in WeaponService.getWeapons(me) do
			canUpgrade = canUpgrade or (weapon.tier < Config.Player.maxWeaponTier and not weapon.evolution)
		end

		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.3)
		expect(phase()).toBe("Shop")
		pickAll()
		-- Oath Ring grew at the wave end (Sweet Reliquary bought above may add more), told in a toast
		expect(StatService.getStat(me, "damage") >= damage + 3 * rings).toBe(true)
		expect(string.find(toastTexts(), "Oath Ring: +", 1, true) ~= nil).toBe(true)
		-- the Ember Anvil raised a weapon when the shop opened
		expect(tierSum()).toBe(if canUpgrade then tiers + 1 else tiers)
		-- the shop: 25 % off, free rerolls from Jester's Bell
		for _, offer in ShopService.getOffers(me) do
			expect(offer.price).toBe(ShopRules.offerPrice(offer, 0.75))
		end
		local reroll = world.gui("Shop", "Reroll").Text
		expect(reroll).toBe(if bells > 1 then `Reroll (free x{bells})` else "Reroll (free)")
		-- Gilded Plume's next wave has not started yet
		local xpInShop = StatService.getStat(me, "xpGain")
		expect(xpInShop >= xpGain).toBe(true) -- Bitter Tonic bought above grows it
		expect(StatService.getTeamStat("enemyDamage")).toBe(0)

		local shards = ShopService.getShards(me)
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.2)
		expect(phase()).toBe("Running")
		expect(StatService.getStat(me, "xpGain") >= xpInShop + 100).toBe(true)
		expect(StatService.getTeamStat("enemyDamage") >= 50).toBe(true)
		expect(string.find(bonusText(), "+50% Enemy Damage (this wave)", 1, true) ~= nil).toBe(true)
		expect(ShopService.getShards(me)).toBe(shards + math.floor(shards * 0.2)) -- Tithe Box
		local current, maxHpNow = CombatService.getHp(me)
		local half = math.ceil(maxHpNow * 0.5) -- Mourning Veil, plus a little regeneration since
		expect(current >= half and current <= half + maxHpNow * 0.1).toBe(true)

		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.3)
		pickAll()
		local tonics = StatService.getItemCounts(me).BitterTonic or 0
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.2)
		expect(StatService.getStat(me, "xpGain")).toBe(xpInShop + 5 * tonics) -- the next-wave bonus is gone
		expect(StatService.getTeamStat("enemyDamage")).toBe(0)
	end)

	local spawningWasPaused
	it("spawns a glowing elite with an HP bar that drops a chest", function()
		spawningWasPaused = SpawnDirector.isPaused()
		SpawnDirector.setPaused(true)
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.3)
		world.click(world.gui("Debug", "ToggleWeapons")) -- weapons off: the elite stays alive until we kill it
		world.advance(0.3)
		world.click(world.gui("Debug", "SpawnElite"))
		world.advance(0.5)
		expect(EnemySim.getCount()).toBe(1)
		expect(string.find(toastTexts(), "Spawned a Gloom", 1, true) ~= nil).toBe(true)
		local models = drawnModels()
		expect(#models).toBe(1)
		local model = models[1]
		expect(model ~= nil and string.sub(model.Name, 1, 5) == "Elite").toBe(true)
		expect(model ~= nil and model:FindFirstChild("HpBar", true) ~= nil).toBe(true)

		world.click(world.gui("Debug", "HitNearby")) -- out of reach: the elite spawned on the ring
		world.advance(0.3)
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.3)
		local chests = LootService.getChests()
		expect(#chests).toBe(1)
		expect(controller("ChestController").getCount()).toBe(1)
		local folder = workspace:FindFirstChild("LanternfallChests")
		expect(folder ~= nil and #folder:GetChildren() == 1).toBe(true)
		-- walk far away from it: the arrow at the screen edge points at it
		local chest = chests[1]
		standAt(if chest.x > Config.Map.arena.center.X then chest.x - 90 else chest.x + 90, chest.z)
		world.advance(0.2)
		local arrow = world.gui("Chests", "ChestArrow")
		expect(arrow ~= nil and arrow.Visible).toBe(true)
	end)

	it("opens the chest when walked over and shows the reward", function()
		local itemsBefore = 0
		for _, count in StatService.getItemCounts(me) do
			itemsBefore += count
		end
		local chest = LootService.getChests()[1]
		standAt(chest.x + 10, chest.z)
		world.advance(0.3)
		expect(#LootService.getChests()).toBe(1) -- not close enough yet
		standAt(chest.x + 1, chest.z)
		world.advance(0.3)
		expect(#LootService.getChests()).toBe(0)
		expect(controller("ChestController").getCount()).toBe(0)
		local banner = world.gui("Chests", "ChestBanner")
		expect(banner ~= nil).toBe(true)
		local itemsAfter = 0
		for _, count in StatService.getItemCounts(me) do
			itemsAfter += count
		end
		-- an item of at least Uncommon rarity, unless the chest held an evolution
		local texts = {}
		for _, object in banner:GetDescendants() do
			if object.ClassName == "TextLabel" then
				table.insert(texts, object.Text)
			end
		end
		expect(itemsAfter - itemsBefore <= 1).toBe(true)
		expect(string.find(table.concat(texts, " | "), "CHEST", 1, true) ~= nil).toBe(true)
	end)

	it("gives the evolution from a chest once the build is ready", function()
		-- a fresh Spark Bolt at the max tier (an earlier test evolved the first one with the debug button)
		for _, weapon in WeaponService.getWeapons(me) do
			if weapon.id == "SparkBolt" then
				WeaponService.removeWeapon(me, weapon.uid)
			end
		end
		WeaponService.addWeapon(me, "SparkBolt", Config.Player.maxWeaponTier)
		StatService.addItem(me, "Focus")
		expect(table.find(UpgradeService.getEvolutions(me), "Starfire") ~= nil).toBe(true)
		local root = me.Character.HumanoidRootPart.Position
		LootService.drop(Vector3.new(root.X + 1, root.Y, root.Z))
		world.advance(0.3)
		expect(#LootService.getChests()).toBe(0)
		local evolved = false
		for _, weapon in WeaponService.getWeapons(me) do
			if weapon.id == "SparkBolt" then
				evolved = weapon.evolution == "Starfire"
			end
		end
		expect(evolved).toBe(true)
		local banner = world.gui("Chests", "ChestBanner")
		local texts = {}
		for _, object in banner:GetDescendants() do
			if object.ClassName == "TextLabel" then
				table.insert(texts, object.Text)
			end
		end
		expect(table.concat(texts, " | ")).toBe("CHEST | Starfire | Spark Bolt evolved!")
	end)

	it("lets Spitters shoot visible projectiles that hit the player", function()
		local center = Config.Map.arena.center
		standAt(center.X, center.Z) -- a clear line of fire: ruins stop shots
		world.advance(0.6)
		EnemySim.spawn("Spitter", center.X + 28, center.Z, 1, 1)
		-- the owner is protected for the rest of this run (see above), so count the hits instead of HP
		local hits = {}
		local connection = EnemySim.ShotHit:Connect(function(player, damage)
			table.insert(hits, { player = player, damage = damage })
		end)
		local seenShots = 0
		for _ = 1, 40 do
			world.advance(0.1)
			seenShots = math.max(seenShots, controller("EnemyShotRenderer").getCount())
		end
		expect(seenShots > 0).toBe(true)
		local shotParts = workspace:FindFirstChild("LanternfallEnemyShots")
		expect(shotParts ~= nil).toBe(true)
		connection:Disconnect()
		expect(#hits >= 1).toBe(true)
		expect(hits[1].player).toBe(me)
		expect(hits[1].damage).toBe(Config.Enemies.types.Spitter.ranged.projectileDamage)
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.3)
	end)

	it("starts Swarm Rush with a ring of Shadelings and no Gloom Elites", function()
		SpawnDirector.setPaused(false)
		-- an enemy left far behind comes back on the spawn ring
		local center = Config.Map.arena.center
		standAt(center.X - 60, center.Z)
		local straggler = EnemySim.spawn("Brute", center.X + 60, center.Z, 1, 1)
		world.advance(Config.Run.spawn.recycle.intervalSeconds + 0.3)
		local position = EnemySim.getPosition(straggler)
		local root = me.Character.HumanoidRootPart.Position
		expect(position ~= nil and (position - root).Magnitude <= Config.Run.spawn.ringMax + 2).toBe(true)
		RunDirector.skipTo(RunSchedule.wave(Config.Run.spawn.swarmRush.atMinutes[1] + 1).startsAt + 0.1)
		world.advance(1)
		expect(SpawnDirector.isSwarmRush()).toBe(true)
		-- B11: the Gloom Elites of the skipped minutes are off on every danger level
		expect(string.find(toastTexts(), "appeared! Kill it for a chest.", 1, true)).toBe(nil)
		-- the HUD's wave banner announces it
		expect(world.gui("HUD", "WaveTitle").Text).toBe(`WAVE {Config.Run.spawn.swarmRush.atMinutes[1] + 1}`)
		expect(string.find(world.gui("HUD", "WaveEvents").Text, "Swarm Rush", 1, true) ~= nil).toBe(true)
		expect(EnemySim.getCount() >= Config.Run.spawn.swarmRush.ringCount / 2).toBe(true)
		SpawnDirector.setPaused(spawningWasPaused)
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.3)
		world.click(world.gui("Debug", "ToggleWeapons")) -- weapons back on
		world.advance(0.3)
		for _ = 1, 5 do -- picks up the chests of elites that came with the skipped minutes
			local chest = LootService.getChests()[1]
			if chest then
				standAt(chest.x, chest.z)
				world.advance(0.3)
			end
		end
		expect(#LootService.getChests()).toBe(0)
	end)

	it("shows a Charger's wind-up, splits Splitters and names elite affixes", function()
		SpawnDirector.setPaused(true)
		WeaponService.setPaused(true)
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.3)
		local center = Config.Map.arena.center
		standAt(center.X, center.Z)
		local function modelNamed(name)
			for _, model in drawnModels() do
				if model.Name == name then
					return model
				end
			end
			return nil
		end
		-- a Charger near the player stops and lights up the path of its rush
		local charger = EnemySim.spawn("Charger", center.X + 15, center.Z, 1, 1) :: number
		local waited = 0
		while EnemySim.getMode(charger) ~= 1 and waited < 4 do
			world.advance(0.1)
			waited += 0.1
		end
		expect(EnemySim.getMode(charger)).toBe(1)
		world.advance(0.2) -- the client draws about 0.1 s behind
		local chargerModel = modelNamed("Charger")
		expect(chargerModel ~= nil and chargerModel.RushPath.Transparency < 1).toBe(true)
		-- a killed Splitter falls apart into Splitlings
		local split = Config.Enemies.types.Splitter.split :: any
		local splitter = EnemySim.spawn("Splitter", center.X - 20, center.Z, 1, 1) :: number
		local before = EnemySim.getCount()
		EnemySim.damage(splitter, 1e6, me)
		expect(EnemySim.getCount()).toBe(before - 1 + split.count)
		-- an elite with an affix carries its name above the HP bar
		EnemySim.spawn("Brute", center.X, center.Z + 25, 1, 1, true, 1)
		world.advance(0.3)
		local elite = modelNamed("EliteBrute")
		local label = elite and elite:FindFirstChild("Affix", true)
		expect(label ~= nil and label.Visible).toBe(true)
		expect(label and label.Text).toBe(string.upper(Config.Enemies.elite.affixes[1].displayName))
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.3)
		for _ = 1, 3 do -- picks up the elite's chest
			local chest = LootService.getChests()[1]
			if chest then
				standAt(chest.x, chest.z)
				world.advance(0.3)
			end
		end
		WeaponService.setPaused(false)
		SpawnDirector.setPaused(spawningWasPaused)
	end)

	it("runs Brotato's combat: weapon class bonuses, burning, exploding items and slowed enemies", function()
		local wasPaused = SpawnDirector.isPaused()
		SpawnDirector.setPaused(true)
		WeaponService.setPaused(false)
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.3)
		local center = Config.Map.arena.center
		standAt(center.X, center.Z)

		-- weapon classes: a second Orbit Blades gives Edge 2 and Spectral 2 on top of the stats
		for _, weapon in WeaponService.getWeapons(me) do
			WeaponService.removeWeapon(me, weapon.uid)
		end
		WeaponService.addWeapon(me, "OrbitBlades")
		local melee, dodge = StatService.getStat(me, "meleeDamage"), StatService.getStat(me, "dodge")
		local _, _, second = WeaponService.addWeapon(me, "OrbitBlades")
		expect(StatService.getStat(me, "meleeDamage")).toBe(melee + 1)
		expect(StatService.getStat(me, "dodge")).toBe(dodge + 6)
		WeaponService.removeWeapon(me, second :: number)
		expect(StatService.getStat(me, "meleeDamage")).toBe(melee)
		WeaponService.addWeapon(me, "OrbitBlades")

		-- Smoldering Wick x4: blade hits set enemies on fire, the clients see it, burn ticks show in orange
		for _ = 1, 4 do
			give("SmolderingWick")
		end
		local tough = {}
		for k = 1, 6 do
			local angle = k / 6 * 2 * math.pi
			local id = EnemySim.spawn("Brute", center.X + math.cos(angle) * 5, center.Z + math.sin(angle) * 5, 50, 0)
			table.insert(tough, id)
		end
		local burning, shownBurning = false, false
		for _ = 1, 30 do
			world.advance(0.1)
			for _, id in tough do
				burning = burning or WeaponService.isBurning(id)
				shownBurning = shownBurning or (enemyRenderer().getStatus(id))
			end
		end
		expect(burning).toBe(true)
		expect(shownBurning).toBe(true)

		-- Thorn Trail slows what stands on it; the clients see it
		WeaponService.addWeapon(me, "ThornTrail")
		local slowed = false
		for _ = 1, 20 do
			world.advance(0.1)
			for _, id in tough do
				slowed = slowed or select(2, enemyRenderer().getStatus(id))
			end
		end
		expect(slowed).toBe(true)

		-- Bursting Sigil x3: kills blow up (the "Explosion" visual)
		world.click(world.gui("Debug", "KillEnemies"))
		for _ = 1, 3 do
			give("BurstingSigil")
		end
		local blasts = 0
		for _ = 1, 3 do
			for k = 1, 10 do
				local angle = k / 10 * 2 * math.pi
				EnemySim.spawn("Shadeling", center.X + math.cos(angle) * 4, center.Z + math.sin(angle) * 4, 0.2, 0)
			end
			for _ = 1, 15 do
				world.advance(0.1)
				blasts = math.max(blasts, weaponParts("Explosion"))
			end
		end
		expect(blasts > 0).toBe(true)

		-- the debug button gives the combat items one after another
		world.click(world.gui("Debug", "AddCombatItem"))
		world.advance(0.2)
		expect(string.find(toastTexts(), ": ", 1, true) ~= nil).toBe(true)
		world.click(world.gui("Debug", "KillEnemies"))
		world.advance(0.2)
		SpawnDirector.setPaused(wasPaused)
	end)

	it("puts a respawned participant back into the arena", function()
		world.spawnCharacter(me)
		world.advance(0.5)
		expect(inZone(me, "Arena")).toBe(true)
	end)

	it("skips to the boss wave, and surviving it wins (WP10)", function()
		world.click(world.gui("Debug", "HoldWaves")) -- the wave timer runs again
		world.advance(0.1)
		expect(RunDirector.isHoldingWaves()).toBe(false)
		world.click(world.gui("Debug", "SkipToBoss"))
		world.advance(0.2)
		expect(phase()).toBe("Shop") -- the shop of the wave before the boss wave
		expect(RunDirector.getWave()).toBe(RunSchedule.waveCount() - 1)
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(0.2)
		expect(phase()).toBe("Running")
		expect(RunDirector.getWave()).toBe(RunSchedule.waveCount())
		world.advance(Config.Enemies.bossWave.introSeconds + 0.3)
		expect(#BossService.getBosses()).toBe(1)
		RunDirector.skipTo(Config.Run.durationSeconds) -- its time runs out with the boss alive
		world.advance(0.2)
		-- playtest after Paket 24: first the vote "continue in endless mode?"; END RUN wins the run
		expect(phase()).toBe("Shop")
		expect(world.gui("EndlessChoice").Enabled).toBe(true)
		expect(world.gui("EndlessChoice", "Title").Text).toBe("BOSS DEFEATED!")
		world.click(world.gui("EndlessChoice", "Stop"))
		world.advance(0.2)
		expect(world.gui("EndlessChoice").Enabled).toBe(false)
		expect(phase()).toBe("Ended")
		expect(world.gui("Results").Enabled).toBe(true)
		expect(world.gui("HUD").Enabled).toBe(false)
		expect(firstText("Results", "Results")).toBe("VICTORY")
		local tally = RunStatsService.getTally()
		expect(world.gui("Results", "Stats").Text).toBe(`Team level {tally:getLevel()} · {tally.kills} kills`)
		expect(tally.kills > 0).toBe(true)
		local row = world.gui("Results", "Team"):FindFirstChildOfClass("TextLabel").Text
		expect(string.match(row, "^Owner · Spark Mage · %d+ kills · [%d%.k]+ damage · took [%d%.k]+$") ~= nil).toBe(
			true
		)
		world.advance(0.2)
		expect(EnemySim.getCount()).toBe(0)
		expect(#drawnModels()).toBe(0)
		expect(weaponParts("OrbitBlade") + weaponParts("SparkBolt") + weaponParts("Shockwave")).toBe(0)
		expect(#workspace.LanternfallWeapons:GetChildren()).toBe(0) -- halos, bodies and rings went with them
	end)

	it("starts the next run with Play again", function()
		world.click(world.gui("Results", "PlayAgain"))
		world.advance(0.2)
		expect(phase()).toBe("Countdown")
		expect(inZone(me, "Lobby")).toBe(true)
		world.advance(3.2)
		expect(phase()).toBe("Running")
		expect(RunDirector.getElapsed() < 1).toBe(true)
		expect(weaponRows()).toBe("Spark Bolt I") -- every run starts with only the class weapon
		expect(itemRows()).toBe("") -- and without items
		expect(world.gui("HUD", "ItemsTitle").Visible).toBe(false)
		expect(world.gui("HUD", "XpText").Text).toBe("LV 1")
		expect(ExperienceService.getOrbCount()).toBe(0)
		expect(WeaponService.isPaused()).toBe(false)
	end)

	it("follows the character with the fixed top-down camera", function()
		local camera = workspace.CurrentCamera
		local root = me.Character.HumanoidRootPart.Position
		expect(camera.CameraType).toBe(Enum.CameraType.Scriptable)
		expect(camera.FieldOfView).toBe(Config.Camera.fieldOfView)
		local offset = camera.CFrame.Position - root
		expect(offset.Magnitude).toBeNear(Config.Camera.distance, 0.5)
		expect(math.deg(math.asin(offset.Y / offset.Magnitude))).toBeNear(Config.Camera.pitchDegrees, 0.5)
		expect(offset.Z > 0).toBe(true) -- south of the character, looking north
	end)

	it("dashes with Space, starts the cooldown and turns jumping off", function()
		local humanoid = me.Character.Humanoid
		expect(humanoid.JumpPower).toBe(0)
		expect(humanoid.WalkSpeed).toBe(Config.Player.moveSpeed)
		humanoid.MoveDirection = Vector3.new(1, 0, 0)
		local result = world.pressAction("LanternfallDash")
		expect(result).toBe(Enum.ContextActionResult.Sink)
		local velocity = me.Character.HumanoidRootPart:FindFirstChild("LanternfallDash")
		expect(velocity ~= nil).toBe(true)
		expect(velocity.PlaneVelocity.X).toBeNear(Config.Player.dash.distance / Config.Player.dash.duration, 0.01)
		local streak = me.Character.HumanoidRootPart:FindFirstChild("LanternfallDashTrail")
		expect(streak ~= nil and streak.Enabled).toBe(true) -- the streak of light behind the dash
		world.advance(0.3)
		expect(me.Character.HumanoidRootPart:FindFirstChild("LanternfallDash")).toBe(nil)
		expect(streak.Enabled).toBe(false)
		local vitals = CombatService.getHp(me)
		expect(vitals).toBe(100)
		local PlayerStateController = require(folderProxy("src/client", "Client").Controllers.PlayerStateController)
		local readyAt = PlayerStateController.getLocal().dashReadyAt
		expect(readyAt - workspace:GetServerTimeNow()).toBeNear(Config.Player.dash.cooldown - 0.3, 0.2)
		-- a second press during the cooldown does nothing
		world.pressAction("LanternfallDash")
		expect(me.Character.HumanoidRootPart:FindFirstChild("LanternfallDash")).toBe(nil)
		expect(world.gui("Dash", "Cooldown").Size.Y.Scale > 0.8).toBe(true)
		humanoid.MoveDirection = Vector3.new(0, 0, 0)
	end)

	it("takes debug damage with hit protection and heals", function()
		world.click(world.gui("Debug", "HurtSelf"))
		world.advance(0.1)
		world.click(world.gui("Debug", "HurtSelf")) -- still protected
		world.advance(0.1)
		expect(CombatService.getHp(me)).toBe(100 - Config.Admin.hurtSelfDamage)
		expect(world.gui("HUD", "HpText").Text).toBe(`{100 - Config.Admin.hurtSelfDamage} / 100`)
		world.click(world.gui("Debug", "HealSelf"))
		world.advance(0.6)
		expect(CombatService.getHp(me)).toBe(100)
	end)

	it("ends in defeat when the only player is knocked down", function()
		world.click(world.gui("Debug", "GainLevel"))
		world.advance(0.2)
		expect(world.gui("LevelUp").Enabled).toBe(false) -- the choice waits for the end of the wave
		world.click(world.gui("Debug", "DownSelf"))
		world.advance(0.2)
		expect(phase()).toBe("Ended")
		expect(world.gui("LevelUp").Enabled).toBe(false)
		expect(UpgradeService.getOffer(me)).toBe(nil)
		expect(CombatService.isChoosing(me)).toBe(false)
		expect(firstText("Results", "Results")).toBe("DEFEAT")
	end)

	it("returns to the lobby after the results", function()
		world.advance(15.5)
		expect(phase()).toBe("Lobby")
		expect(world.gui("Lobby").Enabled).toBe(true)
		expect(world.gui("Results").Enabled).toBe(false)
		expect(inZone(me, "Lobby")).toBe(true)
	end)

	local friend, late
	it("runs with two players and keeps late joiners in the lobby", function()
		friend = world.addPlayer("Friend", 2, false)
		world.advance(0.5)
		world.click(world.gui("Lobby", "Ready"))
		world.advance(1)
		expect(phase()).toBe("Countdown")
		-- friend is not ready yet, so the long countdown runs
		world.advance(3)
		expect(phase()).toBe("Countdown")
		world.fireServerAs(friend, "SelectClass", "SparkMage")
		world.fireServerAs(friend, "SetReady", true)
		world.advance(3.2)
		expect(phase()).toBe("Running")
		expect(#RunDirector.getParticipants()).toBe(2)
		expect(inZone(friend, "Arena")).toBe(true)

		late = world.addPlayer("Late", 3, false)
		world.advance(0.5)
		expect(inZone(late, "Lobby")).toBe(true)
		expect(RunDirector.getParticipantState(late)).toBe(nil)
	end)

	it("keeps running while one of two is down, and enemies go for the one still standing", function()
		expect(WeaponService.getWeapons(friend)[1].id).toBe("SparkBolt") -- the friend's class weapon
		world.click(world.gui("Debug", "ToggleWeapons")) -- or the friend's bolts keep the enemies away
		CombatService.protect(friend, 1e6)
		world.click(world.gui("Debug", "DownSelf"))
		world.advance(0.2)
		expect(phase()).toBe("Running")
		expect(teamText()).toBe("Owner · DOWN | Friend · alive · 100 HP")
		expect(me.Character.Humanoid.WalkSpeed).toBe(0)
		world.advance(8)
		local friendRoot = friend.Character.HumanoidRootPart.Position
		local _, distance = EnemySim.nearest(friendRoot)
		expect(distance < 5).toBe(true)
		CombatService.protect(me, 1) -- the crowd around the friend can reach the owner right after standing up
		world.click(world.gui("Debug", "ReviveSelf"))
		world.advance(0.2)
		local reviveHp = math.ceil(100 * Config.Run.coop.reviveHpFraction)
		expect(teamText()).toBe(`Owner · alive · {reviveHp} HP | Friend · alive · 100 HP`)
		expect(me.Character.Humanoid.WalkSpeed).toBe(Config.Player.moveSpeed)
	end)

	it("stands a downed player up with full HP when the wave ends", function()
		world.click(world.gui("Debug", "DownSelf"))
		world.advance(0.2)
		expect(RunDirector.getParticipantState(me)).toBe("Down")
		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.2)
		expect(phase()).toBe("Shop")
		expect(teamText()).toBe("Owner · alive · 100 HP · shopping | Friend · alive · 100 HP · shopping")
		world.fireServerAs(friend, "SetShopReady", true)
		world.advance(0.2)
		expect(teamText()).toBe("Owner · alive · 100 HP · shopping | Friend · alive · 100 HP · ready")
		expect(phase()).toBe("Shop")
	end)

	it("ends when the last alive player leaves", function()
		world.click(world.gui("Debug", "DownSelf"))
		world.advance(0.2)
		world.removePlayer(friend)
		world.advance(0.2)
		expect(phase()).toBe("Ended")
		expect(firstText("Results", "Results")).toBe("DEFEAT")
	end)

	it("rejects locked classes with a message", function()
		local RunStateController = require(folderProxy("src/client", "Client").Controllers.RunStateController)
		world.fireServerAs(late, "SelectClass", "Trapper")
		world.fireServerAs(me, "SelectClass", "Trapper")
		world.advance(0.2)
		expect(RunStateController.getPlayer(3).classId).toBe("BladeWarden")
		local toasts = {}
		for _, object in world.gui("Notify"):GetDescendants() do
			if object.ClassName == "TextLabel" then
				table.insert(toasts, object.Text)
			end
		end
		expect(table.find(toasts, "This character is not unlocked yet") ~= nil).toBe(true)
	end)

	it("finished without any runtime error", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n\n"))
		end
	end)
end)
