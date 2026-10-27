--!strict
-- The run's timeline from Config.Run.spawn as pure functions (DESIGN.md section 7): keyframe curves, waves with
-- their breathers and the events each wave starts with. Shared, so the server spawns by it (SpawnDirector/SpawnRules)
-- and the HUD shows the same waves without a remote. Tested in tests/SpawnRules.spec.luau.

local Run = require(script.Parent.Parent.Config.Run)

local Spawn = Run.spawn
local Waves = Spawn.waves

export type Curve = { { number } } -- keyframes { minute, value }, sorted by minute

export type Wave = {
	number: number, -- 1 for the first minute
	count: number, -- waves in a run
	startsAt: number, -- run seconds
	endsAt: number, -- run seconds, when the next wave starts
	breather: boolean, -- in the calm part at the end of the wave
	final: boolean, -- the last wave before the boss
}

local RunSchedule = {}

local WAVE_COUNT = math.max(1, math.ceil(Run.durationSeconds / Waves.lengthSeconds))

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

-- The wave at run time `seconds`.
function RunSchedule.waveAt(seconds: number): Wave
	local length = Waves.lengthSeconds
	local number = math.clamp(math.floor(math.max(seconds, 0) / length) + 1, 1, WAVE_COUNT)
	local startsAt = (number - 1) * length
	local final = number == WAVE_COUNT
	return {
		number = number,
		count = WAVE_COUNT,
		startsAt = startsAt,
		endsAt = startsAt + length,
		breather = not final and seconds >= startsAt + length - Waves.breatherSeconds,
		final = final,
	}
end

-- Multiplier on the spawn rate at run time `seconds`: ramps through the wave, low in its breather, higher in the
-- final wave.
function RunSchedule.intensity(seconds: number): number
	local wave = RunSchedule.waveAt(seconds)
	if wave.breather then
		return Waves.breatherRate
	end
	local rampSeconds = Waves.lengthSeconds - (if wave.final then 0 else Waves.breatherSeconds)
	local t = math.clamp((seconds - wave.startsAt) / rampSeconds, 0, 1)
	local ramp = Waves.rampFrom + (Waves.rampTo - Waves.rampFrom) * t
	return if wave.final then ramp * Waves.finalRate else ramp
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
function RunSchedule.eventsOf(number: number): { string }
	local minute = (number - 1) * Waves.lengthSeconds / 60
	local events = {}
	for _, entry in Spawn.mix do
		local announce = (entry :: any).announce :: string?
		if announce and entry.fromMinute == minute then
			table.insert(events, `New: {announce}`)
		end
	end
	for _, start in Spawn.swarmRush.atMinutes do
		if start == minute then
			table.insert(events, "Swarm Rush!")
		end
	end
	local elites = RunSchedule.elitesDue(minute - 1e-6, minute)
	if elites > 1 then
		table.insert(events, `{elites} Gloom Elites!`)
	elseif elites == 1 then
		table.insert(events, "A Gloom Elite!")
	end
	if number == WAVE_COUNT then
		table.insert(events, "Final wave")
	end
	return events
end

return RunSchedule
