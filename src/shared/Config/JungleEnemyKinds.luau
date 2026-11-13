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
			nativeObstacleCollision = f.obstacleCollision,
			nativeMovement = {
				goalInsetX = f.sprite.widthPoints * pixel / 2,
				goalInsetZ = f.sprite.heightPoints * pixel / 2,
				borderClamp = f.bodyBorders,
				collidePlayers = f.playerCollision,
				precision = C.spawningRules.goalPrecisionPoints * pixel,
			},
			hp = s.health,
			hpPerWave = s.health_increase_each_wave,
			contactDamage = s.damage,
			damagePerWave = s.damage_increase_each_wave,
			speed = (s.speed - s.speed_randomization) * pixel,
			speedMax = (s.speed + s.speed_randomization) * pixel,
			nativeSpeedPoints = { base = s.speed, randomization = s.speed_randomization },
			xp = s.value,
			radius = f.body.radiusPoints * pixel,
			hurtRadius = f.hurt.radiusPoints * pixel,
			hitRadius = f.hit.radiusPoints * pixel,
			mass = f.mass or C.runtimeCompatibility.mass,
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

		if f.healing then
			local h = f.healing
			result[id].pulse = {
				radius = h.zone.radiusPoints * pixel,
				intervalSeconds = 0,
				onEnter = true,
				healFlat = h.heal,
				healPerWave = h.heal_increase_each_wave,
				nativeEnemyEntry = true,
			}
			result[id].wander = {
				around = "Arena",
				range = 0,
				rangeJitter = 0,
				arriveStuds = C.spawningRules.goalPrecisionPoints * pixel,
				maxSeconds = math.huge,
			}
		end
		if f.spawning then
			local a = f.spawning.properties
			local rules = C.spawningRules
			result[id].nativeSpawn = {
				enemy = f.spawning.child,
				count = a.nb_to_spawn,
				area = (if a.spawn_random_pos_area ~= -1
					then a.spawn_random_pos_area
					else a.spawn_in_radius_around_unit) * pixel,
				maxCount = a.max_nb_of_spawns,
				dieOnRequest = f.spawning.diesOnRequest,
				timing = {
					fireInterval = a.cooldown / rules.frameRate,
					cooldownRandomSeconds = a.max_cd_randomization / rules.frameRate,
					minimumCooldownSeconds = rules.minimumCooldownFrames / rules.frameRate,
					initialSeconds = 0,
					fireAt = rules.animations[1].fireAt / a.attack_anim_speed,
					animationSeconds = rules.animations[1].seconds / a.attack_anim_speed,
				},
			}
			if id == "Alamosaurus" then
				result[id].wander = {
					around = "Arena",
					range = 0,
					rangeJitter = 0,
					arriveStuds = rules.goalPrecisionPoints * pixel,
					maxSeconds = math.huge,
				}
			else
				local move = f.spawning.movement
				result[id].stayInRange =
					{ distance = move.target_range * pixel, jitter = move.target_range_randomization * pixel }
			end
		end
		if f.pursuer then
			local a = f.pursuer
			result[id].pursuer = {
				everySeconds = a.boost_cooldown,
				maxSteps = a.max_boosts,
				speedPerStep = a.speed_on_boost * pixel,
				damagePercentPerStep = a.damage_on_boost,
				sizePerStep = a.size_on_boost,
				collisionScalingShare = a.collisionScalingShare,
				spriteRise = a.spriteRisePoints * pixel,
				changeAt = a.change_movement_behavior_after_x_boosts,
				changeSpeed = a.bonus_speed_on_change_movement_behavior * pixel,
				playerSpeedShare = a.max_player_speed_multiplier,
			}
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
