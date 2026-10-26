-- Unit tests for team XP (ExperienceService/Progression: the XP curve from DESIGN.md section 9) and XP orbs on the
-- floor (ExperienceService/OrbField: drop, merge at the cap, pick up).

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Services = game:GetService("ServerScriptService").Server.Services
local Progression = require(Services.ExperienceService.Progression)
local OrbField = require(Services.ExperienceService.OrbField)

local CURVE = Config.Run.xpCurve

describe("Progression", function()
	it("matches the solo numbers in DESIGN.md", function()
		expect(Progression.xpForLevel(CURVE, 1, 1)).toBe(7)
		expect(Progression.xpForLevel(CURVE, 10, 1)).toBe(53)
		expect(Progression.xpForLevel(CURVE, 30, 1)).toBe(205)
		local total = 0
		for level = 1, 34 do
			total += Progression.xpForLevel(CURVE, level, 1)
		end
		expect(total > 3500 and total < 4100).toBe(true) -- "bis Level 35 zusammen rund 3.800 XP"
	end)

	it("scales the XP needed with the player factor", function()
		expect(Progression.xpForLevel(CURVE, 1, 1.6)).toBe(12) -- 7.4 * 1.6 = 11.84
		expect(Progression.xpForLevel(CURVE, 1, 2.8)).toBe(21)
	end)

	it("levels up once enough XP is in and keeps the rest", function()
		local p = Progression.new(CURVE)
		expect(p:add(6, 1)).toBe(0)
		expect(p.level).toBe(1)
		expect(p:add(2, 1)).toBe(1) -- 8 of 7
		expect(p.level).toBe(2)
		expect(p.xp).toBe(1)
	end)

	it("gains several levels from one big pickup", function()
		local p = Progression.new(CURVE)
		local needed = Progression.xpForLevel(CURVE, 1, 1) + Progression.xpForLevel(CURVE, 2, 1)
		expect(p:add(needed + 3, 1)).toBe(2)
		expect(p.level).toBe(3)
		expect(p.xp).toBe(3)
		p:reset()
		expect(p.level).toBe(1)
		expect(p.xp).toBe(0)
	end)
end)

describe("OrbField", function()
	it("drops orbs with their own ids and picks up those in the radius", function()
		local field = OrbField.new(10)
		local a = field:spawn(0, 0, 1)
		local b = field:spawn(5, 0, 4)
		local c = field:spawn(20, 0, 2)
		expect(a ~= b and b ~= c).toBe(true)
		local out = {}
		expect(field:collect(1, 0, 4, out)).toBe(5) -- a at 1 stud, b at 4 studs
		expect(#out).toBe(2)
		expect(field:count()).toBe(1)
		local x, z, value = field:get(c)
		expect(x).toBe(20)
		expect(z).toBe(0)
		expect(value).toBe(2)
		expect(field:get(a)).toBe(nil)
	end)

	it("adds XP to the nearest orb once full", function()
		local field = OrbField.new(2)
		local near = field:spawn(0, 0, 1)
		field:spawn(50, 0, 1)
		local id, merged = field:spawn(2, 0, 4)
		expect(id).toBe(near)
		expect(merged).toBe(true)
		expect(field:count()).toBe(2)
		local _, _, value = field:get(near)
		expect(value).toBe(5)
	end)

	it("keeps ids and positions straight after removing from the middle", function()
		local field = OrbField.new(10)
		local ids = {}
		for i = 1, 5 do
			ids[i] = field:spawn(i * 10, 0, i)
		end
		local out = {}
		expect(field:collect(20, 0, 1, out)).toBe(2)
		expect(out[1]).toBe(ids[2])
		local x, _, value = field:get(ids[5])
		expect(x).toBe(50)
		expect(value).toBe(5)
		local flat = field:flatten()
		expect(#flat).toBe(16)
		field:clear()
		expect(field:count()).toBe(0)
	end)
end)
