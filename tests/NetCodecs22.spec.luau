-- Paket 22: the compact weapon effect format (Net/WeaponFx) gives back the same effect tables, keeps unknown names
-- and fields, and is much smaller than the old table form; the size estimate (Net/NetSize) counts like Roblox's remote
-- format (type byte, doubles, length prefixes, string keys).

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local NetSize = require(Shared.Net.NetSize)
local WeaponFx = require(Shared.Net.WeaponFx)
local StructureFeed = require(Shared.Net.StructureFeed)
local ShotFeed = require(Shared.Net.ShotFeed)

local SIZES = Config.Simulation.netSize

local function near(a: number, b: number): boolean
	return math.abs(a - b) <= math.max(1e-3, math.abs(b) * 1e-6)
end

local function same(a: { [string]: any }, b: { [string]: any }): boolean
	for key, value in a do
		local other = b[key]
		if type(value) == "number" then
			if type(other) ~= "number" or not near(other, value) then
				return false
			end
		elseif type(value) == "table" then
			if type(other) ~= "table" or #other ~= #value then
				return false
			end
			for i, entry in value do
				if not near(other[i], entry) then
					return false
				end
			end
		elseif other ~= value then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

describe("WeaponFx", function()
	local at = 1234.5678
	local effects = {
		{
			weapon = "SparkBolt",
			userId = 1,
			kind = "Fire",
			at = at,
			id = 77,
			x = 10.25,
			z = -40.5,
			dx = 0.6,
			dz = 0.8,
			speed = 60,
			range = 30,
		},
		{ weapon = "SparkBolt", userId = 1, kind = "End", at = at, id = 76, distance = 12.5 },
		{ weapon = "ChainLightning", userId = 5000000001, kind = "Chain", at = at, points = { 1, 2, 3.5, 4 } },
		{ weapon = "Explosion", userId = 2, kind = "Blast", at = at, x = 1, z = 2, radius = 6 },
		{ weapon = "BrandNewBehavior", userId = 2, kind = "Sparkle", at = at + 0.5, x = 3, z = 4, angle = 120 },
		{
			weapon = "Shockwave",
			userId = 3,
			kind = "Pulse",
			at = at,
			radius = 8,
			id = 2 ^ 40,
			hue = 0.5,
			label = "hi",
			big = true,
			small = false,
			list = { 1.5, 2 },
		},
	}

	it("decodes exactly the effects it encoded", function()
		local decoded = WeaponFx.decode(WeaponFx.encode(effects))
		expect(#decoded).toBe(#effects)
		for i, effect in effects do
			expect(same(effect, decoded[i])).toBe(true)
		end
		expect(decoded[1].id).toBe(77)
		expect(decoded[3].userId).toBe(5000000001)
		expect(decoded[5].weapon).toBe("BrandNewBehavior") -- unknown names arrive as text
		expect(decoded[5].kind).toBe("Sparkle")
		expect(decoded[6].id).toBe(2 ^ 40)
	end)

	it("knows every weapon and evolution behavior and the shared explosion", function()
		for _, weapon in Config.Weapons do
			expect(table.find(WeaponFx.WEAPONS, weapon.behavior) ~= nil).toBe(true)
		end
		expect(table.find(WeaponFx.WEAPONS, "Explosion") ~= nil).toBe(true)
		expect(#WeaponFx.WEAPONS < 255).toBe(true)
	end)

	it("is a third of the old table form on the wire or less", function()
		local packet = WeaponFx.encode(effects)
		expect(NetSize.call(packet) * 2.5 < NetSize.call(effects)).toBe(true)
		local bolts = {}
		for i = 1, 40 do
			bolts[i] = {
				weapon = "SparkBolt",
				userId = 1,
				kind = "Fire",
				at = at,
				id = i,
				x = i,
				z = 2,
				dx = 0,
				dz = 1,
				speed = 60,
				range = 30,
			}
		end
		expect(NetSize.call(WeaponFx.encode(bolts)) * 3 < NetSize.call(bolts)).toBe(true)
	end)

	it("handles an empty step and malformed packets", function()
		expect(#WeaponFx.decode(WeaponFx.encode({}))).toBe(0)
		expect(#WeaponFx.decode(buffer.create(3))).toBe(0)
		local packet = WeaponFx.encode(effects)
		local cut = buffer.create(buffer.len(packet) - 1)
		buffer.copy(cut, 0, packet, 0, buffer.len(cut))
		expect(#WeaponFx.decode(cut)).toBe(0)
	end)
end)

describe("StructureFeed", function()
	it("decodes the structures and beams it encoded", function()
		local rows = {
			{ id = 1, ownerId = 7, kind = "BrassSentry", x = 10.5, z = -3.25 },
			{ id = 70000, ownerId = 9000000000, kind = "OrbitWisp", x = 0, z = 0 },
			{ id = 3, ownerId = 7, kind = "SomethingNew", x = 1, z = 2 },
		}
		local decoded = StructureFeed.decodeStructures(StructureFeed.encodeStructures(rows))
		expect(#decoded).toBe(3)
		for i, row in rows do
			expect(same(row, decoded[i])).toBe(true)
		end
		local beams = {
			{ x = 1, z = 2, tx = 30.5, tz = -4, kind = "BrassSentry" },
			{ x = 5, z = 6, tx = 7, tz = 8, kind = "Unknown" },
		}
		local decodedBeams = StructureFeed.decodeBeams(StructureFeed.encodeBeams(beams))
		expect(#decodedBeams).toBe(2)
		for i, beam in beams do
			expect(same(beam, decodedBeams[i])).toBe(true)
		end
		expect(#StructureFeed.decodeStructures(buffer.create(1))).toBe(0)
		expect(NetSize.call(StructureFeed.encodeStructures(rows)) * 2.5 < NetSize.call(rows)).toBe(true)
	end)
end)

describe("ShotFeed", function()
	it("decodes the enemy shots it encoded", function()
		local fired = {
			{ id = 5, x = 10, z = -20.5, dx = 0.6, dz = -0.8, speed = 22, range = 40, at = 999.25 },
			{ id = 6, x = 11, z = -21, dx = 1, dz = 0, speed = 12, range = 18, at = 999.3 },
		}
		local events = ShotFeed.decode(ShotFeed.encode({ reset = true, fired = fired, ended = { 3, 12.5, 4, 0.25 } }))
		expect(events.reset).toBe(true)
		expect(#events.fired).toBe(2)
		for i, shot in fired do
			expect(same(shot, events.fired[i])).toBe(true)
		end
		expect(#events.ended).toBe(4)
		expect(events.ended[1]).toBe(3)
		expect(events.ended[2]).toBe(12.5)
		expect(events.ended[4]).toBe(0.25)
		local none = ShotFeed.decode(ShotFeed.encode({ fired = {}, ended = {} }))
		expect(none.reset).toBe(false)
		expect(#none.fired + #none.ended).toBe(0)
		expect(#ShotFeed.decode(buffer.create(14)).fired).toBe(0)
		expect(
			NetSize.call(ShotFeed.encode({ fired = fired, ended = {} })) * 2.5
				< NetSize.call({ fired = fired, ended = {} })
		).toBe(true)
	end)
end)

describe("NetSize", function()
	it("counts type bytes, doubles, length prefixes and string keys", function()
		local t = SIZES.typeByte
		expect(NetSize.value(nil)).toBe(t)
		expect(NetSize.value(true)).toBe(t + 1)
		expect(NetSize.value(1.5)).toBe(t + SIZES.number)
		expect(NetSize.value("abc")).toBe(t + 1 + 3)
		expect(NetSize.value(buffer.create(200))).toBe(t + 2 + 200)
		expect(NetSize.value({ 1, 2 })).toBe(t + 1 + 2 * (t + SIZES.number))
		expect(NetSize.value({ hp = 3 })).toBe(t + 1 + (1 + 2) + (t + SIZES.number))
		expect(NetSize.call()).toBe(SIZES.callOverhead)
		expect(NetSize.call(1, "a")).toBe(SIZES.callOverhead + (t + SIZES.number) + (t + 1 + 1))
	end)
end)
