--!strict
-- Executes the source-selected environmental projectile wave through EnemySim; DangerService owns the immutable event plan.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.NativeBulletHell)
local Nightmare = require(Shared.Config.Nightmare)
local Hell = require(Shared.Util.NativeBulletHell)
local DangerRules = require(Shared.Util.DangerRules)
local Run = require(script.Parent.RunDirector)
local Danger = require(script.Parent.DangerService)
local Enemies = require(script.Parent.EnemySim)
local Map = require(script.Parent.MapService)
local Stats = require(script.Parent.StatService)
local RandomService = require(script.Parent.RandomService)
local SpawnRules = require(script.Parent.SpawnDirector.SpawnRules)
local PIXELS = Config.Stats.range.studsPerPoint
local Service = {}
local state: Hell.State? = nil
local wave = 0
local originX, originZ = 0, 0
local function enemyDamageFactor(atWave: number): number
	local participants = Run.getParticipants()
	local damage, curse = 0, 0
	for _, player in participants do
		damage += Stats.getStat(player, "enemyDamage")
		curse += Stats.getStat(player, "curse")
	end
	curse /= math.max(1, #participants)
	local dangerPercent = 0
	for _, effect in Nightmare.effects do
		if effect.key == "danger_enemy_damage" then
			dangerPercent = effect.value
		end
	end
	local minimum = C.rules.minimumEnemyFactor
	return math.max(minimum, 1 + damage / 100)
		* math.max(minimum, 1 + dangerPercent / 100)
		* SpawnRules.coopDamage(#participants)
		* (Run.getRunOptions().enemyDamage / 100)
		* math.max(
			minimum,
			1 + DangerRules.endlessFactor(atWave) * (1 + math.sqrt(math.max(0, curse)) / C.rules.curseEndlessDivisor)
		)
end
local function clear()
	state = nil
	wave = 0
end
function Service.init()
	Run.RunStarted:Connect(clear)
	Run.RunEnded:Connect(clear)
	Run.PhaseChanged:Connect(function(phase)
		if phase ~= "Running" then
			clear()
		end
	end)
	Enemies.Stepped:Connect(function(dt)
		if Run.getPhase() ~= "Running" then
			return
		end
		local current = Run.getWave()
		if wave ~= current then
			wave = current
			state = nil
			if Danger.getNightmareEvent(current) == "bullet_hell" then
				local bounds = Map.getArenaBounds()
				originX, originZ = bounds.center.X - bounds.halfX, bounds.center.Z - bounds.halfZ
				local random = RandomService.stream("Spawns")
				local pattern = C.patterns[random:NextInteger(1, #C.patterns)]
				state = Hell.new(
					pattern,
					2 * bounds.halfX / PIXELS,
					2 * bounds.halfZ / PIXELS,
					current,
					Danger.getChallenge(current) ~= nil,
					Run.getRunOptions().enemySpeed / 100,
					enemyDamageFactor(current)
				)
			end
		end
		local active = state
		if not active then
			return
		end
		local random = RandomService.stream("Spawns")
		Hell.step(active, dt, function()
			return random:NextNumber()
		end, function(shot)
			local motion = shot.motion
			Enemies.fireShot(
				originX + shot.x * PIXELS,
				originZ + shot.z * PIXELS,
				shot.dx,
				shot.dz,
				shot.speed * PIXELS,
				math.huge,
				C.rules.hitRadiusPixels * PIXELS,
				shot.damage,
				{
					amplitudeX = motion.amplitudeX * PIXELS,
					amplitudeZ = motion.amplitudeZ * PIXELS,
					frequencyX = motion.frequencyX,
					frequencyZ = motion.frequencyZ,
				}
			)
		end)
	end)
end
-- Read-only diagnostics used by service tests; no client command can force or select a pattern.
function Service.isActive(): boolean
	return state ~= nil
end
return Service
