--!strict
-- Original Blazemander physics and delayed coroutine timing; the hitbox window is independent of the attack flag.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services.StructureService
local Timing = require(S.PetBlazeTiming)
local pet = require(game:GetService("ReplicatedStorage").Shared.Config.Pets).kinds.Blazemander
describe("Native Blazemander timing", function()
	it("enables melee after the native delay and keeps that hitbox active until the next close", function()
		local o = { pet = pet, beastMaster = false }
		local sheet = {}
		Timing.init(o, sheet, function()
			return 1
		end)
		local active = {}
		for frame = 1, 46 do
			local _, hit = Timing.step(o, sheet, true)
			active[frame] = hit
		end
		expect(active[22]).toBe(false)
		expect(active[23]).toBe(false)
		expect(active[31]).toBe(false)
		expect(active[32]).toBe(true)
		expect(active[45]).toBe(true)
		expect(active[46]).toBe(false)
	end)
	it("pauses both cooldowns during the attack flag and resets a fired ring on the following frame", function()
		local o = { pet = pet, beastMaster = false }
		local sheet, shots = {}, {}
		Timing.init(o, sheet, function()
			return 0
		end)
		for frame = 1, 63 do
			local fire = Timing.step(o, sheet, true)
			if fire then
				table.insert(shots, frame)
			end
		end
		expect(#shots).toBe(1)
		expect(shots[1]).toBe(62)
		expect(o.blazeRangedFrames).toBe(240)
	end)
	it("does not attack without a nearby enemy and carries no delayed hitbox work across a new deployment", function()
		local o = { pet = pet, beastMaster = false }
		local sheet = { attackSpeed = 1000, structureAttackSpeed = 1000 }
		Timing.init(o, sheet, function()
			return 0
		end)
		for _ = 1, 300 do
			local fire, hit = Timing.step(o, sheet, false)
			expect(fire).toBe(false)
			expect(hit).toBe(false)
		end
		local fire = Timing.step(o, sheet, true)
		expect(fire).toBe(true)
		Timing.init(o, sheet, function()
			return 1
		end)
		expect(#o.blazeTimers).toBe(0)
		expect(o.blazeHitbox).toBe(false)
		expect(o.blazeRangedFrames).toBe(240)
	end)
end)
