--!strict
-- Source-derived Nightmare fog/projectile scheduling; the future danger runtime supplies its frozen challenge waves and RNG.
local C = require(script.Parent.Parent.Config.Nightmare)
local Rules = {}
local values: { [string]: number } = {}
for _, effect in C.effects do
	values[effect.key] = effect.value
end
-- Difficulty resources contain final values, including SET inflation10; never add Danger5's previous bonuses.
function Rules.value(key: string): number
	return values[key] or 0
end
-- Native ProgressData stores one best result per character/zone pair, rather than counting repeat wins.
function Rules.unlocked(bestByCharacterZone: { [string]: { [number]: number } }): boolean
	local count = 0
	for _, zones in bestByCharacterZone do
		for _, danger in zones do
			if danger >= C.unlock.danger then
				count += 1
				if count >= C.unlock.characterZoneWins then
					return true
				end
			end
		end
	end
	return false
end
export type Event = { wave: number, kind: string }
export type Plan = { fog: { number }, bullets: { number }, events: { Event }, generated: { [number]: boolean } }
function Rules.new(): Plan
	return { fog = {}, bullets = {}, events = {}, generated = {} }
end
function Rules.generate(
	plan: Plan,
	danger: number,
	baseWave: number,
	challenges: { [number]: boolean },
	constantProjectiles: boolean,
	random: (number, number) -> number
)
	if danger < C.level or plan.generated[baseWave] then
		return
	end
	local rule = C.events
	local pool = {}
	for offset = 1, rule.lastOffset do
		if not challenges[baseWave + offset] then
			table.insert(pool, baseWave + offset)
		end
	end
	local needed = rule.fogPerBlock + (if constantProjectiles then rule.bulletsPerBlock else 0)
	assert(#pool >= needed, "Nightmare challenge occupancy leaves too few original event slots")
	local function draw(choices: { number }, remove: boolean?): number
		local index = random(1, #choices)
		assert(
			index >= 1 and index <= #choices and index == math.floor(index),
			"Nightmare RNG returned an invalid index"
		)
		local wave = choices[index]
		if remove then
			table.remove(choices, index)
		end
		return wave
	end
	local function add(kind: string, wave: number)
		table.insert(if kind == "fog_of_war" then plan.fog else plan.bullets, wave)
		table.insert(plan.events, { wave = wave, kind = kind })
	end
	if baseWave <= rule.firstBlock then
		plan.fog = {}
		local firstFog = draw(rule.earlyFog)
		add("fog_of_war", firstFog)
		if constantProjectiles then
			plan.bullets = {}
			for _, group in rule.earlyBullets do
				local choices = {}
				for _, wave in group do
					if wave ~= firstFog then
						table.insert(choices, wave)
					end
				end
				add("bullet_hell", draw(choices))
			end
		end
	end
	for _ = 1, rule.fogPerBlock do
		add("fog_of_war", draw(pool, true))
	end
	if constantProjectiles then
		for _ = 1, rule.bulletsPerBlock do
			add("bullet_hell", draw(pool, true))
		end
	end
	plan.generated[baseWave] = true
end
return Rules
