--!strict
-- Seeded random streams per run (DESIGN.md section 15, since B4; rules in RandomService/Streams): Shop (offers,
-- per player), Upgrades (level-up cards, per player), Loot (chest items, double orbs, per player), Spawns (enemy
-- spawns, splits and summons), Combat (weapon crits, life steal and aiming; dodge per player) and Effects (item
-- effects, per player). A new seed every run (Config.Run.seed fixes it), printed to the output. Used by ShopService,
-- UpgradeService, ExperienceService, SpawnDirector, EnemySim, WeaponService, CombatService and EffectService; the
-- balance simulation sets the seed of the next run with setNextSeed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RunDirector = require(script.Parent.RunDirector)
local Streams = require(script.Streams)

local NAMES = { "Shop", "Upgrades", "Loot", "Spawns", "Combat", "Effects" }
local MAX_SEED = 2 ^ 31 - 2

local RandomService = {}

local nextSeed: number? = nil

local function factory(seed: number): Streams.Generator
	return Random.new(seed)
end

local function newSeed(): number
	local seed = nextSeed
	nextSeed = nil
	if seed then
		return seed
	elseif Config.Run.seed ~= 0 then
		return Config.Run.seed
	end
	return Random.new():NextInteger(1, MAX_SEED)
end

local streams = Streams.new(newSeed(), NAMES, factory) -- outside a run (lobby tests, admin commands)

-- Lifecycle -------------------------------------------------------------------------

function RandomService.init()
	RunDirector.RunStarted:Connect(function()
		streams = Streams.new(newSeed(), NAMES, factory)
		print(`[Lanternfall] Run seed {streams.seed} (Config.Run.seed replays it)`)
	end)
end

-- Queries ---------------------------------------------------------------------------

-- The generator of stream `name` ("Shop", "Upgrades", "Loot", "Spawns", "Combat", "Effects"), the player's own if
-- `player` is given. Ask again after a run starts: every run has new streams.
function RandomService.stream(name: string, player: Player?): Streams.Generator
	return streams:get(name, if player then player.UserId else nil)
end

-- A number 0 <= n < 1 from stream `name` (see stream).
function RandomService.number(name: string, player: Player?): number
	return streams:get(name, if player then player.UserId else nil):NextNumber()
end

function RandomService.getSeed(): number
	return streams.seed
end

-- Commands --------------------------------------------------------------------------

-- The seed of the next run (balance simulation, tests); nil goes back to Config.Run.seed / a new seed.
function RandomService.setNextSeed(seed: number?)
	nextSeed = seed
end

return RandomService
