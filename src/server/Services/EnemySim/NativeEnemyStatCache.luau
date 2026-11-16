--!strict
-- Source EntityService global factor cache and final rounding; pending native provider owns context reads and wave reset timing.
local C = require(game:GetService("ReplicatedStorage").Shared.Config.NativeEnemyStatCache)
local R = C.rules
local Cache = {}
Cache.__index = Cache
export type PlayerStats = { health: number, damage: number, speed: number, curse: number, burningSpeed: number }
export type Context = {
	players: { PlayerStats },
	danger: { health: number, damage: number, speed: number }, -- source effect percentages
	accessibility: { health: number, damage: number, speed: number }, -- source run factors
	endless: number,
	curseEnabled: boolean,
}
export type State = typeof(setmetatable({} :: { factors: { [string]: number } }, Cache))
function Cache.new(): State
	return setmetatable({ factors = {} }, Cache)
end
function Cache.clear(self: State)
	table.clear(self.factors)
end
local function percent(value: number): number
	return 1 + value / R.percent
end
local function boundedPercent(value: number): number
	return math.max(R.minimumFactor, percent(value))
end
local function total(players: { PlayerStats }, key: "health" | "damage" | "curse"): number
	local sum = 0
	for _, player in players do
		sum += player[key]
	end
	return sum
end
local function factor(ctx: Context, key: "health" | "damage"): number
	assert(#ctx.players > 0, "Native enemy factors require the source run's players")
	local health = key == "health"
	local curse = if ctx.curseEnabled then math.sqrt(math.max(0, total(ctx.players, "curse") / #ctx.players)) else 0
	local curseFactor = curse / (if health then R.curseHealthDivisor else R.curseDamageDivisor)
	local endless = 1 + ctx.endless * (if health then R.endlessHealthMultiplier else 1) * (1 + curseFactor)
	local coop = 1 + (#ctx.players - 1) * C.coopPerAdditionalPlayer[key]
	return boundedPercent(ctx.danger[key])
		* ctx.accessibility[key]
		* math.max(R.minimumFactor, coop)
		* boundedPercent(total(ctx.players, key))
		* math.max(R.minimumFactor, endless)
end
function Cache.rawHealth(self: State, base: number, ctx: Context): number
	local value = self.factors.health
	if value == nil then
		value = factor(ctx, "health")
		self.factors.health = value
	end
	return math.modf(base) * value
end
function Cache.health(self: State, base: number, boostPercent: number, ctx: Context): number
	return math.round(self:rawHealth(base, ctx) * boundedPercent(boostPercent))
end
function Cache.rawDamage(self: State, base: number, ctx: Context): number
	local value = self.factors.damage
	if value == nil then
		value = factor(ctx, "damage")
		self.factors.damage = value
	end
	return base * value
end
function Cache.damage(self: State, base: number, boostPercent: number, ctx: Context): number
	return math.round(self:rawDamage(base, ctx) * boundedPercent(boostPercent))
end
function Cache.rawSpeed(self: State, base: number, burning: boolean, ctx: Context): number
	local value = self.factors.speed
	if value == nil then
		local effects = 1
		for _, player in ctx.players do
			effects *= percent(
				math.max(R.minimumPlayerSpeedPercent, player.speed) + (if burning then player.burningSpeed else 0)
			)
		end
		value = effects
			* ctx.accessibility.speed
			* (1 + math.min(R.endlessSpeedCap, ctx.endless / R.endlessSpeedDivisor))
			* boundedPercent(ctx.danger.speed)
		self.factors.speed = value
	end
	return math.modf(base) * value
end
function Cache.speed(self: State, base: number, boostPercent: number, burning: boolean, ctx: Context): number
	return math.round(self:rawSpeed(base, burning, ctx) * percent(boostPercent))
end
return Cache
