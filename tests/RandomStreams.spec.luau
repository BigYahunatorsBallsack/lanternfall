-- Unit tests for the seeded random streams (RandomService/Streams, DESIGN.md section 15).

local Streams = require(game:GetService("ServerScriptService").Server.Services.RandomService.Streams)

local NAMES = { "Shop", "Spawns", "Combat" }

-- A tiny seeded generator with Random's methods (the pure test runner has no Roblox Random).
local function generator(seed)
	local state = seed
	local self = {}
	function self.NextNumber()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	function self.NextInteger(_, min, max)
		return min + math.floor(self.NextNumber() * (max - min + 1))
	end
	return self
end

local function draws(generator, count)
	local list = {}
	for _ = 1, count do
		table.insert(list, generator:NextNumber())
	end
	return table.concat(list, ",")
end

describe("RandomStreams", function()
	it("hashes texts to stable seeds in Random's range", function()
		local a = Streams.hash("123/Shop/0")
		expect(a).toBe(Streams.hash("123/Shop/0"))
		expect(a ~= Streams.hash("123/Shop/1")).toBe(true)
		expect(a ~= Streams.hash("124/Shop/0")).toBe(true)
		for _, text in { "", "a", "1/Combat/0", string.rep("x", 300) } do
			local seed = Streams.hash(text)
			expect(seed >= 1 and seed <= 2 ^ 31 - 2 and seed % 1 == 0).toBe(true)
		end
	end)

	it("gives each name and player its own stream that a run seed replays", function()
		local first = Streams.new(42, NAMES, generator)
		local again = Streams.new(42, NAMES, generator)
		expect(first:get("Shop", 7)).toBe(first:get("Shop", 7)) -- cached
		local shop = draws(first:get("Shop", 7), 5)
		expect(draws(again:get("Shop", 7), 5)).toBe(shop)
		-- rolls in another stream do not shift this one
		local other = Streams.new(42, NAMES, generator)
		draws(other:get("Spawns"), 50)
		expect(draws(other:get("Shop", 7), 5)).toBe(shop)
		expect(draws(Streams.new(42, NAMES, generator):get("Shop", 8), 5) ~= shop).toBe(true)
		expect(draws(Streams.new(43, NAMES, generator):get("Shop", 7), 5) ~= shop).toBe(true)
	end)

	it("refuses unknown stream names", function()
		local streams = Streams.new(1, NAMES, generator)
		expect(pcall(streams.get, streams, "Loot")).toBe(false)
	end)
end)
