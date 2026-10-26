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
local UpgradePool = require(ServerScriptService.Server.Services.UpgradeService.UpgradePool)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

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

local function passiveRows()
	local lines = {}
	for _, row in world.gui("HUD", "PassiveRows"):GetChildren() do
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
		expect(weaponRows()).toBe("Spark Bolt · LV 1")
		expect(world.gui("HUD", "WeaponsTitle").Text).toBe("WEAPONS")
		local weapon = WeaponService.getWeapons(me)[1]
		expect(weapon.stats.cooldown).toBeNear(Config.Weapons.SparkBolt.base.cooldown * 0.9) -- Spark Mage bonus
		ExperienceService.setPaused(true) -- no level-up cards in the way until the level-up tests below
		world.click(world.gui("Debug", "ToggleWeapons"))
		world.advance(0.2)
		expect(WeaponService.isPaused()).toBe(true)
		expect(world.gui("HUD", "WeaponsTitle").Text).toBe("WEAPONS (OFF)")
	end)

	it("counts the run timer up", function()
		world.advance(5)
		expect(firstText("HUD", "Timer")).toBe("00:05")
		expect(string.match(teamText(), "^Owner · alive · %d+ HP$") ~= nil).toBe(true)
		expect(string.match(world.gui("HUD", "HpText").Text, "^%d+ / 100$") ~= nil).toBe(true) -- Spark Mage: no bonus
	end)

	it("spawns enemies on a ring around the player and draws them", function()
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
		local hpBefore = CombatService.getHp(me)
		local connection = EnemySim.Contact:Connect(function(player, damage)
			expect(player).toBe(me)
			expect(damage).toBe(Config.Enemies.types.Shadeling.contactDamage)
			contacts += 1
		end)
		world.advance(5)
		connection:Disconnect()
		expect(contacts > 0).toBe(true)
		-- every touch hurts, at most once per hit protection window
		local lost = hpBefore - CombatService.getHp(me)
		local hitsAllowed = math.ceil(5 / Config.Player.hitInvulnerability) + 1
		expect(lost > 0).toBe(true)
		expect(lost <= hitsAllowed * Config.Enemies.types.Shadeling.contactDamage).toBe(true)
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
		expect(stats.Enemies.Text).toBe(
			`Enemies {Config.Run.spawn.cap.base} / {Config.Run.spawn.cap.base} · drawn {Config.Run.spawn.cap.base}`
		)
		expect(string.find(stats.Server.Text, "Server step", 1, true) ~= nil).toBe(true)
		expect(string.find(stats.Network.Text, "KB/s", 1, true) ~= nil).toBe(true)
	end)

	it("shoots Spark Bolts that kill enemies once weapons are on", function()
		local kills = 0
		local connection = EnemySim.EnemyKilled:Connect(function(info)
			if info.killer == me then
				kills += 1
			end
		end)
		world.click(world.gui("Debug", "ToggleWeapons"))
		local mostBolts = 0
		for _ = 1, 30 do
			world.advance(0.1)
			mostBolts = math.max(mostBolts, weaponParts("SparkBolt"))
		end
		connection:Disconnect()
		expect(WeaponService.isPaused()).toBe(false)
		expect(kills > 0).toBe(true)
		expect(mostBolts > 0).toBe(true)
		expect(WeaponService.getDamageStats(me).SparkBolt.kills).toBe(kills)
	end)

	it("adds, levels and swaps weapons with the debug buttons and draws them", function()
		-- getImplemented is sorted: BoomerangAxe, ChainLightning, OrbitBlades, Shockwave, SparkBolt, ThornTrail
		local function most(name, seconds)
			local best = 0
			for _ = 1, seconds / 0.1 do
				world.advance(0.1)
				best = math.max(best, weaponParts(name))
			end
			return best
		end
		world.click(world.gui("Debug", "AddWeapon"))
		world.click(world.gui("Debug", "SpawnWave"))
		expect(most("BoomerangAxe", 3) > 0).toBe(true)
		expect(weaponRows()).toBe("Spark Bolt · LV 1 | Boomerang Axe · LV 1")
		world.click(world.gui("Debug", "AddWeapon"))
		world.click(world.gui("Debug", "SpawnWave"))
		expect(most("ChainLightning", 3) > 0).toBe(true)
		world.click(world.gui("Debug", "AddWeapon"))
		world.advance(0.2)
		expect(weaponParts("OrbitBlade")).toBe(Config.Weapons.OrbitBlades.base.count)
		world.click(world.gui("Debug", "LevelUpWeapons"))
		world.advance(0.2)
		expect(weaponRows()).toBe(
			"Spark Bolt · LV 2 | Boomerang Axe · LV 2 | Chain Lightning · LV 2 | Orbit Blades · LV 2"
		)
		world.click(world.gui("Debug", "AddWeapon"))
		world.advance(0.2)
		expect(string.find(toastTexts(), "All weapon slots are full", 1, true) ~= nil).toBe(true)

		world.click(world.gui("Debug", "NextWeapon"))
		world.advance(0.2)
		expect(weaponRows()).toBe("Thorn Trail · LV 1")
		expect(weaponParts("ThornPatch") > 0).toBe(true)
		for _ = 1, 4 do -- Boomerang Axe, Chain Lightning, Orbit Blades, Shockwave
			world.click(world.gui("Debug", "NextWeapon"))
		end
		world.click(world.gui("Debug", "SpawnWave"))
		expect(most("Shockwave", 4) > 0).toBe(true)
		expect(weaponRows()).toBe("Shockwave · LV 1")

		world.click(world.gui("Debug", "NextWeapon")) -- Spark Bolt
		world.click(world.gui("Debug", "AddWeapon")) -- Boomerang Axe
		world.click(world.gui("Debug", "AddWeapon")) -- Chain Lightning
		world.click(world.gui("Debug", "AddWeapon")) -- Orbit Blades
		world.advance(1.1) -- debug buttons allow 5 clicks per second
		for _ = 1, Config.Player.maxItemLevel do
			world.click(world.gui("Debug", "LevelUpWeapons"))
		end
		world.advance(0.2)
		expect(weaponParts("OrbitBlade")).toBe(Config.Weapons.OrbitBlades.base.count + 2)
		world.advance(1)
		world.click(world.gui("Debug", "EvolveWeapons"))
		world.advance(0.2)
		expect(weaponRows()).toBe(
			"Starfire · MAX | Boomerang Axe · MAX | Chain Lightning · MAX | Blade Storm · MAX"
		)
		expect(string.find(toastTexts(), "Starfire, Blade Storm", 1, true) ~= nil).toBe(true)
		expect(weaponParts("OrbitBlade")).toBe(Config.Evolutions.BladeStorm.stats.count)
		local passives = passiveRows()
		expect(string.find(passives, "Focus", 1, true) ~= nil and string.find(passives, "Armor", 1, true) ~= nil).toBe(
			true
		)
		world.click(world.gui("Debug", "SpawnWave"))
		expect(most("Starfire", 3) > 0).toBe(true)
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

	it("opens level-up cards, freezes the chooser and applies the pick", function()
		world.click(world.gui("Debug", "GainLevel"))
		world.advance(0.1)
		local offer = UpgradeService.getOffer(me)
		expect(offer ~= nil).toBe(true)
		expect(#offer).toBe(Config.Run.levelUp.cardCount)
		expect(world.gui("LevelUp").Enabled).toBe(true)
		expect(world.gui("LevelUp", "Title").Text).toBe(`LEVEL {ExperienceService.getLevel()}`)
		expect(card(1):FindFirstChild("CardName").Text ~= "").toBe(true)
		expect(CombatService.isChoosing(me)).toBe(true)
		expect(me.Character.Humanoid.WalkSpeed).toBe(0)
		expect(string.find(teamText(), "picking", 1, true) ~= nil).toBe(true)
		world.click(card(1)) -- too soon after the cards appeared: ignored
		world.advance(0.1)
		expect(UpgradeService.getOffer(me)).toBe(offer)
		world.advance(Config.Run.levelUp.inputDelaySeconds)
		local chosen = offer[1]
		world.click(card(1))
		world.advance(0.2)
		expect(UpgradeService.getOffer(me)).toBe(nil)
		expect(world.gui("LevelUp").Enabled).toBe(false)
		expect(CombatService.isChoosing(me)).toBe(false)
		if chosen.kind == "Weapon" then
			expect(string.find(weaponRows(), Config.Weapons[chosen.itemId].displayName, 1, true) ~= nil).toBe(true)
		elseif chosen.kind == "Passive" then
			local name = Config.Passives[chosen.itemId].displayName
			expect(string.find(passiveRows(), name, 1, true) ~= nil).toBe(true)
			expect(world.gui("HUD", "PassivesTitle").Visible).toBe(true)
		end
		local haste = 0
		for _, info in UpgradeService.getPassives(me) do
			if info.id == "Haste" then
				haste = info.level
			end
		end
		local speed = Config.Player.moveSpeed * (1 + Config.Passives.Haste.perLevel * haste)
		expect(me.Character.Humanoid.WalkSpeed).toBeNear(speed)
	end)

	it("rerolls once and picks the first card when the time runs out", function()
		world.click(world.gui("Debug", "GainLevel"))
		world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
		local first = UpgradeService.getOffer(me)
		expect(world.gui("LevelUp", "Reroll").Text).toBe("Reroll (1 left)")
		world.click(world.gui("LevelUp", "Reroll"))
		world.advance(Config.Run.levelUp.inputDelaySeconds + 0.1)
		local second = UpgradeService.getOffer(me)
		expect(second ~= first).toBe(true)
		for _, newCard in second do
			for _, oldCard in first do
				expect(newCard.id ~= oldCard.id).toBe(true)
			end
		end
		expect(world.gui("LevelUp", "Reroll").Text).toBe("No rerolls left")
		world.click(world.gui("LevelUp", "Reroll"))
		world.advance(0.2)
		expect(UpgradeService.getOffer(me)).toBe(second)
		world.advance(Config.Run.levelUp.autoPickSeconds)
		expect(UpgradeService.getOffer(me)).toBe(nil)
		expect(CombatService.isChoosing(me)).toBe(false)
	end)

	it("lets passives change HP, speed, weapons and pickup radius", function()
		local bonuses = UpgradePool.passiveBonuses({ Vitality = 1, Haste = 1, Might = 1 })
		local damageBefore = WeaponService.getWeapons(me)[1].stats.damage
		local mightBefore = 0
		for _, info in UpgradeService.getPassives(me) do
			if info.id == "Might" then
				mightBefore = info.level * Config.Passives.Might.perLevel
			end
		end
		CombatService.setBonuses(me, bonuses)
		WeaponService.setBonuses(me, bonuses)
		ExperienceService.setBonuses(me, bonuses)
		world.advance(0.2)
		local _, maxHp = CombatService.getHp(me)
		expect(maxHp).toBe(math.round(Config.Player.maxHp * (1 + Config.Passives.Vitality.perLevel)))
		expect(me.Character.Humanoid.WalkSpeed).toBeNear(Config.Player.moveSpeed * (1 + Config.Passives.Haste.perLevel))
		local damage = WeaponService.getWeapons(me)[1].stats.damage
		expect(damage / damageBefore).toBeNear((1 + Config.Passives.Might.perLevel) / (1 + mightBefore))
		ExperienceService.setPaused(true) -- no cards in the way for the rest of the smoke test
		world.click(world.gui("Debug", "ToggleSpawning"))
		world.advance(0.2)
	end)

	it("puts a respawned participant back into the arena", function()
		world.spawnCharacter(me)
		world.advance(0.5)
		expect(inZone(me, "Arena")).toBe(true)
	end)

	it("skips to the boss phase, which counts as a victory for now", function()
		world.click(world.gui("Debug", "SkipToBoss"))
		world.advance(0.2)
		expect(RunDirector.getElapsed() >= 710).toBe(true)
		expect(phase()).toBe("Running")
		world.advance(10.5)
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
	end)

	it("starts the next run with Play again", function()
		world.click(world.gui("Results", "PlayAgain"))
		world.advance(0.2)
		expect(phase()).toBe("Countdown")
		expect(inZone(me, "Lobby")).toBe(true)
		world.advance(3.2)
		expect(phase()).toBe("Running")
		expect(RunDirector.getElapsed() < 1).toBe(true)
		expect(weaponRows()).toBe("Spark Bolt · LV 1") -- every run starts with only the class weapon
		expect(passiveRows()).toBe("") -- and without passives
		expect(world.gui("HUD", "PassivesTitle").Visible).toBe(false)
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
		world.advance(0.3)
		expect(me.Character.HumanoidRootPart:FindFirstChild("LanternfallDash")).toBe(nil)
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
		expect(world.gui("LevelUp").Enabled).toBe(true)
		world.click(world.gui("Debug", "DownSelf"))
		world.advance(0.2)
		expect(phase()).toBe("Ended")
		expect(world.gui("LevelUp").Enabled).toBe(false) -- the run end closes open cards
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
		expect(table.find(toasts, "This class is not unlocked yet") ~= nil).toBe(true)
	end)

	it("finished without any runtime error", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n\n"))
		end
	end)
end)
