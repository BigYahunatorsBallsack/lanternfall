--!strict
-- Weapon-local class bonuses must affect only matching weapons and preserve native units.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Stats = require(game:GetService("ServerScriptService").Server.Services.WeaponService.WeaponStats)

local function compute(id, sheet)
	return Stats.compute(Config.Weapons[id], 1, sheet, nil, Config.Player.minWeaponCooldown)
end

describe("Character weapon-local bonuses", function()
	it("applies Brawler attack speed only to unarmed weapons", function()
		local sheet = { ["class.Brawl.attackSpeed"] = 50 }
		local fist = compute("BrassKnuckles", {})
		expect(compute("BrassKnuckles", sheet).cooldown).toBe(fist.cooldown / 1.5)
		expect(compute("RitualDirk", sheet).cooldown).toBe(compute("RitualDirk", {}).cooldown)
		expect(sheet.attackSpeed).toBe(nil)
	end)

	it("adds Ghost's flat damage before percent damage", function()
		local plain = compute("SpiritFlint", { damage = 50 })
		local ghost = compute("SpiritFlint", { damage = 50, ["class.Spectral.baseDamage"] = 10 })
		expect(ghost.damage).toBe(plain.damage + 15)
	end)

	it("adds precise weapon range in full weapon units instead of halving it as ordinary melee range", function()
		local plain = compute("RitualDirk", {})
		local crazy = compute("RitualDirk", { ["class.Keen.weaponRange"] = 100 })
		expect(crazy.range).toBe(plain.range + 100 * Config.Stats.range.studsPerPoint)
	end)

	it("keeps critical multiplier, weapon kind and life-steal bonuses local", function()
		local plain = compute("RitualDirk", {})
		local special = compute("RitualDirk", {
			["class.Keen.critDamage"] = 200,
			["kind.Melee.lifeSteal"] = 30,
		})
		expect(special.critDamage).toBe(plain.critDamage + 2)
		expect(special.lifeSteal).toBe(plain.lifeSteal + 0.3)
		expect(compute("WatchmanPistol", { ["kind.Melee.lifeSteal"] = 30 }).lifeSteal).toBe(0)
	end)
end)
