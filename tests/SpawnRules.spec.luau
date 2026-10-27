-- Unit tests for the spawn formulas (SpawnDirector/SpawnRules) and the run's timeline (Util/RunSchedule) against
-- the numbers in DESIGN.md section 7.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RunSchedule = require(game:GetService("ReplicatedStorage").Shared.Util.RunSchedule)
local SpawnRules = require(game:GetService("ServerScriptService").Server.Services.SpawnDirector.SpawnRules)

local bounds = { minX = -150, maxX = 150, minZ = -150, maxZ = 150 }

describe("SpawnRules", function()
	it("matches the design's player factors and rates", function()
		expect(SpawnRules.playerFactor(1)).toBeNear(1)
		expect(SpawnRules.playerFactor(2)).toBeNear(1.6)
		expect(SpawnRules.playerFactor(4)).toBeNear(2.8)
		expect(SpawnRules.rate(0, 1)).toBeNear(1) -- calm start
		expect(SpawnRules.rate(0.5, 1)).toBeNear(1.6) -- halfway between the keyframes at 0 and 1
		expect(SpawnRules.rate(12, 1)).toBeNear(8.6)
		expect(SpawnRules.rate(12, 4)).toBeNear(8.6 * 2.8)
		expect(SpawnRules.rate(20, 1)).toBeNear(8.6) -- flat after the last keyframe
	end)

	it("reads keyframe curves linearly between points", function()
		local curve = { { 0, 1 }, { 2, 3 }, { 4, 3 } }
		expect(RunSchedule.curve(curve, -1)).toBeNear(1)
		expect(RunSchedule.curve(curve, 1)).toBeNear(2)
		expect(RunSchedule.curve(curve, 3)).toBeNear(3)
		expect(RunSchedule.curve(curve, 9)).toBeNear(3)
	end)

	it("runs a wave per minute that ramps up and ends with a breather", function()
		local waves = Config.Run.spawn.waves
		local first = RunSchedule.waveAt(0)
		expect(first.number).toBe(1)
		expect(first.count).toBe(12)
		expect(first.breather).toBe(false)
		expect(RunSchedule.intensity(0)).toBeNear(waves.rampFrom)
		local rampEnd = waves.lengthSeconds - waves.breatherSeconds
		expect(RunSchedule.intensity(rampEnd - 1e-3)).toBeNear(waves.rampTo, 1e-3)
		expect(RunSchedule.waveAt(rampEnd + 1).breather).toBe(true)
		expect(RunSchedule.intensity(rampEnd + 1)).toBeNear(waves.breatherRate)
		expect(RunSchedule.waveAt(60).number).toBe(2)
		local final = RunSchedule.waveAt(11 * 60 + 55)
		expect(final.number).toBe(12)
		expect(final.final).toBe(true)
		expect(final.breather).toBe(false) -- no breather before the boss
		expect(RunSchedule.intensity(11 * 60 + 55) > waves.rampTo).toBe(true)
		expect(RunSchedule.waveAt(800).number).toBe(12) -- the boss phase stays in the last wave
		expect(SpawnRules.currentRate(rampEnd / 60 + 0.05, 1)).toBeNear(
			SpawnRules.rate(rampEnd / 60 + 0.05, 1) * waves.breatherRate
		)
	end)

	it("names what each wave brings on its banner", function()
		expect(#RunSchedule.eventsOf(1)).toBe(0)
		expect(table.concat(RunSchedule.eventsOf(3), "|")).toBe("New: Brutes|A Gloom Elite!")
		expect(table.concat(RunSchedule.eventsOf(6), "|")).toBe("Swarm Rush!")
		expect(table.concat(RunSchedule.eventsOf(7), "|")).toBe("New: Abyss Shadelings|2 Gloom Elites!")
		expect(table.concat(RunSchedule.eventsOf(12), "|")).toBe("Final wave")
	end)

	it("caps alive enemies at 80 + 20 per extra player, at most 140", function()
		expect(SpawnRules.cap(1)).toBe(80)
		expect(SpawnRules.cap(2)).toBe(100)
		expect(SpawnRules.cap(4)).toBe(140)
		expect(SpawnRules.cap(6)).toBe(140)
		expect(SpawnRules.cap(0)).toBe(80)
	end)

	it("grows HP and damage faster and faster", function()
		expect(SpawnRules.hpFactor(0)).toBeNear(1)
		expect(SpawnRules.hpFactor(4)).toBeNear(1.4)
		expect(SpawnRules.hpFactor(12)).toBeNear(3.8)
		local early = SpawnRules.hpFactor(2) - SpawnRules.hpFactor(0)
		local late = SpawnRules.hpFactor(12) - SpawnRules.hpFactor(10)
		expect(late > early * 3).toBe(true)
		expect(SpawnRules.damageFactor(0)).toBeNear(1)
		expect(SpawnRules.damageFactor(12)).toBeNear(1.25)
	end)

	it("brings something new into the mix almost every minute", function()
		expect(SpawnRules.mixAt(1.9).Brute).toBe(nil)
		expect(SpawnRules.mixAt(2).Brute).toBeNear(0.2)
		expect(SpawnRules.mixAt(2.99).Charger).toBe(nil)
		expect(SpawnRules.mixAt(3).Charger).toBeNear(0.12)
		expect(SpawnRules.mixAt(3.99).Spitter).toBe(nil)
		expect(SpawnRules.mixAt(4).Spitter).toBeNear(0.1) -- 0.2 in the original design, halved in WP9
		expect(SpawnRules.mixAt(6).AbyssShadeling).toBeNear(0.2)
		expect(SpawnRules.mixAt(7).Splitter).toBeNear(0.13)
		expect(SpawnRules.mixAt(8).AbyssBrute).toBeNear(0.1)
		expect(SpawnRules.mixAt(11).Shadeling).toBe(nil) -- only the stronger kinds late in the run
		expect(SpawnRules.mixAt(11).Splitling).toBe(nil) -- Splitlings come only from Splitters
	end)

	it("picks enemies by weight", function()
		local weights = SpawnRules.mixAt(4.5)
		local counts = { Shadeling = 0, Brute = 0, Charger = 0, Spitter = 0 }
		for i = 0, 999 do
			local id = SpawnRules.pickEnemy(weights, i / 1000)
			counts[id] += 1
		end
		expect(counts.Shadeling).toBeNear(620, 1)
		expect(counts.Brute).toBeNear(160, 1)
		expect(counts.Charger).toBeNear(120, 1)
		expect(counts.Spitter).toBeNear(100, 1)
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

	it("runs Swarm Rush at minute 5 and 9 for 30 s with double rate and Shadelings only", function()
		expect(SpawnRules.isSwarmRush(4.99)).toBe(false)
		expect(SpawnRules.isSwarmRush(5)).toBe(true)
		expect(SpawnRules.isSwarmRush(5.49)).toBe(true)
		expect(SpawnRules.isSwarmRush(5.5)).toBe(false)
		expect(SpawnRules.isSwarmRush(9.2)).toBe(true)
		local intensity = RunSchedule.intensity(5.2 * 60)
		expect(SpawnRules.currentRate(5.2, 1)).toBeNear(SpawnRules.rate(5.2, 1) * intensity * 2)
		expect(SpawnRules.currentRate(6, 1)).toBeNear(SpawnRules.rate(6, 1) * RunSchedule.intensity(360))
		expect(SpawnRules.currentMix(5.2).Shadeling).toBe(1)
		expect(SpawnRules.currentMix(5.2).Brute).toBe(nil)
		expect(SpawnRules.currentMix(6).Spitter).toBeNear(0.1)
		expect(SpawnRules.swarmRushStarted(4.9, 5)).toBe(true)
		expect(SpawnRules.swarmRushStarted(5, 5.1)).toBe(false)
		expect(SpawnRules.swarmRushStarted(0, 11.8)).toBe(true)
	end)

	it("calls elites at 2:00 and every 2 minutes after, two at 6:00 and 10:00", function()
		expect(SpawnRules.elitesDue(0, 1.99)).toBe(0)
		expect(SpawnRules.elitesDue(1.99, 2)).toBe(1)
		expect(SpawnRules.elitesDue(2, 2.1)).toBe(0)
		expect(SpawnRules.elitesDue(3.9, 4.05)).toBe(1)
		expect(SpawnRules.elitesDue(4.05, 5.9)).toBe(0)
		expect(SpawnRules.elitesDue(5.9, 6)).toBe(2)
		expect(SpawnRules.elitesDue(9.9, 10)).toBe(2)
		expect(SpawnRules.elitesDue(1.5, 4.5)).toBe(2) -- skipped minutes still bring them
		expect(SpawnRules.affixesAt(4)).toBe(false) -- the first elites are plain ones
		expect(SpawnRules.affixesAt(6)).toBe(true)
	end)

	it("spawns part of the enemies in front of a walking player", function()
		local share = Config.Run.spawn.ahead.share
		expect(SpawnRules.aheadHeading(16, 0, share / 2)).toBeNear(0)
		expect(SpawnRules.aheadHeading(0, 16, share / 2)).toBeNear(math.pi / 2)
		expect(SpawnRules.aheadHeading(16, 0, (share + 1) / 2)).toBe(nil)
		expect(SpawnRules.aheadHeading(0.5, 0, 0)).toBe(nil) -- standing still
		local halfAngle = math.rad(Config.Run.spawn.ahead.halfAngleDegrees)
		local state = 7
		local function random()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		for _ = 1, 50 do
			local x, z = SpawnRules.findSpawnPoint(random, 0, 0, 1.5, bounds, {}, 12, 0)
			expect(x ~= nil).toBe(true)
			if x and z then
				expect(math.abs(math.atan2(z, x)) <= halfAngle + 1e-6).toBe(true)
			end
		end
	end)

	it("spreads the Swarm Rush ring evenly", function()
		local x1, z1 = SpawnRules.ringPoint(1, 4, 10, 10, 45)
		local x2, z2 = SpawnRules.ringPoint(2, 4, 10, 10, 45)
		expect(x1).toBeNear(55)
		expect(z1).toBeNear(10)
		expect(x2).toBeNear(10)
		expect(z2).toBeNear(55)
	end)
end)
