-- Unit tests for the damage number format (Net/HitNumbers): round trip, flags, limits.

local HitNumbers = require(game:GetService("ReplicatedStorage").Shared.Net.HitNumbers)

describe("HitNumbers", function()
	it("round-trips positions, rounded amounts and the crit and kill flags", function()
		local xs, zs = { 10.5, -33.25, 0 }, { -4, 120.125, 0.5 }
		local amounts = { 14.6, 0.2, 70000 }
		local flags = { 0, HitNumbers.FLAG_CRIT, HitNumbers.FLAG_CRIT + HitNumbers.FLAG_KILL }
		local hits = HitNumbers.decode(HitNumbers.encode(xs, zs, amounts, flags, 3))
		expect(#hits).toBe(3)
		expect(hits[1].x).toBeNear(10.5, 1 / 32)
		expect(hits[2].z).toBeNear(120.125, 1 / 32)
		expect(hits[1].amount).toBe(15)
		expect(hits[2].amount).toBe(1) -- at least 1
		expect(hits[3].amount).toBe(65535) -- at most what fits
		expect(hits[1].crit).toBe(false)
		expect(hits[2].crit).toBe(true)
		expect(hits[2].killed).toBe(false)
		expect(hits[3].crit).toBe(true)
		expect(hits[3].killed).toBe(true)
	end)

	it("keeps at most MAX_HITS per packet, below the unreliable size limit", function()
		local xs, zs, amounts, flags = {}, {}, {}, {}
		for i = 1, 150 do
			xs[i], zs[i], amounts[i], flags[i] = i, -i, i, 0
		end
		local packet = HitNumbers.encode(xs, zs, amounts, flags, 150)
		expect(buffer.len(packet) <= 900).toBe(true)
		expect(#HitNumbers.decode(packet)).toBe(HitNumbers.MAX_HITS)
	end)

	it("rejects malformed packets", function()
		expect(#HitNumbers.decode(buffer.create(0))).toBe(0)
		local bad = buffer.create(5)
		buffer.writeu8(bad, 0, 3)
		expect(#HitNumbers.decode(bad)).toBe(0)
	end)
end)
