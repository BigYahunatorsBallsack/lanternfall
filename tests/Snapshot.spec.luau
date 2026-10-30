-- Unit tests for the enemy snapshot format (Net/Snapshot): round trip (since B5 with the status byte), splitting into
-- parts, limits.

local Snapshot = require(game:GetService("ReplicatedStorage").Shared.Net.Snapshot)

local function columnsOf(count)
	local columns = Snapshot.newColumns()
	for i = 1, count do
		columns.ids[i] = i * 7 % 65536
		columns.xs[i] = (i - count / 2) * 1.37
		columns.zs[i] = -(i % 50) * 2.11
		columns.typeIds[i] = 1 + i % 3
		columns.hpFractions[i] = (i % 10) / 10
		columns.flags[i] = Snapshot.packFlags(i % 4, i % 3)
		columns.statuses[i] = i % 4 -- burning, slowed, both or none
	end
	return columns
end

local function decodeAll(packets)
	local columns = Snapshot.newColumns()
	local total = 0
	for _, packet in packets do
		local tick = Snapshot.readHeader(packet)
		expect(tick ~= nil).toBe(true)
		total += Snapshot.decodeInto(packet, columns, total + 1)
	end
	return columns, total
end

describe("Snapshot", function()
	it("round-trips ids, positions (1/32 stud), types and HP", function()
		local source = columnsOf(40)
		local packets = Snapshot.encode(1234, source, 40)
		expect(#packets).toBe(1)
		local tick, part, partCount, count = Snapshot.readHeader(packets[1])
		expect(tick).toBe(1234)
		expect(part).toBe(0)
		expect(partCount).toBe(1)
		expect(count).toBe(40)
		local decoded, total = decodeAll(packets)
		expect(total).toBe(40)
		for i = 1, 40 do
			expect(decoded.ids[i]).toBe(source.ids[i])
			expect(decoded.xs[i]).toBeNear(source.xs[i], 1 / 64)
			expect(decoded.zs[i]).toBeNear(source.zs[i], 1 / 64)
			expect(decoded.typeIds[i]).toBe(source.typeIds[i])
			expect(decoded.hpFractions[i]).toBeNear(source.hpFractions[i], 1 / 255)
			expect(decoded.flags[i]).toBe(source.flags[i])
			expect(decoded.statuses[i]).toBe(source.statuses[i])
			local mode, affix = Snapshot.unpackFlags(decoded.flags[i])
			expect(mode).toBe(i % 4)
			expect(affix).toBe(i % 3)
		end
	end)

	it("keeps living enemies above 0 HP", function()
		local source = columnsOf(1)
		source.hpFractions[1] = 0.0001
		local decoded = decodeAll(Snapshot.encode(1, source, 1))
		expect(decoded.hpFractions[1] > 0).toBe(true)
	end)

	it("splits 140 enemies evenly into packets below the unreliable size limit", function()
		local packets = Snapshot.encode(5, columnsOf(140), 140)
		expect(#packets).toBe(2)
		for index, packet in packets do
			expect(buffer.len(packet) <= Snapshot.MAX_PACKET_BYTES).toBe(true)
			expect(buffer.len(packet) < 900).toBe(true)
			local tick, part, partCount, count = Snapshot.readHeader(packet)
			expect(tick).toBe(5)
			expect(part).toBe(index - 1)
			expect(partCount).toBe(2)
			expect(count).toBe(70)
		end
		local _, total = decodeAll(packets)
		expect(total).toBe(140)
	end)

	it("sends one empty packet for a tick without enemies", function()
		local packets = Snapshot.encode(9, Snapshot.newColumns(), 0)
		expect(#packets).toBe(1)
		local tick, _, partCount, count = Snapshot.readHeader(packets[1])
		expect(tick).toBe(9)
		expect(partCount).toBe(1)
		expect(count).toBe(0)
	end)

	it("clamps positions outside the encodable range", function()
		local source = columnsOf(1)
		source.xs[1] = 5000
		local decoded = decodeAll(Snapshot.encode(1, source, 1))
		expect(decoded.xs[1]).toBeNear(Snapshot.MAX_COORDINATE, 1 / 32)
	end)

	it("packs a charger's mode, an elite's affix and the rush direction into one byte", function()
		for _, angle in { 0, 0.4, 2, -1.2, 3.1 } do
			local flags = Snapshot.packFlags(2, 3, math.cos(angle), math.sin(angle))
			expect(flags >= 0 and flags <= 255).toBe(true)
			local mode, affix, heading = Snapshot.unpackFlags(flags)
			expect(mode).toBe(2)
			expect(affix).toBe(3)
			local error = math.abs(math.atan2(math.sin(heading - angle), math.cos(heading - angle)))
			expect(error <= math.pi / Snapshot.HEADINGS + 1e-6).toBe(true) -- half a step at most
		end
		local _, _, none = Snapshot.unpackFlags(Snapshot.packFlags(0, 1))
		expect(none).toBe(0)
	end)

	it("rejects malformed packets", function()
		expect(Snapshot.readHeader(buffer.create(3))).toBe(nil)
		local packet = Snapshot.encode(1, columnsOf(3), 3)[1]
		local cut = buffer.create(buffer.len(packet) - 1)
		buffer.copy(cut, 0, packet, 0, buffer.len(cut))
		expect(Snapshot.readHeader(cut)).toBe(nil)
		local badPart = buffer.create(buffer.len(packet))
		buffer.copy(badPart, 0, packet)
		buffer.writeu8(badPart, 4, 1) -- part 1 of 1
		expect(Snapshot.readHeader(badPart)).toBe(nil)
	end)
end)
