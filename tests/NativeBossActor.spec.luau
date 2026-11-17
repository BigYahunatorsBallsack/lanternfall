--!strict
-- Explicit native elite controller preserves source attack frames across server batches and source boss-init branches.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Actor = require(game:GetService("ServerScriptService").Server.Services.EnemySim.NativeBossActor)
local C = require(Shared.Config.NativeTherizinosaurus).controller
local function fixed()
	return 0.5
end
describe("Native elite actor composition", function()
	it("preserves the same attack frames when server time arrives in one batch or sixty frames", function()
		local batch, frames = Actor.new(C, fixed), Actor.new(C, fixed)
		local a, b = {}, {}
		Actor.step(
			batch,
			1,
			function()
				return 1
			end,
			10,
			fixed,
			function(index)
				table.insert(a, index)
			end
		)
		for _ = 1, 60 do
			Actor.step(
				frames,
				1 / 60,
				function()
					return 1
				end,
				10,
				fixed,
				function(index)
					table.insert(b, index)
				end
			)
		end
		assert(#b > 0)
		expect(#a).toBe(#b)
		expect(batch.shooting.clocks[1].remaining).toBeNear(frames.shooting.clocks[1].remaining)
		expect(batch.shooting.animation.cursor).toBeNear(frames.shooting.animation.cursor)
	end)
	it("preserves the original mutually exclusive early, double-boss and easy-area health branches", function()
		local rows = {
			{ 8, 2, 2, false, 0.5, 1 },
			{ 11, 2, 2, false, 0.75, 0.75 },
			{ 13, 2, 2, false, 1, 1 },
			{ 20, 2, 0, false, 0.9, 1 },
			{ 20, 0, 0, false, 1, 1 },
			{ 20, 2, 5, true, 0.75, 1 },
		}
		for _, row in rows do
			local hp, damage = Actor.initialShares(C, row[1], row[2], row[3], row[4])
			expect(hp).toBe(row[5])
			expect(damage).toBe(row[6])
		end
	end)
end)
