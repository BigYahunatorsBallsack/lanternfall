--!strict
-- Native explosive weapon bonuses are additive before minimum damage and rounding, including Tool-local bonuses.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Services = game:GetService("ServerScriptService").Server.Services
local Rules = require(Shared.Util.CharacterRules)
local Compute = require(Services.WeaponService.WeaponStats).compute
local Preview = require(folderProxy("src/client", "Client").UI.OfferText)
describe("Artificer explosion damage", function()
	it("adds Damage and Explosion Damage before clamping instead of multiplying a minimum hit", function()
		local sheet = Rules.weaponSheet("Artificer", { damage = -100, explosionDamage = 175 })
		for _, id in { "Plank", "ShrapnelOrgan" } do
			local plain = Compute(Config.Weapons[id], 1, { critChance = -100 }, nil, Config.Player.minWeaponCooldown)
			local actual = Compute(Config.Weapons[id], 1, sheet, nil, Config.Player.minWeaponCooldown)
			local factor = 1.75
			expect(actual.damage).toBe(math.round(plain.damage * factor))
			expect(actual.explosionDamage).toBe(1)
			expect(Preview.stats(id, 1, sheet).damage).toBe(actual.damage)
		end
	end)
	it("keeps the Tool class bonus local to its actual weapon set", function()
		local sheet = Rules.weaponSheet("Artificer", { damage = -100, explosionDamage = 175 })
		local plain = Compute(Config.Weapons.RuneAwl, 1, {}, nil, Config.Player.minWeaponCooldown)
		expect(Compute(Config.Weapons.RuneAwl, 1, sheet, nil, Config.Player.minWeaponCooldown).damage).toBe(
			plain.damage
		)
	end)
	it("does not turn very negative Damage into a positive explosion bonus", function()
		local stats = Compute(
			Config.Weapons.Plank,
			1,
			{ damage = -400, explosionDamage = 175 },
			nil,
			Config.Player.minWeaponCooldown
		)
		expect(stats.damage).toBe(1)
	end)
	it("retains the native minimum blast area with very negative Elemental-linked Size", function()
		local base = Compute(Config.Weapons.StickyGrenade, 1, {}, nil, Config.Player.minWeaponCooldown)
		local stats =
			Compute(Config.Weapons.StickyGrenade, 1, { explosionSize = -200 }, nil, Config.Player.minWeaponCooldown)
		expect(stats.explosionRadius).toBeNear(base.explosionRadius * 0.1)
	end)
end)
