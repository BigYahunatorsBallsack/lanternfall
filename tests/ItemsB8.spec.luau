-- Tests of the item package (B8): the new effect rules (PerX with negative per and a floor, living enemies and items
-- per tier as sources, full HP on fruits and crates), their texts, and end to end in a simulated Roblox
-- (tests/helpers/RobloxMock, like tests/Loot.spec.luau): strikes on enemies, HP drain, Second Stomach, Witch's
-- Kettle, Rabble Banner, Hearth Sprite and Velvet Divan. Look and feel: Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local CombatService = require(Services.CombatService)
local EnemySim = require(Services.EnemySim)
local LootService = require(Services.LootService)
local MapService = require(Services.MapService)
local RunDirector = require(Services.RunDirector)
local StatService = require(Services.StatService)
local EffectRules = require(Services.EffectService.EffectRules)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local EffectText = require(Shared.Util.EffectText)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local function click(name)
	world.click(world.gui("Debug", name))
	world.advance(0.2)
end

local function position(): Vector3
	return MapService.getRootPosition(me) :: Vector3
end

local function give(itemId: string)
	local ok, reason = StatService.addItem(me, itemId)
	assert(ok, reason)
	world.advance(0.1)
end

local function stat(id: string): number
	return StatService.getStat(me, id)
end

