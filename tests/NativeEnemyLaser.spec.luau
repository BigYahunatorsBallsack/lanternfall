--!strict
-- Source laser clocks enable after the warning, decrement active time on that same frame, and test the centered oriented rectangle.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local L = require(Shared.Util.NativeEnemyLaser)
describe("Native source enemy laser", function()
	it("waits45frames then expires after the active counter's24th frame including its enabling frame", function()
		local state = L.new()
		local hits = 0
		L.step(state, 44 / 60, function()
			hits += 1
			return false
		end)
		expect(hits).toBe(0)
		L.step(state, 1 / 60, function()
			hits += 1
			return false
		end)
		expect(hits).toBe(1)
		L.step(state, 23 / 60, function()
			hits += 1
			return false
		end)
		expect(state.stopped).toBe(true)
		expect(hits).toBe(23)
	end)
	it("stops the entire beam on its first reported collision", function()
		local state = L.new()
		local hits = 0
		L.step(state, 2, function()
			hits += 1
			return true
		end)
		expect(hits).toBe(1)
		expect(state.stopped).toBe(true)
	end)
	it("covers both sides of its source and keeps rectangular corners rather than capsule ends", function()
		expect(L.contains(0, 0, 1, 0, 199.9, 1.4, 0)).toBe(true)
		expect(L.contains(0, 0, 1, 0, -199.9, 1.4, 0)).toBe(true)
		expect(L.contains(0, 0, 1, 0, 200.4, 1.9, 0.5)).toBe(false)
		expect(L.contains(0, 0, 1, 0, 200.3, 1.8, 0.5)).toBe(true)
	end)
	it("rotates the source rectangle without changing its centered length", function()
		expect(L.contains(4, 5, 0, 1, 5.4, 204.9, 0)).toBe(true)
		expect(L.contains(4, 5, 0, 1, 5.6, 204.9, 0)).toBe(false)
	end)
end)
