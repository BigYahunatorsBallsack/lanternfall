--!strict
-- Native hitbox classification at the real BrotatoCombat boundary; no damage engine substitutions.
local S = game:GetService("ServerScriptService").Server.Services.WeaponService
local Combat = require(S.BrotatoCombat)
local function hit(scaling, secondary)
	local seen = {}
	local weapon = {
		ownerId = 1,
		tier = 1,
		config = { scaling = scaling },
		stats = { damage = 1, critChance = 0, explosionRadius = 1 },
		state = {},
	}
	local context = {
		x = 0,
		z = 0,
		random = function()
			return 1
		end,
		enemyPosition = function()
			return 0, 0
		end,
		hit = function()
			table.insert(seen, Combat.elementalHit(1))
			expect(Combat.elementalHit(2)).toBe(nil)
			return false
		end,
		explode = function()
			table.insert(seen, Combat.elementalHit(1))
		end,
	}
	Combat.hit(weapon, context, 1, nil, nil, nil, secondary)
	expect(Combat.elementalHit(1)).toBe(nil)
	return seen
end
describe("Native hitbox classification", function()
	it("covers direct and explosion hits with no Elemental scaling", function()
		local seen = hit({ meleeDamage = 1 })
		expect(#seen).toBe(2)
		expect(seen[1]).toBe(false)
		expect(seen[2]).toBe(false)
	end)
	it("treats even a zero-share Elemental entry as elemental", function()
		local seen = hit({ meleeDamage = 1, elementalDamage = 0 })
		expect(seen[1]).toBe(true)
		expect(seen[2]).toBe(true)
	end)
	it("clears failed native hitbox context before the next simulation step", function()
		local weapon =
			{ ownerId = 1, tier = 1, config = { scaling = {} }, stats = { damage = 1, critChance = 0 }, state = {} }
		local ok = pcall(function()
			Combat.hit(weapon, {
				random = function()
					return 1
				end,
				enemyPosition = function()
					return 0, 0
				end,
				hit = function()
					error("Fixture")
				end,
			}, 1)
		end)
		expect(ok).toBe(false)
		Combat.resetHitContext()
		expect(Combat.elementalHit(1)).toBe(nil)
	end)
end)