local function context(overrides)
	local base = { moveState = nil, permanent = {}, shards = 0, distinctWeapons = 0 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function effectOf(itemId: string, index: number?)
	return (Config.Items.byId[itemId].effects :: any)[index or 1]
end

describe("item rules (B8)", function()
	it("has about a hundred items", function()
		expect(#Config.Items.list >= 110).toBe(true)
	end)

	it("counts per -1 % Speed with a floor of 0 (Velvet Divan)", function()
		local divan = effectOf("VelvetDivan")
		expect(EffectRules.perXSteps(divan, context({ permanent = { speed = -20 } }))).toBe(20)
		expect(EffectRules.perXSteps(divan, context({ permanent = { speed = 15 } }))).toBe(0)
	end)

	it("counts living enemies and different items per tier", function()
		local banner = effectOf("RabbleBanner")
		expect(EffectRules.perXSteps(banner, context({ enemies = 37 }))).toBe(37)
		local tiers = EffectRules.distinctItemTiers({ Might = 3, Haste = 1, GlassLantern = 2, EternalFlame = 1 })
		expect(tiers[1]).toBe(2)
		expect(tiers[3]).toBe(1)
		expect(tiers[4]).toBe(1)
		local sheet =
			EffectRules.passive(EffectRules.entries({ HearthSprite = 1 }), context({ distinctItemTiers = tiers }))
		expect(sheet.hpRegen).toBe(2 - 3)
	end)

	it("fires Second Stomach only at full HP", function()
		local entry =
			{ key = "SecondStomach#1", itemId = "SecondStomach", effect = effectOf("SecondStomach"), count = 1 }
		local buffs = EffectRules.newBuffs()
		expect(EffectRules.matches(entry, { trigger = "Consumable", wave = 3, fullHp = false }, buffs)).toBe(false)
		expect(EffectRules.matches(entry, { trigger = "Consumable", wave = 3, fullHp = true }, buffs)).toBe(true)
		for _ = 1, 8 do
			EffectRules.countFiring(entry, buffs)
		end
		expect(EffectRules.matches(entry, { trigger = "Consumable", wave = 3, fullHp = true }, buffs)).toBe(false)
	end)

	it("describes the new effects", function()
		expect(EffectText.lines(Config.Items.byId.RollingEye.effects)).toBe(
			"Kill: 1 (+25% Luck) damage to a random enemy (25%)"
		)
		expect(EffectText.lines(Config.Items.byId.TitanGirdle.effects)).toBe(
			"Crit: 10% of the enemy's current HP as damage (1% vs elites)"
		)
		expect(EffectText.lines(Config.Items.byId.CrimsonHand.effects, " | ")).toBe(
			"+2% Damage per 1% Life Steal | Every 1s: lose 10 HP"
		)
		expect(EffectText.lines(Config.Items.byId.VelvetDivan.effects)).toBe("+2 HP Regeneration per -1% Speed")
		expect(EffectText.lines(Config.Items.byId.SecondStomach.effects)).toBe(
			"Fruit or crate at full HP: +10 Max HP (max 8 per wave)"
		)
		expect(EffectText.lines(Config.Items.byId.HearthSprite.effects, " | ")).toBe(
			"+1 HP Regeneration per different Common item | -3 HP Regeneration per different Legendary item"
		)
		expect(EffectText.lines(Config.Items.byId.RabbleBanner.effects)).toBe("+1% Attack Speed per living enemy")
	end)
end)

describe("items in a run (B8)", function()
	it("starts a run with weapons off, spawning paused and random drops off", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(3.5)
		expect(RunDirector.getPhase()).toBe("Running")
		LootService.setDropsPaused(true)
		click("ToggleWeapons")
		click("ToggleSpawning")
		click("HoldWaves")
		expect(EnemySim.getCount()).toBe(0)
	end)

	it("grows Max HP from a fruit picked up at full HP, not when hurt (Second Stomach)", function()
		give("SecondStomach")
		local _, maxHp = CombatService.getHp(me)
		CombatService.healPlayer(me, maxHp)
		LootService.dropPickup(position(), "Fruit")
		world.advance(0.3)
		local _, grown = CombatService.getHp(me)
		expect(grown).toBe(maxHp + 10)
		CombatService.protect(me, 0)
		click("HurtSelf")
		LootService.dropPickup(position(), "Fruit")
		world.advance(0.3)
		local _, after = CombatService.getHp(me)
		expect(after).toBe(grown)
	end)

	it("gives +20% Damage for 2 s after a fruit (Witch's Kettle)", function()
		give("WitchKettle")
		local damage = stat("damage")
		LootService.dropPickup(position(), "Fruit")
		world.advance(0.3)
		expect(stat("damage")).toBe(damage + 20)
		world.advance(2)
		expect(stat("damage")).toBe(damage)
	end)

	it("adds Attack Speed per living enemy (Rabble Banner)", function()
		give("RabbleBanner")
		local attackSpeed = stat("attackSpeed")
		local here = position()
		for i = 1, 5 do
			EnemySim.spawn("Shadeling", here.X + 60, here.Z + i * 4, 1, 1)
		end
		world.advance(0.2)
		expect(stat("attackSpeed")).toBe(attackSpeed + 5)
		click("KillEnemies")
		world.advance(0.2)
		expect(stat("attackSpeed")).toBe(attackSpeed)
	end)

	it("adds HP Regeneration per Common item and takes it per Legendary item (Hearth Sprite)", function()
		local regen = stat("hpRegen")
		give("HearthSprite")
		local tiers = EffectRules.distinctItemTiers(StatService.getItemCounts(me))
		expect(stat("hpRegen")).toBe(regen + tiers[1] - 3 * tiers[4])
		local before = stat("hpRegen")
		give("BrassCarapace") -- a new Legendary: -3, and its own -2
		expect(stat("hpRegen")).toBe(before - 3 - 2)
	end)

	it("turns every -1 % Speed into +2 HP Regeneration (Velvet Divan)", function()
		local regen = stat("hpRegen")
		local speedBefore = StatService.getPermanentSheet(me).speed or 0
		give("VelvetDivan")
		local speed = StatService.getPermanentSheet(me).speed or 0
		expect(speed).toBe(speedBefore - 20)
		-- Hearth Sprite (above) takes 3 for the new Legendary
		expect(stat("hpRegen")).toBe(regen + 2 * (math.max(0, -speed) - math.max(0, -speedBefore)) - 3)
	end)

	it("strikes another enemy when one dies (Rolling Eye)", function()
		for _ = 1, 40 do
			give("RollingEye") -- 25% each: one strike is all but sure
		end
		CombatService.protect(me, 60)
		local here = position()
		local brute = EnemySim.spawn("Brute", here.X + 90, here.Z, 100, 1) :: number -- out of weapon range
		local shade = EnemySim.spawn("Shadeling", here.X + 8, here.Z, 1, 1) :: number
		local full = EnemySim.getHealth(brute)
		click("ToggleWeapons")
		local seconds = 0
		while EnemySim.isAlive(shade) and seconds < 5 do
			world.advance(0.1)
			seconds += 0.1
		end
		world.advance(0.2)
		expect(EnemySim.isAlive(shade)).toBe(false)
		expect(EnemySim.getHealth(brute) < full).toBe(true)
		click("ToggleWeapons")
		click("KillEnemies")
	end)

	it("deals 10% of the enemy's current HP on a crit (Titan's Girdle)", function()
		give("TitanGirdle")
		StatService.addStats(me, { critChance = 100 })
		local here = position()
		local brute = EnemySim.spawn("Brute", here.X + 10, here.Z, 100, 1) :: number
		local full = EnemySim.getHealth(brute)
		click("ToggleWeapons")
		local seconds = 0
		while EnemySim.getHealth(brute) >= full and seconds < 5 do
			world.advance(1 / 15)
			seconds += 1 / 15
		end
		world.advance(1 / 15)
		click("ToggleWeapons")
		-- the weapon hits deal tens of HP, the girdle about 10 % of 6000
		expect(full - EnemySim.getHealth(brute) > 0.09 * full).toBe(true)
		click("KillEnemies")
	end)

	it("drains 10 HP a second but never below 1, and adds Damage per Life Steal (Crimson Hand)", function()
		local damage = stat("damage")
		give("CrimsonHand")
		local lifeSteal = StatService.getPermanentSheet(me).lifeSteal or 0
		expect(stat("damage")).toBe(damage + 2 * math.floor(lifeSteal + 1e-9))
		local _, maxHp = CombatService.getHp(me)
		CombatService.healPlayer(me, maxHp)
		CombatService.protect(me, 60) -- hit protection does not stop the drain
		world.advance(3.05)
		local hp = CombatService.getHp(me)
		expect(hp < maxHp).toBe(true)
		CombatService.setHpFraction(me, 0)
		world.advance(3)
		local low = CombatService.getHp(me)
		expect(low >= 1).toBe(true)
		expect(RunDirector.getParticipantState(me)).toBe("Alive")
	end)

	it("gives the new items one after another with the debug button", function()
		local first = Config.Admin.newItems[1]
		local before = StatService.getItemCounts(me)[first] or 0
		click("AddNewItem")
		expect(StatService.getItemCounts(me)[first]).toBe(before + 1)
	end)

	it("finished without any runtime error", function()
		expect(#world.errors).toBe(0)
	end)
end)
