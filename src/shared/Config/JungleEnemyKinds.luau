--!strict
-- Adapts verified Jungle pursuit/contact families to the existing enemy engine; Config.Enemies owns pixel conversion.
local C = require(script.Parent.JungleWalkers)
local Kinds = {}
function Kinds.build(pixel: number): { [string]: any }
	local result = {}
	for _, id in C.implemented do
		local f = C.enemies[id]
		local s = f.stats
		result[id] = {
			id = id,
			typeId = f.typeId,
			displayName = f.displayName,
			look = f.fallbackLook,
			nativeArtPending = true,
			nativeZoneId = C.zoneId,
			hp = s.health,
			hpPerWave = s.health_increase_each_wave,
			contactDamage = s.damage,
			damagePerWave = s.damage_increase_each_wave,
			speed = (s.speed - s.speed_randomization) * pixel,
			speedMax = (s.speed + s.speed_randomization) * pixel,
			xp = s.value,
			radius = f.body.radiusPoints * pixel,
			hurtRadius = f.hurt.radiusPoints * pixel,
			hitRadius = f.hit.radiusPoints * pixel,
			mass = C.runtimeCompatibility.mass,
			knockbackResistance = s.knockback_resistance,
			removeFirst = f.removeFirst,
			loot = {
				consumableChance = if s.can_drop_consumables then s.base_drop_chance else 0,
				crateShare = if s.can_drop_consumables then s.item_drop_chance else 0,
			},
		}
		if f.anticipate then
			result[id].anticipate = f.anticipate
		end
		if f.activeVariant then
			local a = f.shootingVariants[f.activeVariant]
			local rules = C.shootingRules
			local position = a.position.values
			local kind = result[id]
			kind.stayInRange =
				{ distance = f.movement.target_range * pixel, jitter = f.movement.target_range_randomization * pixel }
			kind.shotDamagePerWave = a.damage_increase_each_wave
			kind.ranged = {
				keepDistance = 0,
				fireInterval = a.cooldown / rules.frameRate,
				fireRange = a.max_range * pixel,
				minFireRange = a.min_range * pixel,
				projectileDamage = a.damage,
				projectileSpeed = a.projectile_speed * pixel,
				projectileRange = rules.projectileRangeStuds,
				projectileRadius = rules.pillar.radiusPoints * pixel,
				aimLead = 0,
				nativePillar = true,
				nativeVolley = {
					count = a.number_projectiles,
					spread = a.projectile_spread,
					constantSpread = a.constant_spread,
					offsetX = position[1] * pixel,
					offsetZ = position[2] * pixel,
					speedStep = a.speed_change_after_each_projectile * pixel,
				},
				nativeTiming = {
					fireInterval = a.cooldown / rules.frameRate,
					cooldownRandomSeconds = a.max_cd_randomization / rules.frameRate,
					minimumCooldownSeconds = rules.minimumCooldownFrames / rules.frameRate,
					initialSeconds = a.initial_cooldown / rules.frameRate,
					fireAt = rules.animationFireAt / a.attack_anim_speed,
					animationSeconds = rules.animationSeconds / a.attack_anim_speed,
					longEvery = a.long_cooldown_every_x_shoots,
					longSeconds = a.long_cooldown / rules.frameRate,
				},
			}
		end
	end
	return result
end
return Kinds
