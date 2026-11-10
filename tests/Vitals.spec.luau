-- Unit tests for player HP, armor, dodge and hit protection (src/server/Services/CombatService/Vitals.luau).
-- Run: see README "Für Entwickler".

local ServerScriptService = game:GetService("ServerScriptService")
local Vitals = require(ServerScriptService.Server.Services.CombatService.Vitals)

local SETTINGS = {
	minDamagePerHit = 1,
	hitInvulnerabilityMin = 0.5,
	hitInvulnerabilityMax = 0.5,
}

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

	it("protects 0.2-0.4 s after a hit, the maximum from 15 % of max HP (Brotato Player.get_iframes)", function()
		local settings = {
			minDamagePerHit = 1,
			hitInvulnerabilityMin = 0.2,
			hitInvulnerabilityMax = 0.4,
			hitInvulnerabilityFullShare = 0.15,
		}
		expect(Vitals.protectionAfterHit(settings, 0, 100)).toBeNear(0.2, 1e-9)
		expect(Vitals.protectionAfterHit(settings, 6, 100)).toBeNear(0.2, 1e-9) -- 6 % x 0.4 / 0.15 = 0.16 -> min
		expect(Vitals.protectionAfterHit(settings, 10, 100)).toBeNear(0.4 * 0.1 / 0.15, 1e-9)
		expect(Vitals.protectionAfterHit(settings, 15, 100)).toBeNear(0.4, 1e-9)
		expect(Vitals.protectionAfterHit(settings, 50, 100)).toBeNear(0.4, 1e-9)
		local v = Vitals.new(100, settings)
		expect(v:hit(10, 0)).toBe(10) -- 10 % of max HP: 0.267 s
		expect(v.invulnerableUntil).toBeNear(0.4 * 0.1 / 0.15, 1e-9)
		expect(v:hit(1, 0.26)).toBe(0)
		expect(v:hit(1, 0.27)).toBe(1)
		v.protectionDivisor = 2 -- endless factor
		v:hit(50, 1)
		expect(v.invulnerableUntil).toBeNear(1.2, 1e-9)
	end)

	it("takes the armor share of the damage but always at least 1", function()
		local v = Vitals.new(100, SETTINGS)
		v:setDefense(0.5, 0)
		expect(v:hit(10, 0)).toBe(5)
		expect(v:hit(1, 1)).toBe(1)
		expect(v.hp).toBe(94)
	end)

	it("dodges a hit when the roll is below the dodge chance, with the minimum protection afterwards", function()
		local v = Vitals.new(100, SETTINGS)
		v:setDefense(1, 0.3)
		local taken, dodged = v:hit(10, 0, 0.29)
		expect(taken).toBe(0)
		expect(dodged).toBe(true)
		expect(v:hit(10, 0.1, 0.3)).toBe(0) -- Brotato: a dodge also starts the protection (min 0.5 s here)
		taken, dodged = v:hit(10, 0.6, 0.3)
		expect(taken).toBe(10)
		expect(dodged).toBe(false)
		expect(v:hit(10, 10)).toBe(10) -- no roll: never dodged
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

	it("never shortens an existing protection", function()
		local v = Vitals.new(100, SETTINGS)
		v:protect(0, 10)
		v:hit(5, 1) -- protected, no new window
		expect(v.invulnerableUntil).toBe(10)
	end)

	it("resets for a new run", function()
		local v = Vitals.new(100, SETTINGS)
		v:hit(50, 0)
		v:reset(120)
		expect(v.hp).toBe(120)
		expect(v.maxHp).toBe(120)
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

	it("lets a hit shield take a whole hit with the minimum protection afterwards, after dodging", function()
		local v = Vitals.new(100, SETTINGS)
		v:setHitShields(1)
		local taken, dodged, blocked = v:hit(30, 0, 0.5)
		expect(taken).toBe(0)
		expect(dodged).toBe(false)
		expect(blocked).toBe(true)
		expect(v:isInvulnerable(0.01)).toBe(true) -- Brotato: protected hits start the minimum protection too
		taken, dodged, blocked = v:hit(30, 0.6, 0.5)
		expect(taken).toBe(30)
		expect(blocked).toBe(false)
		v:setDefense(1, 0.5)
		v:setHitShields(1)
		taken, dodged, blocked = v:hit(30, 10, 0.1) -- dodged: the shield stays
		expect(dodged).toBe(true)
		expect(v.hitShields).toBe(1)
		v:reset(100)
		expect(v.hitShields).toBe(0)
	end)

	it("keeps its defense when reset for a new run", function()
		local v = Vitals.new(100, SETTINGS)
		v:setDefense(0.75, 0)
		v:reset(120)
		expect(v.hp).toBe(120)
		expect(v:hit(20, 0)).toBe(15)
	end)
end)
