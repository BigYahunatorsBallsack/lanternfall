-- Unit tests for level-up stat cards (UpgradeService/UpgradePool: DESIGN.md section 9, Brotato direction since B2),
-- evolutions and the card, offer and chest texts (Util/UpgradeText).

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local UpgradeText = require(Shared.Util.UpgradeText)
local UpgradePool = require(game:GetService("ServerScriptService").Server.Services.UpgradeService.UpgradePool)

local function sequence(values)
	local index = 0
	return function()
		index = index % #values + 1
		return values[index]
	end
end

local function params(overrides)
	local p = {
		level = 2,
		luck = 0,
		cardCount = Config.Run.levelUp.cardCount,
		random = sequence({ 0.1, 0.5, 0.9, 0.3, 0.7 }),
	}
	for key, value in overrides or {} do
		p[key] = value
	end
	return p
end

describe("UpgradePool", function()
	it("deals four cards of different primary stats with their tier values", function()
		local cards = UpgradePool.roll(params())
		expect(#cards).toBe(4)
		local seen = {}
		for _, card in cards do
			expect(seen[card.stat]).toBe(nil)
			seen[card.stat] = true
			local stat = Config.Stats.byId[card.stat]
			expect(stat.primary).toBe(true)
			expect(card.amount).toBe(stat.upgrade[card.tier])
			expect(card.id).toBe(`Stat:{card.stat}:{card.tier}`)
			expect(#card.id <= 32).toBe(true)
		end
	end)

	it("only deals Common cards on the first levels", function()
		for seed = 1, 10 do
			local cards = UpgradePool.roll(params({ level = 1, random = sequence({ seed / 11, 0.01, 0.99 }) }))
			for _, card in cards do
				expect(card.tier).toBe(1)
			end
		end
	end)

	it("fixes the tier on Brotato's levels: 5 Uncommon, 10/15/20 Rare, from 25 every 5th Legendary", function()
		expect(UpgradePool.guaranteedTier(5)).toBe(2)
		expect(UpgradePool.guaranteedTier(10)).toBe(3)
		expect(UpgradePool.guaranteedTier(20)).toBe(3)
		expect(UpgradePool.guaranteedTier(25)).toBe(4)
		expect(UpgradePool.guaranteedTier(35)).toBe(4)
		expect(UpgradePool.guaranteedTier(26)).toBe(nil)
		expect(UpgradePool.guaranteedTier(7)).toBe(nil)
		for _, card in UpgradePool.roll(params({ level = 10 })) do
			expect(card.tier).toBe(3)
		end
	end)

	it("rolls rarer cards with a higher level and more Luck", function()
		local function rareShare(level, luck)
			local rare, total = 0, 0
			for step = 0, 199 do
				local cards = UpgradePool.roll(params({
					level = level,
					luck = luck,
					random = sequence({ (step % 20) / 20, ((step * 7) % 20) / 20 + 0.01 }),
				}))
				for _, card in cards do
					total += 1
					if card.tier >= 2 then
						rare += 1
					end
				end
			end
			return rare / total
		end
		expect(rareShare(3, 0) < rareShare(9, 0)).toBe(true)
		expect(rareShare(3, 0) < rareShare(3, 100)).toBe(true)
	end)

	it("deals other stats on a reroll while there are enough", function()
		local first = UpgradePool.roll(params())
		local avoid = {}
		for _, card in first do
			avoid[card.stat] = true
		end
		for _, card in UpgradePool.roll(params({ avoid = avoid })) do
			expect(avoid[card.stat]).toBe(nil)
		end
	end)
end)

describe("UpgradeText", function()
	it("describes stat cards", function()
		local title, detail, badge = UpgradeText.card(UpgradePool.card("damage", 2))
		expect(title).toBe("Damage")
		expect(detail).toBe("+8% Damage")
		expect(badge).toBe("Uncommon")
		_, detail = UpgradeText.card(UpgradePool.card("maxHp", 1))
		expect(detail).toBe("+30 Max HP")
	end)

	it("describes weapon and item offers", function()
		local title, detail, badge = UpgradeText.offer({
			id = "1:Weapon:SparkBolt",
			kind = "Weapon",
			itemId = "SparkBolt",
			tier = 1,
			level = 2,
			isNew = false,
			price = 10,
			sold = false,
		})
		expect(title).toBe("Spark Bolt")
		expect(detail).toBe("+1 bolt")
		expect(badge).toBe("LV 2")
		title, detail, badge = UpgradeText.offer({
			id = "2:Item:GlassLantern",
			kind = "Item",
			itemId = "GlassLantern",
			tier = 3,
			level = 3,
			isNew = false,
			price = 80,
			sold = false,
		})
		expect(title).toBe("Glass Lantern")
		expect(detail).toBe("+25% Damage\n-3 Armor")
		expect(badge).toBe("Rare · x2")
	end)

	it("colors stat lines as rich text", function()
		local text = UpgradeText.statLines({ armor = -1, damage = 5 }, {
			plus = { R = 0, G = 1, B = 0 } :: any, -- Color3 fields; the unit tests run without Roblox types
			minus = { R = 1, G = 0, B = 0 } :: any,
		})
		expect(text).toBe('<font color="#00FF00">+5% Damage</font>\n<font color="#FF0000">-1 Armor</font>')
	end)

	it("describes chest rewards", function()
		local title, detail = UpgradeText.chestReward({ kind = "Evolution", itemId = "Starfire", level = 0 })
		expect(title).toBe("Starfire")
		expect(detail).toBe("Spark Bolt evolved!")
		title, detail = UpgradeText.chestReward({ kind = "Item", itemId = "Might", level = 2 })
		expect(title).toBe("Might x2")
		expect(detail).toBe("-10 Max HP, +5% Damage") -- in the order of the stat panel
		title = UpgradeText.chestReward({ kind = "Reward", itemId = "Heal", level = 0 })
		expect(title).toBe("Heal")
	end)
end)

describe("evolutions", function()
	local max = Config.Player.maxItemLevel

	it("needs the weapon at max level, not evolved yet, plus at least one of the item", function()
		local evolutionsFor = UpgradePool.evolutionsFor
		local blades = { OrbitBlades = { level = max } }
		expect(#evolutionsFor(blades, {}, max)).toBe(0)
		expect(#evolutionsFor({ OrbitBlades = { level = max - 1 } }, { Armor = 5 }, max)).toBe(0)
		expect(table.concat(evolutionsFor(blades, { Armor = 1 }, max), ",")).toBe("BladeStorm")
		expect(#evolutionsFor({ OrbitBlades = { level = max, evolution = "BladeStorm" } }, { Armor = 1 }, max)).toBe(0)
		local both = { OrbitBlades = { level = max }, SparkBolt = { level = max } }
		expect(table.concat(evolutionsFor(both, { Armor = 1, Focus = 2 }, max), ",")).toBe("BladeStorm,Starfire")
	end)
end)
