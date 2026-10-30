-- Unit tests for the spawn formulas (SpawnDirector/SpawnRules) and the run's timeline (Util/RunSchedule) against
-- the numbers in DESIGN.md section 7.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RunSchedule = require(game:GetService("ReplicatedStorage").Shared.Util.RunSchedule)
local SpawnRules = require(game:GetService("ServerScriptService").Server.Services.SpawnDirector.SpawnRules)

local bounds = { minX = -150, maxX = 150, minZ = -150, maxZ = 150 }

describe("SpawnRules", function()
	it("matches the design's player factors and spawns more enemies wave by wave", function()
		expect(SpawnRules.playerFactor(1)).toBeNear(1)
		expect(SpawnRules.playerFactor(2)).toBeNear(1.6)
		expect(SpawnRules.playerFactor(4)).toBeNear(2.8)
		local function base(minutes)
			return SpawnRules.currentRate(minutes, 1) / RunSchedule.intensity(minutes)
		end
		expect(base(0.5)).toBeNear(1.6) -- wave 1: a group of 4 Shadelings every 2.5 s
		expect(base(14.5)).toBeNear(8.59, 0.01)
		expect(SpawnRules.currentRate(14.5, 4)).toBeNear(SpawnRules.currentRate(14.5, 1) * 2.8)
		local previous = 0
		for wave = 1, 20 do
			local minutes = wave - 0.5
			if not SpawnRules.isSwarmRush(wave - 1) then
				expect(base(minutes) > previous).toBe(true)
				previous = base(minutes)
			end
		end
		expect(SpawnRules.waveAt(0)).toBe(1)
		expect(SpawnRules.waveAt(19.9)).toBe(20)
		expect(SpawnRules.waveAt(25)).toBe(20)
	end)

	it("fires each group after a share of its interval and spreads it around one spot", function()
		local group = Config.Run.spawn.groups[1].groups[1]
		expect(SpawnRules.firstFiring(group)).toBeNear(group.every * Config.Run.spawn.firstShare)
		expect(SpawnRules.groupSize(group, 0, 1)).toBeNear(group.size * Config.Run.spawn.waves.rampFrom)
		expect(SpawnRules.groupSize(group, 0, 2)).toBeNear(group.size * Config.Run.spawn.waves.rampFrom * 1.6)
		local state = 5
		local function random()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		local reach = Config.Run.spawn.groupSpread * math.sqrt(9)
		for _ = 1, 100 do
			local dx, dz = SpawnRules.groupOffset(random, 9)
			expect(math.sqrt(dx * dx + dz * dz) <= reach + 1e-6).toBe(true)
		end
	end)

	it("reads keyframe curves linearly between points", function()
		local curve = { { 0, 1 }, { 2, 3 }, { 4, 3 } }
		expect(RunSchedule.curve(curve, -1)).toBeNear(1)
		expect(RunSchedule.curve(curve, 1)).toBeNear(2)
		expect(RunSchedule.curve(curve, 3)).toBeNear(3)
		expect(RunSchedule.curve(curve, 9)).toBeNear(3)
	end)

	it("runs Brotato's 20 waves from 20 s up to 60 s, the last one 90 s, that ramp up, the last one harder", function()
		local waves = Config.Run.spawn.waves
		local first = RunSchedule.waveAt(0)
		expect(first.number).toBe(1)
		expect(first.count).toBe(20)
		expect(first.endsAt).toBe(20)
		expect(RunSchedule.waveAt(19.9).number).toBe(1)
		expect(RunSchedule.waveAt(20).number).toBe(2) -- a wave's end belongs to the next wave
		expect(RunSchedule.wave(2).endsAt).toBe(45)
		expect(RunSchedule.wave(9).endsAt - RunSchedule.wave(9).startsAt).toBe(60)
		expect(RunSchedule.wave(19).endsAt - RunSchedule.wave(19).startsAt).toBe(60)
		expect(RunSchedule.wave(20).endsAt - RunSchedule.wave(20).startsAt).toBe(90)
		expect(RunSchedule.wave(20).endsAt).toBe(Config.Run.durationSeconds)
		expect(Config.Run.durationSeconds).toBe(1050)
		expect(RunSchedule.intensity(0)).toBeNear(waves.rampFrom)
		expect(RunSchedule.intensity(0.999)).toBeNear(waves.rampTo, 1e-2)
		expect(RunSchedule.intensity(1)).toBeNear(waves.rampFrom) -- wave 2 starts calm again
		local final = RunSchedule.waveAt(1040)
		expect(final.number).toBe(20)
		expect(final.final).toBe(true)
		expect(RunSchedule.wave(19).final).toBe(false)
		expect(RunSchedule.intensity(19.9) > waves.rampTo).toBe(true)
		expect(RunSchedule.waveAt(1400).number).toBe(20) -- after the run stays in the last wave
	end)

	it("turns fighting seconds into one schedule minute per wave", function()
		expect(RunSchedule.minutesAt(0)).toBeNear(0)
		expect(RunSchedule.minutesAt(10)).toBeNear(0.5) -- halfway through the 20 s wave 1
		expect(RunSchedule.minutesAt(20)).toBeNear(1)
		expect(RunSchedule.minutesAt(32.5)).toBeNear(1.5)
		expect(RunSchedule.minutesAt(540)).toBeNear(12)
		expect(RunSchedule.minutesAt(1005)).toBeNear(19.5) -- halfway through the 90 s wave 20
		expect(RunSchedule.minutesAt(1400)).toBeNear(20)
	end)

	it("names what each wave brings on its banner", function()
		expect(#RunSchedule.eventsOf(1)).toBe(0)
		expect(table.concat(RunSchedule.eventsOf(3), "|")).toBe("New: Brutes|A Gloom Elite!")
		expect(table.concat(RunSchedule.eventsOf(6), "|")).toBe("New: Spitters|A Gloom Elite!")
		expect(table.concat(RunSchedule.eventsOf(7), "|")).toBe("Swarm Rush!")
		expect(table.concat(RunSchedule.eventsOf(11), "|")).toBe("New: Splitters, Reapers|2 Gloom Elites!")
		expect(table.concat(RunSchedule.eventsOf(20), "|")).toBe("Final wave")
	end)

	it("caps alive enemies at 80 + 20 per extra player, at most 140", function()
		expect(SpawnRules.cap(1)).toBe(80)
		expect(SpawnRules.cap(2)).toBe(100)
		expect(SpawnRules.cap(4)).toBe(140)
		expect(SpawnRules.cap(6)).toBe(140)
		expect(SpawnRules.cap(0)).toBe(80)
	end)

	it("grows HP and damage of every kind by its own amount per growth step", function()
		local shadeling = Config.Enemies.types.Shadeling
		local hp, damage = SpawnRules.growth("Shadeling", 1)
		expect(hp).toBeNear(1)
		expect(damage).toBeNear(1)
		local steps = Config.Run.spawn.growth
		hp, damage = SpawnRules.growth("Shadeling", 20)
		expect(hp * shadeling.hp).toBeNear(shadeling.hp + steps.hpSteps[20] * shadeling.hpPerWave)
		expect(damage * shadeling.contactDamage).toBeNear(
			shadeling.contactDamage + steps.damageSteps[20] * shadeling.damagePerWave
		)
		expect(hp > 12).toBe(true) -- at least about the 14x of the curve before B9
		expect(SpawnRules.growth("Shadeling", 5) < 2).toBe(true) -- few steps early, many late
		-- a Spitter's growth counts on its shots
		local spitter = Config.Enemies.types.Spitter
		local _, shots = SpawnRules.growth("Spitter", 11)
		expect(shots * spitter.ranged.projectileDamage).toBeNear(
			spitter.ranged.projectileDamage + steps.damageSteps[11] * spitter.damagePerWave
		)
		local _, tree = SpawnRules.growth("Tree", 20)
		expect(tree).toBe(1) -- no damage to grow
		expect(SpawnRules.growth("Nobody", 5)).toBe(1)
	end)

	it("brings something new every few waves", function()
		expect(SpawnRules.mixAt(1.9).Brute).toBe(nil)
		expect(SpawnRules.mixAt(2).Brute ~= nil).toBe(true)
		expect(SpawnRules.mixAt(3.99).Charger).toBe(nil)
		expect(SpawnRules.mixAt(4).Charger ~= nil).toBe(true)
		expect(SpawnRules.mixAt(4.99).Spitter).toBe(nil)
		expect(SpawnRules.mixAt(5).Spitter ~= nil).toBe(true)
		expect(SpawnRules.mixAt(8).AbyssShadeling ~= nil).toBe(true)
		expect(SpawnRules.mixAt(10).Splitter ~= nil).toBe(true)
		expect(SpawnRules.mixAt(12).AbyssBrute ~= nil).toBe(true)
		expect(SpawnRules.mixAt(15).Shadeling).toBe(nil) -- only the stronger kinds late in the run
		expect(SpawnRules.mixAt(15).Splitling).toBe(nil) -- Splitlings come only from Splitters
	end)

	it("picks enemies by weight", function()
		local weights = { Shadeling = 0.6, Brute = 0.3, Spitter = 0.1 }
		local counts = { Shadeling = 0, Brute = 0, Spitter = 0 }
		for i = 0, 999 do
			local id = SpawnRules.pickEnemy(weights, i / 1000)
			counts[id] += 1
		end
		expect(counts.Shadeling).toBeNear(600, 1)
		expect(counts.Brute).toBeNear(300, 1)
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

	it("runs Swarm Rush in waves 7, 12 and 17 for 60 % of the wave with double rate and Shadelings only", function()
		expect(SpawnRules.isSwarmRush(5.99)).toBe(false)
		expect(SpawnRules.isSwarmRush(6)).toBe(true)
		expect(SpawnRules.isSwarmRush(6.59)).toBe(true)
		expect(SpawnRules.isSwarmRush(6.6)).toBe(false)
		expect(SpawnRules.isSwarmRush(11.2)).toBe(true)
		expect(SpawnRules.isSwarmRush(16.2)).toBe(true)
		local intensity = RunSchedule.intensity(6.2)
		local ownRate = 0
		for _, group in Config.Run.spawn.groups[7].groups do
			ownRate += group.size / group.every
		end
		expect(SpawnRules.currentRate(6.2, 1)).toBeNear(ownRate * intensity * 2)
		expect(#SpawnRules.groupsAt(6.2)).toBe(1)
		expect(SpawnRules.groupsAt(6.2)[1].enemy).toBe("Shadeling")
		expect(SpawnRules.groupsAt(6.2)).toBe(SpawnRules.groupsAt(6.3)) -- the same groups all through the rush
		expect(SpawnRules.groupsAt(6.7)).toBe(Config.Run.spawn.groups[7].groups)
		expect(SpawnRules.mixAt(6.2).Brute).toBe(nil)
		expect(SpawnRules.mixAt(7).Spitter ~= nil).toBe(true)
		expect(SpawnRules.swarmRushStarted(5.9, 6)).toBe(true)
		expect(SpawnRules.swarmRushStarted(6, 6.1)).toBe(false)
		expect(SpawnRules.swarmRushStarted(0, 19.8)).toBe(true)
	end)

	it("calls elites in waves 3, 6, 9, 11, 13, 15, 17 and 19, two from wave 11 on (except 13)", function()
		expect(SpawnRules.elitesDue(0, 1.99)).toBe(0)
		expect(SpawnRules.elitesDue(1.99, 2)).toBe(1)
		expect(SpawnRules.elitesDue(2, 2.1)).toBe(0)
		expect(SpawnRules.elitesDue(4.9, 5.05)).toBe(1)
		expect(SpawnRules.elitesDue(5.05, 7.9)).toBe(0)
		expect(SpawnRules.elitesDue(9.9, 10)).toBe(2)
		expect(SpawnRules.elitesDue(17.9, 18)).toBe(2)
		expect(SpawnRules.elitesDue(1.5, 5.5)).toBe(2) -- skipped minutes still bring them
		expect(SpawnRules.affixesAt(5)).toBe(false) -- the first elites are plain ones
		expect(SpawnRules.affixesAt(8)).toBe(true)
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
