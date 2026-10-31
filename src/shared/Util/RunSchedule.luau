--!strict
-- The run's timeline from Config.Run.spawn as pure functions (DESIGN.md section 7): keyframe curves, waves of
-- different lengths, schedule minutes and the events each wave starts with. Shared, so the server spawns by it (SpawnDirector/SpawnRules)
-- and the HUD shows the same waves without a remote. Tested in tests/SpawnRules.spec.luau.

local Run = require(script.Parent.Parent.Config.Run)
local Difficulty = require(script.Parent.Parent.Config.Difficulty)

local Spawn = Run.spawn
local Waves = Spawn.waves

export type Curve = { { number } } -- keyframes { minute, value }, sorted by minute

export type Wave = {
	number: number, -- 1 for the first wave
	count: number, -- waves in a run
	startsAt: number, -- fighting seconds (the clock stops in the shop between waves)
	endsAt: number, -- fighting seconds, when the shop opens (or the boss comes after the final wave)
	final: boolean, -- the boss wave that ends a run (wave 20)
	endless: boolean, -- B11: a wave after the final one (endless mode)
	boss: boolean, -- B11: wave 20 and every Difficulty.endless.bossEvery waves after it
}

local RunSchedule = {}

local LENGTHS = Waves.lengthsSeconds
local WAVE_COUNT = #LENGTHS
local STARTS: { number } = {}
local TOTAL = 0
do
	for index, length in LENGTHS do
		STARTS[index] = TOTAL
		TOTAL += length
	end
end
local Endless = Difficulty.endless

local function isEndlessBoss(number: number): boolean
	return number > WAVE_COUNT and (number - WAVE_COUNT) % Endless.bossEvery == 0
end

-- Endless wave `number` (> WAVE_COUNT): starts after the run's waves and the endless waves before it (B11).
local function endlessWave(number: number): Wave
	local before = number - WAVE_COUNT - 1
	local bossesBefore = math.floor(before / Endless.bossEvery)
	local startsAt = TOTAL
		+ before * Endless.waveSeconds
		+ bossesBefore * (Endless.bossWaveSeconds - Endless.waveSeconds)
	local boss = isEndlessBoss(number)
	return {
		number = number,
		count = WAVE_COUNT,
		startsAt = startsAt,
		endsAt = startsAt + if boss then Endless.bossWaveSeconds else Endless.waveSeconds,
		final = false,
		endless = true,
		boss = boss,
	}
end

-- Value of a keyframe curve at `minutes`: linear between keyframes, flat before the first and after the last.
function RunSchedule.curve(curve: Curve, minutes: number): number
	local first = curve[1]
	if minutes <= first[1] then
		return first[2]
	end
	for k = 2, #curve do
		local point = curve[k]
		if minutes <= point[1] then
			local previous = curve[k - 1]
			local span = point[1] - previous[1]
			local t = if span > 0 then (minutes - previous[1]) / span else 1
			return previous[2] + (point[2] - previous[2]) * t
		end
	end
	return curve[#curve][2]
end

-- Number of waves in a run.
function RunSchedule.waveCount(): number
	return WAVE_COUNT
end

-- The wave with this number (at least 1); past the run's waves the endless ones (B11).
function RunSchedule.wave(number: number): Wave
	if number > WAVE_COUNT then
		return endlessWave(math.floor(number))
	end
	local n = math.max(number, 1)
	return {
		number = n,
		count = WAVE_COUNT,
		startsAt = STARTS[n],
		endsAt = STARTS[n] + LENGTHS[n],
		final = n == WAVE_COUNT,
		endless = false,
		boss = n == WAVE_COUNT,
	}
end

-- The wave at `seconds` of fighting time; a wave's end belongs to the next wave. Past the run's waves the endless
-- ones (B11).
function RunSchedule.waveAt(seconds: number): Wave
	if seconds >= TOTAL then
		local number = WAVE_COUNT + 1
		while RunSchedule.wave(number).endsAt <= seconds do
			number += 1
		end
		return RunSchedule.wave(number)
	end
	local number = 1
	for index = WAVE_COUNT, 1, -1 do
		if seconds >= STARTS[index] then
			number = index
			break
		end
	end
	return RunSchedule.wave(number)
end

-- Fighting seconds turned into schedule minutes (one per wave, see Config.Run.spawn): wave n runs from n - 1 to n.
function RunSchedule.minutesAt(seconds: number): number
	local wave = RunSchedule.waveAt(seconds)
	local length = wave.endsAt - wave.startsAt
	return wave.number - 1 + math.clamp((seconds - wave.startsAt) / length, 0, 1)
end

-- Multiplier on the spawn rate at schedule minute `minutes`: ramps through the wave, higher in the final wave.
function RunSchedule.intensity(minutes: number): number
	local number = math.clamp(math.floor(minutes) + 1, 1, WAVE_COUNT)
	local t = math.clamp(minutes - (number - 1), 0, 1)
	local ramp = Waves.rampFrom + (Waves.rampTo - Waves.rampFrom) * t
	return if number == WAVE_COUNT then ramp * Waves.finalRate else ramp
end

-- Elites called at run time in (fromMinutes, toMinutes].
function RunSchedule.elitesDue(fromMinutes: number, toMinutes: number): number
	local count = 0
	for _, entry in Spawn.elites.waves do
		if fromMinutes < entry.atMinute and entry.atMinute <= toMinutes then
			count += entry.count
		end
	end
	return count
end

-- What the wave with this number brings, for its banner: new enemies, Swarm Rush, elites. Empty for none.
-- `danger` (B11, default 5) leaves out the kinds that come from danger 1 and the Gloom Elites where they are off.
function RunSchedule.eventsOf(number: number, danger: number?): { string }
	local minute = number - 1
	local events = {}
	local level = Difficulty.levels[math.clamp(danger or #Difficulty.levels - 1, 0, #Difficulty.levels - 1) + 1]
	local entry = Spawn.groups[number]
	if entry and entry.announce then
		local names = {}
		for _, item in entry.announce do
			if level.newEnemies or not table.find(Difficulty.newEnemies, item.enemy) then
				table.insert(names, item.name)
			end
		end
		if #names > 0 then
			table.insert(events, `New: {table.concat(names, ", ")}`)
		end
	end
	for _, start in Spawn.swarmRush.atMinutes do
		if start == minute then
			table.insert(events, "Swarm Rush!")
		end
	end
	local elites = if level.gloomElites then RunSchedule.elitesDue(minute - 1e-6, minute) else 0
	if elites > 1 then
		table.insert(events, `{elites} Gloom Elites!`)
	elseif elites == 1 then
		table.insert(events, "A Gloom Elite!")
	end
	if number == WAVE_COUNT then
		table.insert(events, "Final wave")
	elseif isEndlessBoss(number) then
		table.insert(events, "Boss wave")
	end
	return events
end

return RunSchedule
