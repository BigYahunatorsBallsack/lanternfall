--!strict
-- Carbon Bow variants travel and hit through the production projectile and combat modules.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local W = game:GetService("ServerScriptService").Server.Services.WeaponService
local Stats = require(W.WeaponStats)
local Projectile = require(W.BrotatoProjectile)
local Combat = require(W.BrotatoCombat)
local Preview = require(folderProxy("src/client/UI", "UI").OfferText)
describe("Carbon projectile integration", function()
	it("applies source accuracy and extra-projectile spread to native ranged stats and preview", function()
		local bonuses = { accuracy = -50, projectiles = 2, piercing = 1 }
		local stats = Stats.compute(Config.Weapons.CarbonBow, 1, bonuses, nil, 0)
		local preview = Preview.stats("CarbonBow", 1, bonuses)
		expect(stats.nativeAccuracy).toBe(0.5)
		expect(stats.count).toBe(3)
		expect(stats.nativeSpread).toBe(0.2)
		expect(stats.pierce).toBe(1)
		for _, key in { "nativeAccuracy", "count", "nativeSpread" } do
			expect(preview[key]).toBe(stats[key])
		end
	end)
	it("scales each variant and resolves its slow, piercing, burning or mine effect at the hit position", function()
		local slows, mines = {}, {}
		Combat.configure({
			nativeSlow = function(...)
				table.insert(slows, { ... })
			end,
			spawnMine = function(...)
				table.insert(mines, { ... })
			end,
		})
		for variant = 1, 4 do
			local stats = Stats.compute(
				Config.Weapons.CarbonBow,
				4,
				{ meleeDamage = 10, rangedDamage = 20, elementalDamage = 30, engineering = 40 },
				nil,
				0
			)
			local weapon = {
				id = "CarbonBow",
				uid = 1,
				ownerId = 17,
				tier = 4,
				config = Config.Weapons.CarbonBow,
				state = { nextCarbon = variant },
				stats = stats,
			}
			local hits = {}
			local serial = 0
			local ctx = {
				x = 0,
				z = 0,
				now = 0,
				active = false,
				random = function()
					return 0
				end,
				nextId = function()
					serial += 1
					return serial
				end,
				emit = function() end,
				bounceTarget = function()
					return nil
				end,
				enemyPosition = function(_, id)
					return 5 + id, 0
				end,
				querySegment = function(_, _, _, _, _, _, out)
					out[1] = 1
					out[2] = 2
					return 2
				end,
				hit = function(_, w, id)
					table.insert(hits, { id = id, damage = w.stats.damage, burn = w.stats.burnDamage })
					return false
				end,
			}
			Projectile.launch(weapon, ctx, 0, 0, 1, 0, stats)
			Projectile.step(weapon, ctx, 0.1)
			expect(hits[1].damage).toBe(({ 23, 33, 43, 53 })[variant])
			expect(#hits).toBe(if variant == 2 then 2 else 1)
			if variant == 3 then
				expect(hits[1].burn).toBe(42)
			end
		end
		expect(#slows).toBe(1)
		expect(slows[1][2]).toBe(-50)
		expect(slows[1][3]).toBe(true)
		expect(slows[1][4]).toBe(2)
		expect(#mines).toBe(1)
		expect(mines[1][1]).toBe(17)
		expect(mines[1][2]).toBe(6)
		expect(mines[1][3]).toBe(0)
	end)
end)
