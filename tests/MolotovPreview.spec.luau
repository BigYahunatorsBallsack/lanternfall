--!strict
-- Native burn rounding and extreme modifiers agree in the server and the owner's read-only offer preview.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server.Services.WeaponService
local Compute = require(Server.WeaponStats).compute
local Preview = require(folderProxy("src/client", "Client").UI.OfferText)
describe("Molotov native burn and preview", function()
	it("truncates the combined flat burn before rounding percent damage and keeps a one-damage minimum", function()
		for _, sheet in
			{ { elementalDamage = 1.5, damage = 50 }, { elementalDamage = -20, damage = 50 }, { damage = -1000 } }
		do
			local expected = if sheet.elementalDamage == 1.5 then 6 elseif sheet.elementalDamage == -20 then 2 else 1
			local stats = Compute(Config.Weapons.Molotov, 1, sheet, nil, 0)
			expect(stats.burnDamage).toBe(expected)
			expect(Preview.stats("Molotov", 1, sheet).burnDamage).toBe(expected)
		end
	end)
	it("retains the native one-tenth-second burn minimum without allowing a negative puddle size", function()
		local stats = Compute(Config.Weapons.Molotov, 1, { burnSpeed = 500, firePuddleSize = -1000 }, nil, 0)
		expect(stats.burnInterval).toBe(0.1)
		expect(stats.puddleRadius).toBeNear(0.56)
		expect(Preview.stats("Molotov", 1, { firePuddleSize = -1000 }).puddleRadius).toBeNear(stats.puddleRadius)
	end)
	it("passes the new shared cosmetic kind through the existing binary effect format", function()
		local fx = require(Shared.Net.WeaponFx)
		local packet = fx.encode({
			{ kind = "Puddle", weapon = "FirePuddle", userId = 1, at = 10, x = 4, z = 5, radius = 5.6, duration = 3 },
		})
		local result = fx.decodeShared(packet)[1]
		expect(result.kind).toBe("Puddle")
		expect(result.weapon).toBe("FirePuddle")
		expect(result.radius).toBeNear(5.6)
		expect(result.duration).toBe(3)
	end)
end)
