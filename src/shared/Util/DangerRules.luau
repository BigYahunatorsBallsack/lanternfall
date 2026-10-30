--!strict
-- Danger level, enemy slider and endless formulas from Config.Difficulty as pure functions (B11): the options a run
-- starts with, the multipliers on enemy HP, damage and speed per wave, which kinds spawn, which waves are elite or
-- horde waves and how many bosses come. Shared, so the server (RunFlow, DangerService, SpawnDirector, BossService)
-- and the lobby and HUD use the same rules. Tested in tests/DangerRules.spec.luau.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Net.Types)

local Difficulty = Config.Difficulty
local Endless = Difficulty.endless
local EliteWaves = Config.Enemies.eliteWaves
local WAVE_COUNT = #Config.Run.spawn.waves.lengthsSeconds

type Level = typeof(Difficulty.levels[1])

local DangerRules = {}

export type Challenge = { kind: "Elite" | "Horde", champions: { string } }

local NEW_ENEMIES: { [string]: boolean } = {}
for _, enemyId in Difficulty.newEnemies do
	NEW_ENEMIES[enemyId] = true
end

-- The level's config (clamped to 0..5).
function DangerRules.level(danger: number): Level
	local levels = Difficulty.levels
	return levels[math.clamp(math.floor(danger), 0, #levels - 1) + 1]
end

function DangerRules.defaultOptions(): Types.RunOptions
	local sliders = Difficulty.sliders
	return {
		danger = Difficulty.defaultLevel,
		endless = false,
		enemyHp = sliders.enemyHp.default,
		enemyDamage = sliders.enemyDamage.default,
		enemySpeed = sliders.enemySpeed.default,
		enemyCount = sliders.enemyCount.default,
	}
end

local function snap(value: number, slider: { min: number, max: number, step: number }): number
	local stepped = slider.min + math.floor((value - slider.min) / slider.step + 0.5) * slider.step
	return math.clamp(stepped, slider.min, slider.max)
end

-- Options with every value in its range and on its slider steps.
function DangerRules.clean(options: Types.RunOptions): Types.RunOptions
	local sliders = Difficulty.sliders
	return {
		danger = math.clamp(math.floor(options.danger), 0, #Difficulty.levels - 1),
		endless = options.endless == true,
		enemyHp = snap(options.enemyHp, sliders.enemyHp),
		enemyDamage = snap(options.enemyDamage, sliders.enemyDamage),
		enemySpeed = snap(options.enemySpeed, sliders.enemySpeed),
		enemyCount = snap(options.enemyCount or sliders.enemyCount.default, sliders.enemyCount),
	}
end

-- Short text for the HUD and results, e.g. "Danger 3 · Endless · HP 150%".
function DangerRules.label(options: Types.RunOptions): string
	local parts = { DangerRules.level(options.danger).displayName }
	if options.endless then
		table.insert(parts, "Endless")
	end
	for _, id in Difficulty.sliderOrder do
		local slider = Difficulty.sliders[id]
		local value = ((options :: any)[id] or slider.default) :: number
		if value ~= slider.default then
			table.insert(parts, `{slider.label} {value}%`)
		end
	end
	return table.concat(parts, " · ")
end

-- Brotato's endless factor for `wave` (0 up to wave 20).
function DangerRules.endlessFactor(wave: number): number
	local w = math.max(0, wave - WAVE_COUNT)
	local mult = Endless.multBase + math.max(0, (wave - Endless.multFromWave) * Endless.multPerWave)
	return w * (w + 1) / 2 / 100 * mult
end

-- Multipliers on the HP, damage and speed of an enemy spawned in `wave`: danger level, sliders and the endless factor
-- (before its own growth and the team's enemy stats).
function DangerRules.multipliers(options: Types.RunOptions, wave: number): (number, number, number)
	local level = DangerRules.level(options.danger)
	local factor = DangerRules.endlessFactor(wave)
	local hp = Difficulty.base.enemyHp * level.enemyHp * options.enemyHp / 100 * (1 + factor * Endless.hpFactor)
	local damage = level.enemyDamage * options.enemyDamage / 100 * (1 + factor)
	local speed = options.enemySpeed / 100 * (1 + math.min(Endless.speedCap, factor / Endless.speedDivisor))
	return hp, damage, speed
end

-- Multiplier on the enemies the spawn groups bring: our base tuning and the Enemy count slider.
function DangerRules.countMultiplier(options: Types.RunOptions): number
	return Difficulty.base.enemyCount * (options.enemyCount or Difficulty.sliders.enemyCount.default) / 100
end

-- True if spawn groups of `enemyId` take part on this danger level.
function DangerRules.spawns(danger: number, enemyId: string): boolean
	return DangerRules.level(danger).newEnemies or not NEW_ENEMIES[enemyId]
end

-- True if the kind only comes from danger 1 on.
function DangerRules.isNewEnemy(enemyId: string): boolean
	return NEW_ENEMIES[enemyId] == true
end

-- True if `wave` is a boss wave: wave 20, and in endless mode every bossEvery waves after it.
function DangerRules.isBossWave(wave: number): boolean
	if wave == WAVE_COUNT then
		return true
	end
	return wave > WAVE_COUNT and (wave - WAVE_COUNT) % Endless.bossEvery == 0
end

-- Bosses in boss wave `wave`: the level's count in wave 20, every boss in the endless ones.
function DangerRules.bossCount(danger: number, wave: number): number
	if wave <= WAVE_COUNT then
		return DangerRules.level(danger).bossCount
	end
	return #Config.Enemies.bossWave.order
end

-- Block of waves: 0 for waves 1-20, 1 for 21-30, 2 for 31-40 ...
function DangerRules.block(wave: number): number
	if wave <= WAVE_COUNT then
		return 0
	end
	return math.ceil((wave - WAVE_COUNT) / Endless.bossEvery)
end

-- Champions that join each elite wave and endless boss wave of `block`.
function DangerRules.championsIn(block: number): number
	return EliteWaves.count + block * Endless.championsPerBlock
end

-- Plans the elite and horde waves of one block (Brotato): one wave of each of the level's first challengeSlots slots
-- (shifted by 10 waves per block after the first), the first two slots a horde with hordeChance in block 0, the
-- rest elite waves. Champions are drawn from `pool` (refilled from eliteWaves.order when empty, so in block 0 none
-- comes twice; afterwards they may repeat). `random(n)` returns an integer 1..n, `roll()` a number in [0, 1).
-- Endless boss waves of the block get champions too (Brotato: "+1 elite to elite and boss waves").
function DangerRules.planBlock(
	danger: number,
	block: number,
	random: (number) -> number,
	roll: () -> number,
	pool: { string }
): { [number]: Challenge }
	local plan: { [number]: Challenge } = {}
	local count = DangerRules.championsIn(block)
	local function draw(): { string }
		local ids = {}
		for _ = 1, count do
			if #pool == 0 then
				for _, id in EliteWaves.order do
					table.insert(pool, id)
				end
			end
			table.insert(ids, table.remove(pool, random(#pool)) :: string)
		end
		return ids
	end
	local slots = EliteWaves.slots
	local offset = block * Endless.bossEvery -- block 1: 21/22, 24/25, 27/28
	for index = 1, math.min(DangerRules.level(danger).challengeSlots, #slots) do
		local slot = slots[index]
		local wave = slot[random(#slot)] + offset
		local horde = block == 0 and index < #slots and roll() < Difficulty.hordeChance
		if horde then
			plan[wave] = { kind = "Horde", champions = {} }
		else
			plan[wave] = { kind = "Elite", champions = draw() }
		end
	end
	if block > 0 then
		local bossWave = WAVE_COUNT + block * Endless.bossEvery
		plan[bossWave] = { kind = "Elite", champions = draw() }
	end
	return plan
end

-- Share of HP each boss of a boss wave with `count` bosses gets.
function DangerRules.bossShare(count: number): number
	return if count > 1 then Config.Enemies.bossWave.hpShareWhenSeveral else 1
end

-- Champion HP share in `wave` (Brotato: 75 % in waves 11 and 12).
function DangerRules.championShare(wave: number): number
	return if table.find(EliteWaves.reducedHpWaves, wave) then EliteWaves.reducedHpShare else 1
end

-- True if bosses and champions killed in `wave` drop the legendary crate (Brotato: not after wave 20).
function DangerRules.legendaryCrates(wave: number): boolean
	return wave <= WAVE_COUNT or Endless.legendaryCrates
end

return DangerRules
