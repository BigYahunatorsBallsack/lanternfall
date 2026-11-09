--!strict
-- Native weighted Carbon Bow variants retain the prepared arrow across stat changes and scale each projectile independently.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local W = game:GetService("ServerScriptService").Server.Services.WeaponService
local Carbon = require(W.CarbonArrows)
local function weapon(sheet, tier)
	local config = Config.Weapons.CarbonBow
	return {
		id = "CarbonBow",
		config = config,
		tier = tier or 1,
		state = {},
		stats = require(W.WeaponStats).compute(config, tier or 1, sheet, nil, 0),
	}
end
describe("Native Carbon arrows", function()
	it("uses positive stat weights and uniformly chooses when all four stats are nonpositive", function()
		local w = weapon({ meleeDamage = -100, rangedDamage = 10, elementalDamage = 0, engineering = -20 })
		for _, roll in { 0, 0.2, 0.9 } do
			expect(Carbon.pick(w.stats, function()
				return roll
			end)).toBe(2)
		end
		local empty = weapon({})
		for i, roll in { 0, 0.25, 0.5, 0.75 } do
			expect(Carbon.pick(empty.stats, function()
				return roll
			end)).toBe(i)
		end
	end)
	it("keeps the primed variant when stats change, then prepares the next projectile with the new weights", function()
		local w = weapon({ rangedDamage = 10 })
		Carbon.initialise(w, function()
			return 0.5
		end)
		w.stats = weapon({ meleeDamage = 20 }).stats
		local shot = Carbon.take(w, w.stats, function()
			return 0.5
		end)
		expect(shot.damage).toBe(7)
		expect(shot.pierce).toBe(1)
		expect(w.state.nextCarbon).toBe(1)
		local nextShot = Carbon.take(w, w.stats, function()
			return 0.5
		end)
		expect(nextShot.damage).toBe(19)
		expect(nextShot.carbonMeleeSlow).toBe(50)
	end)
	it("applies all four source tier effects without leaking a previous arrow's properties", function()
		for tier = 1, 4 do
			local w = weapon({ elementalDamage = 5 }, tier)
			for variant = 1, 4 do
				w.state.nextCarbon = variant
				local shot = Carbon.take(w, w.stats, function()
					return 0
				end)
				if variant == 1 then
					expect(shot.carbonSlowSeconds).toBe(0.5 * tier)
				elseif variant == 2 then
					expect(shot.pierce).toBe(if tier <= 2 then 1 else 2)
				elseif variant == 3 then
					expect(shot.burnDamage).toBe(({ 3, 5, 8, 12 })[tier] + 5)
				elseif variant == 4 then
					expect(shot.nativeMineChance).toBe((tier + 1) / 100)
				end
				if variant ~= 3 then
					expect(shot.burnDamage).toBe(nil)
				end
			end
		end
	end)
end)
