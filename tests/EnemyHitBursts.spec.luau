--!strict
-- Hit feedback on enemies (08.11.2026): red blobs from EnemyRenderer/HitBursts, limited per frame.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local client = folderProxy("src/client", "Client")
local HitBursts = require(client.Controllers.EnemyRenderer.HitBursts)

local settings = Config.Feedback.hitBursts

describe("EnemyRenderer hit bursts", function()
	it("splashes blobs on a hit and stops at the per-frame limit", function()
		HitBursts.beginFrame()
		local before = world.particlesEmitted or 0
		expect(HitBursts.hit(0, 0, 0, 1.5)).toBe(true)
		expect((world.particlesEmitted or 0) - before).toBe(settings.particles)
		for _ = 2, settings.maxPerFrame do
			expect(HitBursts.hit(1, 0, 1, 1.5)).toBe(true)
		end
		expect(HitBursts.hit(2, 0, 2, 1.5)).toBe(false)
		HitBursts.beginFrame()
		expect(HitBursts.hit(2, 0, 2, 1.5)).toBe(true)
	end)
	it("keeps its looks in the config", function()
		expect(#settings.color).toBe(3)
		assert(settings.particlesTouch <= settings.particles)
		assert(settings.maxPerFrameTouch <= settings.maxPerFrame)
		assert(settings.lifetime[1] <= settings.lifetime[2] and settings.speed[1] <= settings.speed[2])
	end)
end)
