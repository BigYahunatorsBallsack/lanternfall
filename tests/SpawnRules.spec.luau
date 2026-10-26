-- Unit tests for the spawn formulas (SpawnDirector/SpawnRules) against the numbers in DESIGN.md section 7.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local SpawnRules = require(game:GetService("ServerScriptService").Server.Services.SpawnDirector.SpawnRules)

local bounds = { minX = -150, maxX = 150, minZ = -150, maxZ = 150 }

describe("SpawnRules", function()
	it("matches the design's player factors and rates", function()
		expect(SpawnRules.playerFactor(1)).toBeNear(1)
		expect(SpawnRules.playerFactor(2)).toBeNear(1.6)
		expect(SpawnRules.playerFactor(4)).toBeNear(2.8)
		expect(SpawnRules.rate(0, 1)).toBeNear(1.5)
		expect(SpawnRules.rate(10, 1)).toBeNear(7)
		expect(SpawnRules.rate(10, 4)).toBeNear(19.6)
	end)

	it("caps alive enemies at 80 + 20 per extra player, at most 140", function()
		expect(SpawnRules.cap(1)).toBe(80)
		expect(SpawnRules.cap(2)).toBe(100)
		expect(SpawnRules.cap(4)).toBe(140)
		expect(SpawnRules.cap(6)).toBe(140)
		expect(SpawnRules.cap(0)).toBe(80)
	end)

	it("grows HP to 2.5x at minute 10", function()
		expect(SpawnRules.hpFactor(0)).toBeNear(1)
		expect(SpawnRules.hpFactor(10)).toBeNear(2.5)
	end)

	it("changes the mix at minute 2 and 4", function()
		expect(SpawnRules.mixAt(1.9).Brute).toBe(nil)
		expect(SpawnRules.mixAt(2).Brute).toBeNear(0.2)
		expect(SpawnRules.mixAt(3.99).Spitter).toBe(nil)
		expect(SpawnRules.mixAt(4).Spitter).toBeNear(0.2)
		expect(SpawnRules.mixAt(11).Shadeling).toBeNear(0.6)
	end)

	it("picks enemies by weight", function()
		local weights = SpawnRules.mixAt(5)
		local counts = { Shadeling = 0, Brute = 0, Spitter = 0 }
		for i = 0, 999 do
			local id = SpawnRules.pickEnemy(weights, i / 1000)
			counts[id] += 1
		end
		expect(counts.Shadeling).toBe(600)
		expect(counts.Brute).toBe(200)
		expect(counts.Spitter).toBe(200)
		expect(SpawnRules.pickEnemy(weights, 0.999999)).toBe("Spitter")
	end)

	it("spawns on the ring, inside the arena and never in an obstacle", function()
		local obstacles = { { x = 50, z = 0, radius = 10 } }
		local seed = 1
		local function random()
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		local ring = Config.Run.spawn
		for _ = 1, 500 do
			local x, z = SpawnRules.findSpawnPoint(random, 0, 0, 2.5, bounds, obstacles, 12)
			expect(x ~= nil).toBe(true)
			local distance = math.sqrt(x * x + z * z)
			expect(distance >= ring.ringMin - 1e-6 and distance <= ring.ringMax + 1e-6).toBe(true)
			expect(SpawnRules.isFree(x, z, 2.5, bounds, obstacles)).toBe(true)
		end
	end)

	it("still finds spots for a player in a corner, and gives up when there are none", function()
		local seed = 3
		local function random()
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		local found = 0
		for _ = 1, 100 do
			if SpawnRules.findSpawnPoint(random, 145, 145, 1.5, bounds, {}, 12) then
				found += 1
			end
		end
		expect(found >= 85).toBe(true)
		local tiny = { minX = -10, maxX = 10, minZ = -10, maxZ = 10 }
		expect(SpawnRules.findSpawnPoint(random, 0, 0, 1.5, tiny, {}, 12)).toBe(nil)
	end)
end)
