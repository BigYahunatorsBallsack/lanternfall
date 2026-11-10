--!strict
-- Native Brick's exact tiers and break effect are separate from hit damage and never emit duplicate break requests.
loadHelper("tests/helpers/RobloxMock.luau")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.WeaponService
local Combat = require(S.BrotatoCombat)
local Compute = require(S.WeaponStats).compute
describe("Native Brick", function()
	it("preserves original tier damage, half/full stat scaling and break material amounts", function()
		for tier, amount in { 10, 30, 75, 200 } do
			local stats = Compute(Config.Weapons.Brick, tier, {}, nil, Config.Player.minWeaponCooldown)
			expect(stats.breakMaterials).toBe(amount)
			expect(stats.damage).toBe(tier * 30)
			expect(stats.breakChance).toBe(0.01)
		end
		expect(Config.Weapons.Brick.available).toBe(false)
	end)
	it("rolls break after damage, stops later hits and issues one break request", function()
		local calls, hits = 0, 0
		Combat.configure({
			breakWeapon = function()
				calls += 1
			end,
		})
		local w = {
			id = "Brick",
			ownerId = 1,
			tier = 1,
			config = Config.Weapons.Brick,
			state = {},
			stats = Compute(Config.Weapons.Brick, 1, {}, nil, Config.Player.minWeaponCooldown),
		}
		local ctx = {
			x = 0,
			z = 0,
			slot = 1,
			slotCount = 1,
			random = function()
				return 0.01
			end,
			enemyPosition = function()
				return 2, 0
			end,
			hit = function()
				hits += 1
				return false
			end,
		}
		Combat.hit(w, ctx, 1)
		Combat.hit(w, ctx, 2)
		expect(calls).toBe(1)
		expect(hits).toBe(1)
	end)
	it("keeps the weapon just above the native threshold and never breaks at zero chance", function()
		local calls = 0
		Combat.configure({
			breakWeapon = function()
				calls += 1
			end,
		})
		local w = {
			id = "Brick",
			ownerId = 1,
			tier = 1,
			config = Config.Weapons.Brick,
			state = {},
			stats = Compute(Config.Weapons.Brick, 1, {}, nil, Config.Player.minWeaponCooldown),
		}
		local roll = 0.010001
		local ctx = {
			x = 0,
			z = 0,
			slot = 1,
			slotCount = 1,
			random = function()
				return roll
			end,
			enemyPosition = function()
				return 2, 0
			end,
			hit = function()
				return false
			end,
		}
		Combat.hit(w, ctx, 1)
		expect(calls).toBe(0)
		w.stats.breakChance = 0
		roll = 0
		Combat.hit(w, ctx, 1)
		expect(calls).toBe(0)
	end)
end)
