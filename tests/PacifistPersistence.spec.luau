--!strict
-- Schema migration and native item data preserve legacy saves and keep unuploaded art out of random pools.
local Services = game:GetService("ServerScriptService").Server.Services
local Migrations = require(Services.PlayerDataService.Migrations)
local Template = require(Services.PlayerDataService.ProfileTemplate)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Shop = require(Services.ShopService.ShopRules)
local Text = require(Shared.Util.UpgradeText)
describe("Pacifist persistence and item policy", function()
	it("migrates v9 without changing legacy currency, records or unlocks", function()
		local data = Template.new() :: any
		data.schemaVersion = 9
		data.nativeCounts = nil
		data.embers = 123
		data.achievements["Brotato:chal_medicine"] = true
		data.characterStats.Doctor = { runs = 3, wins = 1, bestWave = 20, bestDanger = 0 }
		Migrations.run(data, Template.SCHEMA_VERSION)
		expect(data.nativeCounts.materialsCollected).toBe(0)
		expect(data.embers).toBe(123)
		expect(data.achievements["Brotato:chal_medicine"]).toBe(true)
		expect(data.characterStats.Doctor.wins).toBe(1)
		data.nativeCounts.materialsCollected = 4321
		Migrations.run(data, Template.SCHEMA_VERSION)
		expect(data.nativeCounts.materialsCollected).toBe(4321)
	end)
	it("creates independent counters for new profiles", function()
		local a, b = Template.new(), Template.new()
		a.nativeCounts.materialsCollected = 99
		expect(b.nativeCounts.materialsCollected).toBe(0)
	end)
	it("matches the native unique Shirt and excludes its pending image from all random pools", function()
		local shirt = Config.Items.byId.LumberjackShirt
		expect(shirt.price).toBe(15)
		expect(shirt.tier).toBe(1)
		expect(shirt.limit).toBe(1)
		expect(Text.itemLines("LumberjackShirt"):find("Trees die in one hit", 1, true) ~= nil).toBe(true)
		for _, id in { "NightWatch", "Pacifist" } do
			expect(Shop.itemAllowed(id, "LumberjackShirt", 1)).toBe(false)
			expect(Shop.itemAllowed(id, "LumberjackShirt", 20)).toBe(false)
		end
	end)
end)
