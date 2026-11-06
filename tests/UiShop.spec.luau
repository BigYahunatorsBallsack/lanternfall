--!strict
-- Offer previews must agree with combat, and responsive UI must keep the existing server commands usable.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local me = world.addPlayer("Owner", 1, true)
world.step()
local Client = folderProxy("src/client", "Client")
-- This UI test does not render 3D weapons; the current general mock lacks Vector3:Dot.
require(Client.Controllers.WeaponRenderer).start = function() end
runScript(Client, "init.client.luau")
world.advance(0.5)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Preview = require(Client.UI.OfferText)
local WeaponStats = require(Server.Services.WeaponService.WeaponStats)
local Run = require(Server.Services.RunDirector)
local Shop = require(Server.Services.ShopService)
local Stats = require(Server.Services.StatService)

describe("Approved shop UI", function()
	it("previews all four tiers using the same effective damage, timing, reach and crit as combat", function()
		for _, sheet in
			{
				{},
				{
					damage = 36,
					meleeDamage = 12,
					rangedDamage = 14,
					elementalDamage = 8,
					engineering = 6,
					attackSpeed = 46,
					critChance = 8,
					lifeSteal = 8,
					range = 40,
					knockback = 3,
					piercing = 2,
					bounce = 1,
					level = 12,
					weaponCooldownMin = 0.4,
				},
				{
					damage = -150,
					meleeDamage = -20,
					rangedDamage = -12,
					elementalDamage = -8,
					attackSpeed = -70,
					critChance = -50,
					lifeSteal = -5,
					range = -80,
					knockback = -10,
				},
			}
		do
			for id, weapon in Config.Weapons do
				for tier = 1, #weapon.tiers do
					local expected = WeaponStats.compute(weapon, tier, sheet, nil, Config.Player.minWeaponCooldown)
					local actual = Preview.stats(id, tier, sheet)
					for _, key in
						{
							"damage",
							"cooldown",
							"critChance",
							"critDamage",
							"lifeSteal",
							"knockback",
							"pierce",
							"bounce",
						}
					do
						expect(actual[key]).toBe(expected[key])
					end
					for _, key in weapon.rangeKeys do
						expect(actual[key]).toBe(expected[key])
					end
				end
			end
		end
	end)
	it("shows four offers with inline weapon values beside the matching stats sidebar", function()
		world.click(world.gui("Lobby", "Ready"))
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.3)
		expect(Run.getPhase()).toBe("Shop")
		local first = world.gui("Shop", "Offer1")
		expect(first.Size.Y.Offset >= 310).toBe(true)
		expect(world.gui("Shop", "Offers").Position.Y.Offset).toBe(105)
		expect(world.gui("Shop", "ItemInventory").Visible).toBe(true)
		expect(world.gui("Shop", "Ready").Text).toBe("GO (Wave 2)")
		for index, offer in require(Client.Controllers.ShopController).get().offers do
			if offer.kind == "Weapon" then
				local card = world.gui("Shop", `Offer{index}`)
				expect(card.EffectDetails.Visible).toBe(true)
				expect(string.find(card.EffectDetails.Detail.Text, "Critical", 1, true) ~= nil).toBe(true)
			end
		end
		expect(world.gui("Stats", "CurrentLevel").Value.Text).toBe("1")
	end)
	it("keeps purchases, locks and rerolls working after portrait, landscape and desktop transitions", function()
		Shop.addShards(me, 1000)
		Stats.addItem(me, "Vitality")
		Stats.addItem(me, "Vitality")
		world.advance(0.2)
		for _, area in { Vector2.new(390, 844), Vector2.new(844, 390), Vector2.new(1920, 1080), Vector2.new(1280, 720) } do
			workspace.CurrentCamera.ViewportSize = area
			local current = require(Client.Controllers.ShopController).get()
			local before = current.offers[2].locked
			world.click(world.gui("Shop", "Lock2"))
			world.advance(0.2)
			expect(require(Client.Controllers.ShopController).get().offers[2].locked).toBe(not before)
			if area.X < 1000 then
				world.click(world.gui("Shop", "StatsToggle"))
				expect(world.gui("Stats").Enabled).toBe(true)
				world.click(world.gui("Shop", "BackToShop"))
			end
		end
		local current = require(Client.Controllers.ShopController).get()
		local before = current.shards
		local price = current.offers[1].price
		world.click(world.gui("Shop", "Offer1"))
		world.advance(0.2)
		expect(require(Client.Controllers.ShopController).get().shards).toBe(before - price)
		expect(world.gui("Shop", "Vitality").Count.Text).toBe("×2")
		world.click(world.gui("Shop", "Reroll"))
		world.advance(0.2)
		expect(require(Client.Controllers.ShopController).get().offers[1].sold).toBe(false)
		expect(world.gui("Shop", "ShopContent").ScrollingEnabled).toBe(false)
	end)
	it("clears standalone shop controls when combat resumes and uses red health with green XP", function()
		world.click(world.gui("Shop", "Ready"))
		world.advance(0.3)
		expect(Run.getPhase()).toBe("Running")
		expect(world.gui("Shop", "Reroll").Visible).toBe(false)
		expect(world.gui("Shop", "WaveSchedule").Visible).toBe(false)
		expect(world.gui("HUD", "Fill").BackgroundColor3).toBe(require(Client.UI.Theme).hp)
		expect(world.gui("HUD", "XpFill").BackgroundColor3).toBe(require(Client.UI.Theme).xp)
		assert(#world.errors == 0, table.concat(world.errors, "\n"))
	end)
end)
