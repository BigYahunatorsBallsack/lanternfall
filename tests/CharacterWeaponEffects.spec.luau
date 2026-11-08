--!strict
-- Stable Spoon/Cestus/Sickle/Trident effects at the real shared combat boundary.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.WeaponService
local Compute, Combat = require(S.WeaponStats).compute, require(S.BrotatoCombat)
local burning, healthShare = false, 1
Combat.configure({
	isBurning = function()
		return burning
	end,
	healthShare = function()
		return healthShare
	end,
})
local function stats(id, tier, sheet)
	return Compute(Config.Weapons[id], tier, sheet or {}, nil, Config.Player.minWeaponCooldown)
end
local function hit(id, tier)
	local weapon =
		{ id = id, ownerId = 1, tier = tier, config = Config.Weapons[id], state = {}, stats = stats(id, tier) }
	local seen
	local ctx = {
		x = 0,
		z = 0,
		random = function()
			return 1
		end,
		enemyPosition = function()
			return 0, 0
		end,
		hit = function()
			seen = { crit = weapon.stats.critChance, bonus = Combat.targetBonus(1, 1) }
			return false
		end,
	}
	Combat.hit(weapon, ctx, 1, nil, nil, false)
	return seen
end
describe("Native conditional starting-weapon effects", function()
	it("doubles only Cestus base at ten player Knockback, before flat scaling and Damage", function()
		expect(stats("Cestus", 2, { knockback = 9, meleeDamage = 10 }).damage).toBe(35)
		expect(stats("Cestus", 2, { knockback = 10, meleeDamage = 10 }).damage).toBe(60)
		expect(stats("Cestus", 2, { knockback = 10, meleeDamage = 10, damage = 50 }).damage).toBe(90)
		expect(stats("Sickle", 1, { meleeDamage = 1, harvesting = 1, damage = 50 }).damage).toBe(8)
	end)
	it("forces Spoon critical hits only against already-burning targets", function()
		burning = false
		expect(hit("Spoon", 1).crit).toBe(0)
		burning = true
		expect(hit("Spoon", 1).crit).toBe(1)
		burning = false
	end)
	it("uses inclusive Sickle and Trident HP thresholds for their own target", function()
		healthShare = 0.3
		expect(hit("Sickle", 1).bonus).toBe(20)
		healthShare = 0.30001
		expect(hit("Sickle", 1).bonus).toBe(0)
		healthShare = 0.8
		expect(hit("Trident", 2).bonus).toBe(30)
		healthShare = 0.79999
		expect(hit("Trident", 2).bonus).toBe(0)
	end)
	it("shows the selected tier's actual effect values and conditional Cestus preview", function()
		local Preview = require(folderProxy("src/client", "Client").UI.OfferText)
		local _, low = Preview.weapon("Sickle", 1, {})
		local _, high = Preview.weapon("Sickle", 4, {})
		expect(low:find("+20%% damage") ~= nil).toBe(true)
		expect(high:find("+50%% damage") ~= nil).toBe(true)
		local _, lute = Preview.weapon("Lute", 4, {})
		expect(lute:find("max: 100%%") ~= nil).toBe(true)
		expect(Preview.stats("Cestus", 2, { knockback = 10, meleeDamage = 10, damage = 50 }).damage).toBe(90)
	end)
end)
