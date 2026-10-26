-- Unit tests for player HP, armor, hit protection and dash rules (src/server/Services/CombatService/Vitals.luau).
-- Run: see README "Für Entwickler".

local ServerScriptService = game:GetService("ServerScriptService")
local Vitals = require(ServerScriptService.Server.Services.CombatService.Vitals)

local SETTINGS = {
	armor = 0,
	minDamagePerHit = 1,
	hitInvulnerability = 0.5,
	dashCooldown = 6,
	dashInvulnerability = 0.3,
	dashCooldownTolerance = 0.25,
}

local function withArmor(armor)
	local settings = table.clone(SETTINGS)
	settings.armor = armor
	return settings
end

describe("Vitals", function()
	it("starts at full HP", function()
		local v = Vitals.new(120, SETTINGS)
		expect(v.hp).toBe(120)
		expect(v:isDown()).toBe(false)
	end)

	it("protects for a moment after a hit", function()
		local v = Vitals.new(100, SETTINGS)
		expect(v:hit(5, 10)).toBe(5)
		expect(v:hit(5, 10.4)).toBe(0)
		expect(v.hp).toBe(95)
		expect(v:hit(5, 10.5)).toBe(5)
		expect(v.hp).toBe(90)
	end)

	it("subtracts armor but always deals at least 1", function()
		local v = Vitals.new(100, withArmor(3))
		expect(v:hit(5, 0)).toBe(2)
		expect(v:hit(2, 1)).toBe(1)
		expect(v.hp).toBe(97)
	end)

	it("goes down at 0 HP and ignores further hits and heals", function()
		local v = Vitals.new(10, SETTINGS)
		expect(v:hit(25, 0)).toBe(10)
		expect(v.hp).toBe(0)
		expect(v:isDown()).toBe(true)
		expect(v:hit(5, 5)).toBe(0)
		expect(v:heal(50)).toBe(0)
	end)

	it("heals up to the maximum", function()
		local v = Vitals.new(100, SETTINGS)
		v:hit(30, 0)
		expect(v:heal(20)).toBe(20)
		expect(v:heal(50)).toBe(10)
		expect(v.hp).toBe(100)
	end)

	it("revives with a fraction of the maximum", function()
		local v = Vitals.new(120, SETTINGS)
		v:knockDown()
		v:setFraction(0.4)
		expect(v.hp).toBe(48)
		expect(v:isDown()).toBe(false)
	end)

	it("dashes with a cooldown and short invulnerability", function()
		local v = Vitals.new(100, SETTINGS)
		expect(v:dash(10)).toBe(true)
		expect(v.dashReadyAt).toBe(16)
		expect(v:isInvulnerable(10.2)).toBe(true)
		expect(v:hit(5, 10.2)).toBe(0)
		expect(v:isInvulnerable(10.3)).toBe(false)
		local ok, reason = v:dash(12)
		expect(ok).toBe(false)
		expect(reason).toBe("Cooldown")
		expect(v:dash(15.8)).toBe(true) -- within the ping tolerance
	end)

	it("cannot dash while down", function()
		local v = Vitals.new(100, SETTINGS)
		v:knockDown()
		local ok, reason = v:dash(0)
		expect(ok).toBe(false)
		expect(reason).toBe("Down")
	end)

	it("never shortens an existing protection", function()
		local v = Vitals.new(100, SETTINGS)
		v:protect(0, 10)
		v:hit(5, 1) -- protected, no new window
		v:dash(2)
		expect(v.invulnerableUntil).toBe(10)
	end)

	it("resets for a new run", function()
		local v = Vitals.new(100, SETTINGS)
		v:hit(50, 0)
		v:dash(0)
		v:reset(120)
		expect(v.hp).toBe(120)
		expect(v.maxHp).toBe(120)
		expect(v.dashReadyAt).toBe(0)
		expect(v:isInvulnerable(0)).toBe(false)
	end)

	it("shields while choosing and leaves a short protection afterwards", function()
		local v = Vitals.new(100, SETTINGS)
		v:setShielded(true, 0, 0.5)
		expect(v:hit(30, 100)).toBe(0)
		v:setShielded(false, 100, 0.5)
		expect(v:hit(30, 100.4)).toBe(0)
		expect(v:hit(30, 100.6)).toBe(30)
		v:setShielded(true, 0, 0.5)
		v:reset(100)
		expect(v.shielded).toBe(false)
	end)

	it("adds a higher maximum to the current HP and caps at a lower one", function()
		local v = Vitals.new(100, SETTINGS)
		v:hit(40, 0)
		v:setMaxHp(115)
		expect(v.hp).toBe(75)
		expect(v.maxHp).toBe(115)
		v:setMaxHp(50)
		expect(v.hp).toBe(50)
		v:knockDown()
		v:setMaxHp(200)
		expect(v.hp).toBe(0)
	end)

	it("takes armor bonuses on top of the base armor, back to base on reset", function()
		local v = Vitals.new(100, withArmor(1))
		v:setArmorBonus(2)
		expect(v:hit(10, 0)).toBe(7)
		v:reset(100)
		expect(v:hit(10, 10)).toBe(9)
	end)
end)
