--!strict
-- Source finite spawning counts every attempted child, permits a whole final batch and keeps exhausted clocks separate.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local S = require(Shared.Util.NativeBossShooting)
local function fixed()
	return 0.5
end
local function rules(limit)
	local r = table.clone(require(Shared.Config.NativeSilesaurus).shootingRules)
	r.profiles = table.clone(r.profiles)
	r.profiles[1] = table.clone(r.profiles[1])
	r.profiles[1].spawnLimit = limit
	r.profiles[1].exhaustedFrames = 99999999
	return r
end
describe("Native finite boss spawning", function()
	it("counts children rather than salvos and allows the complete batch that crosses the limit", function()
		local state = S.new(rules(3), fixed)
		local count = 0
		for _ = 1, 2 do
			assert(S.physics(state, 1, math.huge))
			S.advanceAnimation(state, 1, fixed, function(index)
				count += 2
				S.recordSpawns(state, index, 2)
			end)
		end
		expect(count).toBe(4)
		expect(state.clocks[1].spawns).toBe(4)
		expect(state.clocks[1].remaining).toBe(99999999)
		expect(S.physics(state, 99999999, 0)).toBe(false)
	end)
	it("does not increment spawning counts for a method routed to the current bullet profile", function()
		local state = S.new(rules(1), fixed)
		assert(S.physics(state, 1, math.huge))
		S.select(state, 2)
		S.advanceAnimation(state, 1, fixed, function(index)
			if index == 1 then
				S.recordSpawns(state, index, 1)
			end
		end)
		expect(state.clocks[1].spawns).toBe(0)
		expect(state.clocks[2].spawns).toBe(0)
		expect(state.clocks[2].shots).toBe(1)
	end)
	it("uses the source zero-limit ready clock and resets only the selected behavior", function()
		local state = S.new(rules(0), fixed)
		expect(state.clocks[1].remaining).toBe(99999999)
		expect(S.physics(state, 100000000, 0)).toBe(false)
		S.resetCurrent(state, fixed)
		expect(state.clocks[1].remaining).toBe(60) -- source reset calls get_cd, unlike its ready zero-limit branch
		expect(S.physics(state, 1, 0)).toBe(false)
		S.select(state, 2)
		expect(S.physics(state, 1, 10)).toBe(true)
	end)
	it("resets an exhausted spawn counter without resetting a playing shared animation", function()
		local state = S.new(rules(1), fixed)
		assert(S.physics(state, 1, 0))
		S.advanceAnimation(state, 0.8, fixed, function(index)
			S.recordSpawns(state, index, 1)
		end)
		S.resetCurrent(state, fixed)
		expect(state.clocks[1].spawns).toBe(0)
		expect(state.animation.playing).toBe(true)
		S.advanceAnimation(state, 0.2, fixed)
		expect(state.clocks[1].remaining).toBe(60)
	end)
end)
