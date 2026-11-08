--!strict
-- Native Bull explosion arithmetic and scene geometry, separate from the older item-explosion formula.
local Shared = game:GetService("ReplicatedStorage").Shared
local Definitions = require(Shared.Config.CharacterExplosions)
local Explosion = require(game:GetService("ServerScriptService").Server.Services.WeaponService.CharacterExplosion)
local bull = Definitions.bySource["res://items/characters/bull/bull_explosion_stats.tres"]

describe("Native character explosion calculation", function()
	it("keeps Bull's original base, triple flat scaling and own critical multiplier", function()
		local base = Explosion.compute(bull, {})
		expect(base.damage).toBe(30)
		expect(base.critChance).toBeNear(0.03)
		expect(Explosion.hitDamage(base, true, 0)).toBe(45)
		local scaled = Explosion.compute(bull, { meleeDamage = 2, rangedDamage = 4, elementalDamage = 5 })
		expect(scaled.damage).toBe(63)
	end)
	it("adds Damage and Explosion Damage before multiplying, after truncating flat scaling", function()
		expect(Explosion.compute(bull, {
			meleeDamage = 2,
			rangedDamage = 4,
			elementalDamage = 5,
			damage = 20,
			explosionDamage = 50,
		}).damage).toBe(107)
		expect(Explosion.compute(bull, { meleeDamage = 1.25, damage = 50 }).damage).toBe(50)
		expect(Explosion.compute(bull, { damage = -200 }).damage).toBe(1)
	end)
	it("uses the native collision radius, offset and minimum area scale", function()
		local base = Explosion.compute(bull, {})
		expect(base.radius).toBeNear(14.734)
		expect(base.offsetZ).toBeNear(0.3)
		expect(Explosion.compute(bull, { explosionSize = 100 }).radius).toBeNear(29.468)
		expect(Explosion.compute(bull, { explosionSize = -200 }).radius).toBeNear(1.4734)
	end)
	it("rounds critical damage before target bonuses and accepts critical modifiers", function()
		local stats = Explosion.compute(bull, { critChance = 100, critDamage = 50 })
		expect(stats.critChance).toBe(1)
		expect(Explosion.hitDamage(stats, true, 50)).toBe(90)
	end)
end)
