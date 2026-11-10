--!strict
-- Original periodic site counts, rectangle/body intersections and scored placement use source config.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Rules = require(game:GetService("ServerScriptService").Server.Services.DiggingService.Rules)
describe("Native Dig Site rules", function()
	it("adds periodic item copies only on the matching wave and retains character base sites", function()
		expect(Rules.siteCount("WellRounded", { DigSite = 2 }, 2)).toBe(0)
		expect(Rules.siteCount("WellRounded", { DigSite = 2 }, 3)).toBe(2)
		expect(Rules.siteCount("Archaeologist", { DigSite = 1 }, 6)).toBe(5)
	end)
	it("tests the native rectangular area against the player's body circle including corners", function()
		expect(Rules.contains(0, 0, 11.4, 0)).toBe(true)
		expect(Rules.contains(0, 0, 11.41, 0)).toBe(false)
		expect(Rules.contains(0, 0, 10.69, 10.69)).toBe(true)
		expect(Rules.contains(0, 0, 10.7, 10.7)).toBe(false)
	end)
	it("clamps every placement candidate inside the native edge margin", function()
		local C = require(Shared.Config.Digging)
		local x, z = Rules.position({ center = Vector3.zero, halfX = 100, halfZ = 80 }, {}, function()
			return 0
		end)
		expect(x).toBe(-100 + C.edgeMargin)
		expect(z).toBe(-80 + C.edgeMargin)
	end)
	it("describes the periodic effect without silently hiding its action", function()
		local EffectText = require(game:GetService("ReplicatedStorage").Shared.Util.EffectText)
		expect(EffectText.line({ trigger = "Always", action = "DigSites", amount = 1, per = 3 })).toBe(
			"1 dig site appears every 3 waves"
		)
	end)
end)
