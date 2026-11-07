--!strict
-- Native LV.0 HUD and first guaranteed card boundary through real XP, upgrade and client controllers.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
runScript(folderProxy("src/client", "Client"), "init.client.luau")
local S = Server.Services
local Run = require(S.RunDirector)
local XP = require(S.ExperienceService)
local Upgrades = require(S.UpgradeService)
require(S.SpawnDirector).setPaused(true)
require(S.WeaponService).setPaused(true)
Run.setHoldWaves(true)
Run.setReady(me, true)
world.advance(3.5)
local offer
world.getRemote("LevelUpOffer").OnClientEvent:Connect(function(value)
	offer = value
end)

describe("Native level boundaries", function()
	it("starts the HUD at LV.0 and requires 16 XP for the first level", function()
		expect(XP.getLevel(me)).toBe(0)
		expect(XP.getProgress(me).needed).toBe(16)
		expect(world.gui("HUD", "XpText").Text).toBe("LV.0")
	end)

	it("queues native levels one through five and guarantees tier II exactly at level five", function()
		for _ = 1, 5 do
			assert(XP.grantLevel())
		end
		expect(XP.getLevel(me)).toBe(5)
		Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
		for level = 1, 5 do
			expect(offer.level).toBe(level)
			local cards = assert(Upgrades.getOffer(me))
			if level == 1 or level == 5 then
				for _, card in cards do
					expect(card.tier).toBe(if level == 1 then 1 else 2)
				end
			end
			world.fireServerAs(me, "ChooseUpgrade", cards[1].id)
			world.advance(0.3)
		end
		expect(Upgrades.getOffer(me)).toBe(nil)
		expect(world.gui("HUD", "XpText").Text).toBe("LV.5")
		local Client = folderProxy("src/client", "Client")
		local sheet = require(Client.Controllers.StatsController).get()
		expect(sheet.level).toBe(5)
		local preview = require(Client.UI.OfferText).stats("Quarterstaff", 1, sheet)
		local combat = require(S.WeaponService.WeaponStats).compute(
			require(Shared.Config).Weapons.Quarterstaff,
			1,
			sheet,
			nil,
			require(Shared.Config).Player.minWeaponCooldown
		)
		expect(preview.damage).toBe(combat.damage)
	end)
end)
