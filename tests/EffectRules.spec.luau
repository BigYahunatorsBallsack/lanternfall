-- Unit tests for the item effect rules (EffectService/EffectRules) and their texts (Util/EffectText) against
-- Config.Effects, Config.Items and DESIGN.md section 6.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local EffectText = require(Shared.Util.EffectText)
local EffectRules = require(game:GetService("ServerScriptService").Server.Services.EffectService.EffectRules)

local function entry(effect, count, itemId)
	return { key = `{itemId or "Test"}#1`, itemId = itemId or "Test", effect = effect, count = count or 1 }
end

local function context(overrides)
	local base = { moveState = nil, permanent = {}, shards = 0, distinctWeapons = 0 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function sequence(values)
	local index = 0
	return function()
		index += 1
		return values[(index - 1) % #values + 1]
	end
end

describe("EffectRules", function()
	it("lists the effects of owned items with their counts, sorted by item", function()
		local list = EffectRules.entries({ StoneIdol = 2, Might = 3, BitterTonic = 1 })
		expect(#list).toBe(3) -- Might has no effects
		expect(list[1].itemId).toBe("BitterTonic")
		expect(list[1].key).toBe("BitterTonic#1")
		expect(list[2].key).toBe("BitterTonic#2")
		expect(list[3].itemId).toBe("StoneIdol")
		expect(list[3].count).toBe(2)
		local groups = EffectRules.byTrigger(list)
		expect(#groups.WaveEnd).toBe(1)
		expect(#groups.Acquire).toBe(1)
		expect(#groups.Always).toBe(1)
	end)

	it("gives standing-still stats only while standing still, times the count", function()
		local list = { entry({ trigger = "Always", action = "Stats", state = "Still", stats = { armor = 8 } }, 2) }
		expect(EffectRules.passive(list, context({ moveState = "Still" })).armor).toBe(16)
		expect(EffectRules.passive(list, context({ moveState = "Moving" })).armor).toBe(nil)
		expect(EffectRules.passive(list, context()).armor).toBe(nil) -- shop or down: neither
		expect(EffectRules.watchesMovement(list)).toBe(true)
		local bonuses = EffectRules.activeBonuses(list, context({ moveState = "Still" }), EffectRules.newBuffs())
		expect(#bonuses).toBe(1)
		expect(bonuses[1].kind).toBe("Still")
		expect(bonuses[1].stats.armor).toBe(16)
	end)

	it("counts per X: Shards, different weapons and permanent stats, rounded down, with a cap", function()
		local padding = { trigger = "Always", action = "PerX", source = "shards", per = 80, stats = { maxHp = 10 } }
		expect(EffectRules.passive({ entry(padding) }, context({ shards = 239 })).maxHp).toBe(20)
		expect(EffectRules.passive({ entry(padding) }, context({ shards = 79 })).maxHp).toBe(nil)
		local spider =
			{ trigger = "Always", action = "PerX", source = "distinctWeapons", per = 1, stats = { attackSpeed = 6 } }
		expect(EffectRules.passive({ entry(spider, 2) }, context({ distinctWeapons = 3 })).attackSpeed).toBe(36)
		local coin = { trigger = "Always", action = "PerX", source = "critChance", per = 1, stats = { luck = 2 } }
		expect(EffectRules.passive({ entry(coin) }, context({ permanent = { critChance = 7.5 } })).luck).toBe(14)
		-- negative sources round toward zero
		expect(EffectRules.passive({ entry(coin) }, context({ permanent = { critChance = -3.5 } })).luck).toBe(-6)
		local capped = table.clone(coin)
		capped.max = 3
		expect(EffectRules.passive({ entry(capped) }, context({ permanent = { critChance = 10 } })).luck).toBe(6)
		expect(EffectRules.counts({ entry(padding) }, "shards")).toBe(true)
		expect(EffectRules.counts({ entry(padding) }, "distinctWeapons")).toBe(false)
	end)

	it("matches triggers with crit, elite, wave window and limit per wave", function()
		local buffs = EffectRules.newBuffs()
		local trophy = entry({ trigger = "Kill", action = "Shards", amount = 1, crit = true })
		expect(EffectRules.matches(trophy, { trigger = "Kill", wave = 3, crit = true }, buffs)).toBe(true)
		expect(EffectRules.matches(trophy, { trigger = "Kill", wave = 3, crit = false }, buffs)).toBe(false)
		expect(EffectRules.matches(trophy, { trigger = "Hit", wave = 3, crit = true }, buffs)).toBe(false)
		local elite = entry({ trigger = "Hit", action = "Heal", amount = 10, elite = true })
		expect(EffectRules.matches(elite, { trigger = "Hit", wave = 1, elite = false }, buffs)).toBe(false)
		expect(EffectRules.matches(elite, { trigger = "Hit", wave = 1, elite = true }, buffs)).toBe(true)
		local piggy = entry({ trigger = "WaveStart", action = "ShardShare", amount = 20, untilWave = 19 })
		expect(EffectRules.matches(piggy, { trigger = "WaveStart", wave = 19 }, buffs)).toBe(true)
		expect(EffectRules.matches(piggy, { trigger = "WaveStart", wave = 20 }, buffs)).toBe(false)
		local limited = entry({ trigger = "Pickup", action = "Heal", amount = 10, maxPerWave = 2 })
		local event = { trigger = "Pickup", wave = 1 }
		for _ = 1, 2 do
			expect(EffectRules.matches(limited, event, buffs)).toBe(true)
			EffectRules.countFiring(limited, buffs)
		end
		expect(EffectRules.matches(limited, event, buffs)).toBe(false)
		EffectRules.startWave(buffs)
		expect(EffectRules.matches(limited, event, buffs)).toBe(true)
	end)

	it("rolls a chance once per copy and scales effects without a chance by the count", function()
		local adrenaline = entry({ trigger = "Dodge", action = "Heal", amount = 50, chance = 0.5 }, 3)
		expect(EffectRules.strength(adrenaline, sequence({ 0.1, 0.9, 0.4 }))).toBe(2)
		expect(EffectRules.strength(adrenaline, sequence({ 0.9 }))).toBe(0)
		local ring = entry({ trigger = "WaveEnd", action = "Grow", stats = { damage = 3 } }, 4)
		expect(EffectRules.strength(ring, sequence({ 0.99 }))).toBe(4)
	end)

	it("keeps wave stacks until the wave ends and timed stats until they run out", function()
		local buffs = EffectRules.newBuffs()
		local censer = entry({ trigger = "Timer", action = "WaveStats", interval = 5, stats = { hpRegen = 2 } })
		EffectRules.addWaveStats(buffs, censer, 1)
		EffectRules.addWaveStats(buffs, censer, 1)
		expect(EffectRules.buffSheet(buffs).hpRegen).toBe(4)
		local capped =
			entry({ trigger = "Kill", action = "WaveStats", maxStacks = 1, stats = { damage = 1 } }, 1, "Cap")
		expect(EffectRules.addWaveStats(buffs, capped, 2)).toBe(true)
		expect(EffectRules.addWaveStats(buffs, capped, 2)).toBe(false)
		expect(EffectRules.buffSheet(buffs).damage).toBe(2)

		local rush = entry({ trigger = "Crit", action = "TimedStats", seconds = 3, stats = { speed = 10 } }, 1, "Rush")
		EffectRules.addTimedStats(buffs, rush, 1, 100)
		EffectRules.addTimedStats(buffs, rush, 1, 102) -- refreshes, no second stack (maxStacks 1)
		expect(EffectRules.buffSheet(buffs).speed).toBe(10)
		expect(EffectRules.expire(buffs, 104)).toBe(false)
		expect(EffectRules.expire(buffs, 105)).toBe(true)
		expect(EffectRules.buffSheet(buffs).speed).toBe(nil)

		EffectRules.endWave(buffs)
		expect(EffectRules.buffSheet(buffs).hpRegen).toBe(nil)
	end)

	it("holds next-wave stats until the next wave starts and drops them when it ends", function()
		local buffs = EffectRules.newBuffs()
		local plume = entry(
			{ trigger = "Acquire", action = "NextWaveStats", stats = { xpGain = 100, enemyDamage = 50 } },
			1,
			"GildedPlume"
		)
		EffectRules.addNextWave(buffs, plume, 1)
		expect(EffectRules.buffSheet(buffs).xpGain).toBe(nil) -- bought in the shop: not yet
		EffectRules.startWave(buffs)
		expect(EffectRules.buffSheet(buffs).xpGain).toBe(100)
		expect(EffectRules.buffSheet(buffs).enemyDamage).toBe(50)
		local bonuses = EffectRules.activeBonuses({}, context(), buffs)
		expect(bonuses[1].kind).toBe("NextWave")
		EffectRules.endWave(buffs)
		EffectRules.startWave(buffs)
		expect(EffectRules.buffSheet(buffs).xpGain).toBe(nil)
	end)

	it("gives a share of the Shards, random stat points and compares sheets", function()
		local piggy = { trigger = "WaveStart", action = "ShardShare", amount = 20 }
		expect(EffectRules.shardShare(piggy, 99, 1)).toBe(19)
		expect(EffectRules.shardShare(piggy, -5, 1)).toBe(0)
		local capped = { trigger = "WaveStart", action = "ShardShare", amount = 50, max = 10 }
		expect(EffectRules.shardShare(capped, 100, 1)).toBe(10)

		local points = EffectRules.randomStats(8, sequence({ 0 }))
		expect(points.maxHp).toBe(8 * Config.Effects.randomPoint.maxHp) -- the first primary stat every time
		local spread = EffectRules.randomStats(8, sequence({ 0.99 }))
		local total = 0
		for id, value in spread do
			expect(Config.Stats.byId[id].primary).toBe(true)
			total += value
		end
		expect(total).toBe(8)

		expect(EffectRules.sameSheet({ armor = 1 }, { armor = 1, damage = 0 })).toBe(true)
		expect(EffectRules.sameSheet({ armor = 1 }, { armor = 2 })).toBe(false)
		expect(EffectRules.sameSheet({}, { luck = 3 })).toBe(false)
	end)
end)

describe("EffectText", function()
	it("writes one line per effect", function()
		expect(EffectText.line(Config.Items.byId.IronVigil.effects[1])).toBe("+8 Armor while standing still")
		expect(EffectText.line(Config.Items.byId.QuiltedCoat.effects[1])).toBe("+10 Max HP per 80 Shards")
		expect(EffectText.line(Config.Items.byId.EightEyedIdol.effects[1])).toBe(
			"+6% Attack Speed per different weapon"
		)
		expect(EffectText.line(Config.Items.byId.FortuneCoin.effects[1])).toBe("+2 Luck per 1% Crit Chance")
		expect(EffectText.line(Config.Items.byId.ClockworkArm.effects[1])).toBe("Wave end: -10 Max HP, +3 Melee Damage")
		expect(EffectText.line(Config.Items.byId.GildedPlume.effects[1])).toBe(
			"Next wave: +100% XP Gain, +50% Enemy Damage"
		)
		expect(EffectText.line(Config.Items.byId.PulseDraught.effects[1])).toBe("Dodge: heal 50 HP (50%)")
		expect(EffectText.line(Config.Items.byId.HuntersTally.effects[1])).toBe("Kill (crit): +1 Shard (33%)")
		expect(EffectText.line(Config.Items.byId.FieldCenser.effects[1])).toBe("Every 5s: +2 HP Regeneration this wave")
		expect(EffectText.line(Config.Items.byId.SmolderingWick.effects[1])).toBe(
			"Hit: burn 3x1 (+100% Elemental Damage) (25%)"
		)
		expect(EffectText.line(Config.Items.byId.BurstingSigil.effects[1])).toBe(
			"Kill: explode for 10 (+50% Melee Damage) (20%)"
		)
		expect(EffectText.line(Config.Items.byId.RecoilSpring.effects[1])).toBe("+1% Damage per 1 Knockback")
		expect(EffectText.line(Config.Items.byId.TitheBox.effects[1])).toBe(
			"Wave start: +20% of your Shards (until wave 19)"
		)
		expect(EffectText.line(Config.Items.byId.MossWard.effects[1])).toBe(
			"Wave start: the first hit taken deals no damage"
		)
		expect(EffectText.line(Config.Items.byId.EmberAnvil.effects[1])).toBe(
			"Shop: a random weapon +1 tier (none: +2 Armor)"
		)
	end)

	it("writes feedback and HUD texts", function()
		expect(EffectText.proc({ kind = "Heal", amount = 50 })).toBe("+50 HP")
		expect(EffectText.proc({ kind = "Shards", amount = 1 })).toBe("+1 Shard")
		expect(EffectText.proc({ kind = "Stats", stats = { damage = 3 } })).toBe("+3% Damage")
		expect(EffectText.proc({ kind = "Weapon", weaponId = "SparkBolt", tier = 2 })).toBe("Spark Bolt II!")
		expect(EffectText.procWithItem({ itemId = "OathRing", kind = "Stats", stats = { damage = 3 } })).toBe(
			"Oath Ring: +3% Damage"
		)
		expect(EffectText.bonus({ itemId = "IronVigil", kind = "Still", stats = { armor = 8 } })).toBe(
			"+8 Armor (standing still)"
		)
	end)

	it("has a text for every effect in the game", function()
		for _, item in Config.Items.list do
			for _, effect in item.effects or {} do
				local line = EffectText.line(effect)
				expect(line ~= "" and not string.find(line, "nil", 1, true)).toBe(true)
			end
		end
	end)
end)
