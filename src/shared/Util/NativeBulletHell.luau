--!strict
-- Original bullet-hell emitter timing and native-pixel geometry; BulletHellService supplies map bounds, source damage factors and seeded RNG.
local C = require(script.Parent.Parent.Config.NativeBulletHell).rules
local Hell = {}
export type Emitter = { x: number, z: number, tick: number, generator: any }
export type State =
	{ emitters: { Emitter }, interval: number, speed: number, damage: number, accessibilitySpeed: number }
function Hell.new(
	pattern: any,
	width: number,
	height: number,
	wave: number,
	challenge: boolean,
	accessibilitySpeed: number,
	enemyDamageFactor: number
): State
	local parameterWave = math.min(wave, C.parameterWaveCap) / (if challenge then C.challengeWaveDivisor else 1)
	local interval = pattern.spawn_rate - parameterWave / C.intervalWaveDivisor
	assert(interval > 0, "Native bullet hell has a nonpositive source interval")
	local damage = math.floor(
		(C.baseDamage + pattern.projectile_damage_increase_each_wave * (wave - 1))
				* enemyDamageFactor
				* (1 + C.enemyDamageModifier / 100)
			+ 0.5
	)
	local state: State = {
		emitters = {},
		interval = interval,
		speed = pattern.projectile_speed + parameterWave * C.speedPerWave,
		damage = damage + pattern.projectile_damage_increase_each_wave * (wave - 1),
		accessibilitySpeed = accessibilitySpeed,
	}
	for _, g in pattern.generators do
		if not g.is_active then
			continue
		end
		local anchor = g.anchor_position
		local x = if anchor == 0 then 0 else ((anchor - 1) % 3) * width / 2
		local z = if anchor == 0 then 0 else math.floor((anchor - 1) / 3) * height / 2
		x += g.offset_anchor_positon[1]
		z += g.offset_anchor_positon[2]
		local count = g.duplications
		local axis = g.duplication_constant_along
		if axis ~= 0 then
			local offset = g.duplication_offset_position[axis]
			count = 1
			if offset ~= 0 then
				local span = if axis == 1 then width - x else height - z
				count = math.floor(math.abs(math.modf(span)) / offset) + 1
			end
		end
		for index = 0, count - 1 do
			table.insert(
				state.emitters,
				{
					x = x + index * g.duplication_offset_position[1],
					z = z + index * g.duplication_offset_position[2],
					tick = interval * g.spawn_rate_factor * (g.start_cool_down + index * g.duplication_offset_start_cd),
					generator = g,
				}
			)
		end
	end
	return state
end
-- The positive native start_cool_down initializes elapsed phase (it is not a delay).
function Hell.step(state: State, dt: number, random: () -> number, fire: (any) -> ())
	for _, emitter in state.emitters do
		local g = emitter.generator
		local interval = state.interval * g.spawn_rate_factor
		emitter.tick += dt
		while emitter.tick > interval do
			emitter.tick -= interval
			fire({
				x = emitter.x + (random() - 0.5) * g.position_spawn_randomness[1],
				z = emitter.z + (random() - 0.5) * g.position_spawn_randomness[2],
				dx = g.direction[1],
				dz = g.direction[2],
				speed = state.speed * g.speed_factor * state.accessibilitySpeed,
				damage = math.floor(state.damage * g.damage_factor),
				motion = {
					amplitudeX = g.sinusoidal_motion[1],
					amplitudeZ = g.sinusoidal_motion[2],
					frequencyX = g.sinusoidal_motion_speed[1],
					frequencyZ = g.sinusoidal_motion_speed[2],
				},
			})
		end
	end
end
return Hell
