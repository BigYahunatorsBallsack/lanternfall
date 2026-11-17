--!strict
-- Source hurtbox origin changes precede lethal damage; unrecognized sources preserve the prior death-shot flag.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services
local Death = require(S.EnemySim.NativeDeathShots)
local Combat = require(S.WeaponService.BrotatoCombat)
describe("Native death shot origin", function()
	it("starts enabled and follows Ranged, Melee and the Pet shoot_projectiles flag", function()
		local state = Death.new()
		expect(state.enabled).toBe(true)
		Death.hurt(state, "Melee")
		expect(state.enabled).toBe(false)
		Death.hurt(state, "Ranged")
		expect(state.enabled).toBe(true)
		Death.hurt(state, "Pet", 0)
		expect(state.enabled).toBe(false)
		Death.hurt(state, "Pet", 1)
		expect(state.enabled).toBe(true)
	end)
	it("keeps the prior flag for explosions, structures, burn and stat damage", function()
		for _, initial in { true, false } do
			local state = Death.new()
			state.enabled = initial
			for _, kind in { "Explosion", "Structure", "Burn", "Stat", "Enemy" } do
				Death.hurt(state, kind)
			end
			expect(state.enabled).toBe(initial)
		end
	end)
	it("requires strictly more than the configured remaining time and excludes cleanup", function()
		local state = Death.new()
		expect(Death.allowed(state, 0.5001, false, 0.5)).toBe(true)
		expect(Death.allowed(state, 0.5, false, 0.5)).toBe(false)
		expect(Death.allowed(state, 4, true, 0.5)).toBe(false)
		Death.hurt(state, "Melee")
		expect(Death.allowed(state, 4, false, 0.5)).toBe(false)
	end)
	it("calls the origin adapter before Charm or lethal damage, with the captured Pet flag", function()
		local state = Death.new()
		local sequence = {}
		Combat.configure({
			hurtContact = function(id, kind, pet)
				expect(id).toBe(27)
				Death.hurt(state, kind, pet)
				table.insert(sequence, "origin")
			end,
			tryCharm = function()
				table.insert(sequence, "charm")
				return false
			end,
		})
		local weapon = {
			ownerId = 1,
			id = "probe",
			state = {},
			config = { kind = "Pet", scaling = {} },
			stats = { critChance = 0, charmChance = 1, petSourceShootsProjectiles = 1 },
		}
		local ctx = {
			random = function()
				return 0.9
			end,
			enemyPosition = function()
				return 0, 0
			end,
			hit = function()
				expect(state.enabled).toBe(false)
				table.insert(sequence, "damage")
				return true
			end,
		}
		Combat.hit(weapon, ctx, 27, nil, { critChance = 0, charmChance = 1, petSourceShootsProjectiles = 0 })
		expect(table.concat(sequence, ",")).toBe("origin,charm,damage")
		Combat.configure({})
	end)
	it("does not relabel an explosion as the weapon which created it", function()
		local origins = 0
		Combat.configure({
			hurtContact = function()
				origins += 1
			end,
		})
		local w = { ownerId = 1, stats = { explosionRadius = 5 }, config = { scaling = {} } }
		local ctx = {
			queryCircle = function(_, _, _, _, ids)
				ids[1] = 27
				return 1
			end,
			emit = function() end,
			hit = function()
				return false
			end,
		}
		Combat.explode(w, ctx, 0, 0)
		expect(origins).toBe(0)
		Combat.configure({})
	end)
end)
