--!strict
-- One source enemy-factor context/cache per run wave, shared by hostile and friendly actors; EnemySim owns lifecycle and births.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rules = require(Shared.Config.NativeEnemyStatCache).rules
local DangerRules = require(Shared.Util.DangerRules)
local Nightmare = require(Shared.Config.Nightmare)
local NightmareRules = require(Shared.Util.NightmareRules)
local Cache = require(script.Parent.NativeEnemyStatCache)
local NativeStats = {}
local cache = Cache.new()
local capturedWave = 0
local captured: Cache.Context? = nil
local function capture(wave: number): Cache.Context
	-- Lazy dependencies avoid the existing StatService/RunDirector service-loading cycle.
	local Run = require(script.Parent.Parent.RunDirector)
	local Stats = require(script.Parent.Parent.StatService)
	local options = Run.getRunOptions()
	local level = DangerRules.level(options.danger)
	local players: { Cache.PlayerStats } = {}
	for _, player in Run.getParticipants() do
		table.insert(players, {
			health = Stats.getStat(player, "enemyHp"),
			damage = Stats.getStat(player, "enemyDamage"),
			speed = Stats.getStat(player, "enemySpeed"),
			curse = Stats.getStat(player, "curse"),
			-- Unit.init_current_stats primes speed before enemy effects/burning; this term is unused on that first call.
			burningSpeed = 0,
		})
	end
	return {
		players = players,
		danger = {
			health = (level.enemyHp - 1) * Rules.percent,
			damage = (level.enemyDamage - 1) * Rules.percent,
			speed = if options.danger >= Nightmare.level then NightmareRules.value("danger_enemy_speed") else 0,
		},
		accessibility = {
			health = options.enemyHp / Rules.percent,
			damage = options.enemyDamage / Rules.percent,
			speed = options.enemySpeed / Rules.percent,
		},
		endless = DangerRules.endlessFactor(wave),
		curseEnabled = true, -- the approved reference includes every DLC and its default Curse stat
	}
end
function NativeStats.clear()
	cache:clear()
	captured, capturedWave = nil, 0
end
function NativeStats.get(wave: number): (Cache.State, Cache.Context)
	if captured == nil or capturedWave ~= wave then
		cache:clear()
		capturedWave = wave
		local context = capture(wave)
		captured = context
		-- Source Enemy.init_current_stats asks health, damage and speed in this order on an unburned birth.
		cache:rawHealth(1, context)
		cache:rawDamage(1, context)
		cache:rawSpeed(1, false, context)
	end
	return cache, assert(captured, "Native enemy stat context was not captured")
end
return NativeStats
