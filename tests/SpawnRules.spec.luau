-- Unit tests for the spawn formulas (SpawnDirector/SpawnRules) and the run's timeline (Util/RunSchedule) against
-- the numbers in DESIGN.md section 7.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RunSchedule = require(game:GetService("ReplicatedStorage").Shared.Util.RunSchedule)
local SpawnRules = require(game:GetService("ServerScriptService").Server.Services.SpawnDirector.SpawnRules)

local bounds = { minX = -150, maxX = 150, minZ = -150, maxZ = 150 }

describe("SpawnRules", function()
	it("uses Brotato's co-op factors and wave lookup", function()
		expect(SpawnRules.coopEnemies(1)).toBeNear(0)
		expect(SpawnRules.coopEnemies(4)).toBeNear(0.9) -- +30 % enemies per extra player
		expect(SpawnRules.coopHealth(2)).toBeNear(1.3)
		expect(SpawnRules.coopDamage(4)).toBeNear(1.24) -- +8 % damage per extra player
		expect(SpawnRules.waveAt(0)).toBe(1)
		expect(SpawnRules.waveAt(19.9)).toBe(20)
		expect(SpawnRules.waveAt(25)).toBe(20)
	end)

	it("runs wave 1's group like Brotato: 4-5 Shadelings at 1 s, then every 3 s", function()
		local groups = SpawnRules.groupsFor(1, 0)
		local main = groups[1]
		expect(main.units[1].enemy).toBe("Shadeling")
		local timers = SpawnRules.newTimers({ main })
		local fired = {}
		for second = 0, 19 do
			if #SpawnRules.due(timers, second, function()
				return 0
			end) > 0 then
				table.insert(fired, second)
			end
		end
		expect(table.concat(fired, ",")).toBe("1,4,7,10,13,16,19")
		-- every wave also brings Brotato's trees, Looter and Gobbler groups
		local kinds = {}
		for _, group in groups do
			for _, unit in group.units do
				kinds[unit.enemy or "?"] = true
			end
		end
		expect(kinds.Tree and kinds.Looter and kinds.Gobbler).toBe(true)
	end)

	it("lets a missed first roll still start the repeats and shrinks intervals to their minimum", function()
		local group = table.freeze({
			timing = 2,
			repeating = 3,
			interval = 5,
			reduceInterval = 2,
			minInterval = 2,
			chance = 0.5,
			units = {},
		}) :: any
		local timers = SpawnRules.newTimers({ group })
		local fired = {}
		for second = 0, 30 do
			if
				#SpawnRules.due(timers, second, function()
					return 0.9 -- the first roll misses
				end) > 0
			then
				table.insert(fired, second)
			end
		end
		-- next = 2 + 5 = 7; then interval 3 -> 10; then interval 2 (minimum) -> 12; repeats used up
		expect(table.concat(fired, ",")).toBe("7,10,12")
	end)

	it("counts units with co-op, the Enemies stat, Trees and the leftover chance", function()
		local group = { loot = false } :: any
		local unit = { min = 4, max = 5, chance = 1, neutral = false } :: any
		expect(SpawnRules.unitCount(unit, group, 1, 0, 0, 1, 0, 0.99)).toBe(4)
		expect(SpawnRules.unitCount(unit, group, 1, 0, 0, 1, 0.99, 0.99)).toBe(5)
		-- 2 players: 4 * 1.3 = 5.2 -> 5, plus one more 20 % of the time
		expect(SpawnRules.unitCount(unit, group, 2, 0, 0, 1, 0, 0.1)).toBe(6)
		expect(SpawnRules.unitCount(unit, group, 2, 0, 0, 1, 0, 0.3)).toBe(5)
		-- Enemies -100 % still brings at least one
		expect(SpawnRules.unitCount(unit, group, 1, -100, 0, 1, 0, 0.99)).toBe(1)
		-- loot groups ignore co-op and the Enemies stat
		expect(SpawnRules.unitCount(unit, { loot = true } :: any, 4, 50, 0, 1, 0, 0.99)).toBe(4)
		-- trees add the Trees stat, then roll their chance
		local tree = { min = 1, max = 2, chance = 0.33, neutral = true } :: any
		expect(SpawnRules.unitCount(tree, group, 1, 0, 2, 1, 0, 0.995)).toBe(0) -- 3 * 0.33 = 0.99
		expect(SpawnRules.unitCount(tree, group, 1, 0, 2, 1, 0, 0.5)).toBe(1)
	end)

	it("speeds up the spawn queue from 100 waiting enemies on", function()
		expect(SpawnRules.queueBurst(5)).toBe(1)
		expect(SpawnRules.queueBurst(115)).toBe(1)
		expect(SpawnRules.queueBurst(125)).toBe(2)
		expect(SpawnRules.queueBurst(400)).toBe(2)
	end)

	it("keeps groups apart from players and units inside the arena", function()
		local seed = 11
		local function random()
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		local players = { Vector3.new(0, 0, 0) }
		local main = SpawnRules.groupsFor(1, 0)[1]
		local need = SpawnRules.studs(Config.Run.spawn.layout.minPlayerDistance)
		for _ = 1, 200 do
			local gx, gz = SpawnRules.groupPoint(random, bounds, main, players)
			local x, z = SpawnRules.enemyPoint(random, bounds, main, main.units[1], gx, gz, players)
			expect(x >= bounds.minX and x <= bounds.maxX and z >= bounds.minZ and z <= bounds.maxZ).toBe(true)
			expect(math.sqrt(SpawnRules.closestSquared(players, x, z)) >= need - 1e-6).toBe(true)
		end
	end)

	it("reads keyframe curves linearly between points", function()
		local curve = { { 0, 1 }, { 2, 3 }, { 4, 3 } }
		expect(RunSchedule.curve(curve, -1)).toBeNear(1)
		expect(RunSchedule.curve(curve, 1)).toBeNear(2)
		expect(RunSchedule.curve(curve, 3)).toBeNear(3)
		expect(RunSchedule.curve(curve, 9)).toBeNear(3)
	end)

	it("runs Brotato's 20 waves from 20 s up to 60 s, the last one 90 s, the last one harder", function()
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
		local final = RunSchedule.waveAt(1040)
		expect(final.number).toBe(20)
		expect(final.final).toBe(true)
		expect(RunSchedule.wave(19).final).toBe(false)
		-- B11: past the run's end the endless waves follow (60 s each, every 10th a 90 s boss wave)
		expect(RunSchedule.waveAt(1400).number).toBe(26)
		expect(RunSchedule.wave(21).startsAt).toBe(1050)
		expect(RunSchedule.wave(21).endless).toBe(true)
		expect(RunSchedule.wave(30).boss).toBe(true)
		expect(RunSchedule.wave(30).endsAt - RunSchedule.wave(30).startsAt).toBe(90)
		expect(RunSchedule.wave(31).startsAt).toBe(1050 + 9 * 60 + 90)
		expect(RunSchedule.wave(20).boss).toBe(true)
		expect(RunSchedule.wave(29).boss).toBe(false)
	end)

	it("turns fighting seconds into one schedule minute per wave", function()
		expect(RunSchedule.minutesAt(0)).toBeNear(0)
		expect(RunSchedule.minutesAt(10)).toBeNear(0.5) -- halfway through the 20 s wave 1
		expect(RunSchedule.minutesAt(20)).toBeNear(1)
		expect(RunSchedule.minutesAt(32.5)).toBeNear(1.5)
		expect(RunSchedule.minutesAt(540)).toBeNear(12)
		expect(RunSchedule.minutesAt(1005)).toBeNear(19.5) -- halfway through the 90 s wave 20
		expect(RunSchedule.minutesAt(1400)).toBeNear(25 + 50 / 60) -- endless wave 26 (B11)
	end)

	it("names the first appearances of Brotato's wave data for the selected danger", function()
		expect(#RunSchedule.eventsOf(1)).toBe(0)
		expect(table.concat(RunSchedule.eventsOf(3), "|")).toBe("New: Charger, Thornback")
		expect(table.concat(RunSchedule.eventsOf(4, 0), "|")).toBe("New: Spitter")
		expect(table.concat(RunSchedule.eventsOf(6, 0), "|")).toBe("New: Charger") -- wave 3 only from danger 1
		expect(table.concat(RunSchedule.eventsOf(11, 0), "|")).toBe("New: Stalker")
		expect(table.concat(RunSchedule.eventsOf(20), "|")).toBe("Final wave")
		expect(table.concat(RunSchedule.eventsOf(20, 6), "|")).toBe("New: Mad Slasher|Final wave")
		expect(table.concat(RunSchedule.eventsOf(30), "|")).toBe("Boss wave")
	end)

	it("keeps Brotato's enemy maximum: 100 + 1/8 of it per extra player", function()
		expect(SpawnRules.cap(1)).toBe(100)
		expect(SpawnRules.cap(2)).toBe(112)
		expect(SpawnRules.cap(4)).toBe(137)
		expect(SpawnRules.cap(0)).toBe(100)
		expect(SpawnRules.cap(4) <= Config.Run.spawn.cap.max).toBe(true)
	end)

	it("grows HP and damage of every kind by its own amount per growth step", function()
		local shadeling = Config.Enemies.types.Shadeling
		local steps = Config.Run.spawn.growth
		local scale = steps.damageScale or 1 -- playtest after Paket 24: normal enemies hit harder
		local hp, damage = SpawnRules.growth("Shadeling", 1)
		expect(hp).toBeNear(1)
		expect(damage).toBeNear(scale)
		hp, damage = SpawnRules.growth("Shadeling", 20)
		expect(hp * shadeling.hp).toBeNear(shadeling.hp + steps.hpSteps[20] * shadeling.hpPerWave)
		expect(damage * shadeling.contactDamage).toBeNear(
			scale * (shadeling.contactDamage + steps.damageSteps[20] * shadeling.damagePerWave)
		)
		expect(hp > 12).toBe(true) -- at least about the 14x of the curve before B9
		expect(SpawnRules.growth("Shadeling", 5)).toBeNear(11 / 3) -- 3 base + 4 * 2 HP
		-- a Spitter's growth counts on its shots
		local spitter = Config.Enemies.types.Spitter
		local _, _, shots = SpawnRules.growth("Spitter", 11)
		expect(shots * spitter.ranged.projectileDamage).toBeNear(
			scale * (spitter.ranged.projectileDamage + steps.damageSteps[11] * spitter.shotDamagePerWave)
		)
		local _, tree = SpawnRules.growth("Tree", 20)
		expect(tree).toBe(scale) -- no damage to grow, only the scale
		local _, champion = SpawnRules.growth("BrassRam", 1)
		expect(champion).toBeNear(1) -- champions keep their own numbers
		expect(SpawnRules.growth("Nobody", 5)).toBe(1)
	end)

	it("introduces the main-game kinds at their wiki waves", function()
		expect(SpawnRules.mixAt(6.9).Brute).toBe(nil)
		expect(SpawnRules.mixAt(7.7).Brute ~= nil).toBe(true)
		expect(SpawnRules.mixAt(1.9).Charger).toBe(nil)
		expect(SpawnRules.mixAt(2.7).Charger ~= nil).toBe(true)
		expect(SpawnRules.mixAt(2.99).Spitter).toBe(nil)
		expect(SpawnRules.mixAt(3.7).Spitter ~= nil).toBe(true)
		expect(SpawnRules.mixAt(13.7).Splitter ~= nil).toBe(true)
		expect(SpawnRules.mixAt(12.7).AbyssBrute ~= nil).toBe(true)
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
end)
