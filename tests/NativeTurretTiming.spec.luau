--!strict
-- Native animation delays, maximum animation rate and random cooldowns use production structure rules.
loadHelper("tests/helpers/RobloxMock.luau")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.StructureService
local Timing = require(S.TurretTiming)
describe("Native turret timing", function()
	it("fires at the animation event and starts a random cooldown after the animation completes", function()
		local state = { remaining = 0 }
		local shots = 0
		local function step(dt)
			Timing.step(state, dt, Config.Structures.kinds.BrassSentry, {}, false, true, function()
				return 0.5
			end, function()
				shots += 1
			end)
		end
		step(0.01)
		expect(shots).toBe(0)
		step(0.19)
		expect(shots).toBe(0)
		step(0.01)
		expect(shots).toBe(1)
		step(0.1)
		expect(state.attack).toBe(nil)
		expect(state.remaining).toBeNear(32 / 60)
	end)
	it("caps accelerated animation at three while still applying structure speed to cooldown", function()
		local state = { remaining = 0 }
		local shots = 0
		local function step(dt)
			Timing.step(
				state,
				dt,
				Config.Structures.kinds.BrassSentry,
				{ structureAttackSpeed = 1000 },
				false,
				true,
				function()
					return 0
				end,
				function()
					shots += 1
				end
			)
		end
		step(0.01)
		expect(state.animationSpeed).toBe(3)
		step(0.07)
		expect(shots).toBe(1)
		step(0.04)
		expect(state.remaining).toBeNear((2 / 60) * 0.7)
	end)
end)
