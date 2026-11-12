--!strict
-- Builds only implemented Nightmare families from source facts; Config.Enemies supplies its existing pixel/world conversion.
local C = require(script.Parent.NightmareEnemies)
local Kinds = {}
local identities = {
	BloatedSpawner = { typeId = 33, name = "Bloated Spawner", look = "Splitter" },
	DireJunkie = { typeId = 34, name = "Dire Junkie", look = "Spitter" },
	HornedFly = { typeId = 35, name = "Horned Fly", look = "Brute" },
	HornedSpitter = { typeId = 36, name = "Horned Spitter", look = "Spitter" },
	CorruptedBuffer = { typeId = 37, name = "Corrupted Buffer", look = "Spitter" },
}
function Kinds.build(pixel: number): { [string]: any }
	local result = {}
	for _, id in C.implemented do
		local f = C.enemies[id]
		local s = f.stats
		local identity = identities[id]
		local kind = {
			id = id,
			typeId = identity.typeId,
			displayName = identity.name,
			look = identity.look,
			nativeArtPending = true,
			hp = s.health,
			hpPerWave = s.health_increase_each_wave,
			contactDamage = s.damage,
			damagePerWave = s.damage_increase_each_wave,
			speed = (s.speed - s.speed_randomization) * pixel,
			speedMax = (s.speed + s.speed_randomization) * pixel,
			xp = s.value,
			radius = f.circles.body * pixel,
			hurtRadius = f.circles.hurt * pixel,
			hitRadius = f.circles.hit * pixel,
			mass = C.runtimeCompatibility.mass,
			knockbackResistance = s.knockback_resistance,
			minDanger = C.minimumDanger,
			firstWave = 1,
			loot = {
				consumableChance = if s.can_drop_consumables then s.base_drop_chance else 0,
				crateShare = if s.can_drop_consumables then s.item_drop_chance else 0,
			},
		}
		if id == "BloatedSpawner" then
			kind.wander = {
				around = "Offset",
				within = false,
				range = f.movement.range_around_player * pixel,
				rangeJitter = f.movement.range_randomization * pixel,
				arriveStuds = C.rules.arrivePixels * pixel,
				maxSeconds = C.runtimeCompatibility.wanderTimeoutSeconds,
			}
			kind.split = {
				enemy = "DireJunkie",
				count = C.rules.spawnedChildren,
				spread = 0,
				area = C.rules.spawnSquarePixels * pixel,
			}
		elseif id == "CorruptedBuffer" then
			local root = f.root
			kind.stayInRange =
				{ distance = f.movement.target_range * pixel, jitter = f.movement.target_range_randomization * pixel }
			kind.pulse = {
				radius = f.circles.boost * pixel,
				intervalSeconds = root.boost_cooldown,
				firstSeconds = f.boostTimer.wait_time,
				buffCount = root.nb_entities_boosted_at_once,
				nativeResetStats = true,
				buffHp = root.hp_boost / 100,
				buffDamage = 1 + root.damage_boost / 100,
				buffSpeed = 1 + root.speed_boost / 100,
			}
		elseif id == "HornedFly" then
			kind.wander = {
				around = "Target",
				range = f.movement.range_around_player * pixel,
				rangeJitter = f.movement.range_randomization * pixel,
				arriveStuds = C.rules.arrivePixels * pixel,
				maxSeconds = C.runtimeCompatibility.wanderTimeoutSeconds,
			}
			kind.retaliate = {
				count = f.attack.number_projectiles,
				cooldownSeconds = 0,
				projectileDamage = f.attack.damage,
				projectileSpeed = f.attack.projectile_speed * pixel,
				projectileRange = C.runtimeCompatibility.projectileRangeStuds,
				projectileRadius = C.rules.projectileRadiusPixels * pixel,
				rangedOnly = true,
				chance = f.root.proj_chance,
				randomDirections = true,
				fromCenter = true,
			}
			kind.shotDamagePerWave = f.attack.damage_increase_each_wave
		else
			local a = f.attack
			if id == "DireJunkie" then
				kind.specialSpawn = true
				kind.wander = {
					around = "Arena",
					arriveStuds = C.rules.arrivePixels * pixel,
					maxSeconds = C.runtimeCompatibility.wanderTimeoutSeconds,
				}
			else
				kind.stayInRange = {
					distance = f.movement.target_range * pixel,
					jitter = f.movement.target_range_randomization * pixel,
				}
			end
			kind.ranged = {
				keepDistance = 0,
				fireInterval = a.cooldown / C.rules.physicsRate,
				fireRange = a.max_range * pixel,
				minFireRange = a.min_range * pixel,
				projectileDamage = a.damage,
				projectileSpeed = a.projectile_speed * pixel,
				projectileRange = C.runtimeCompatibility.projectileRangeStuds,
				projectileRadius = C.rules.projectileRadiusPixels * pixel,
				aimLead = 0,
				spreadRadians = a.projectile_spread,
				projectileCount = a.number_projectiles,
				fromCenter = true,
				nativeTiming = {
					fireInterval = a.cooldown / C.rules.physicsRate,
					cooldownRandomSeconds = a.max_cd_randomization / C.rules.physicsRate,
					initialSeconds = a.initial_cooldown / C.rules.physicsRate,
					fireAt = C.shootAnimation.fireAt / a.attack_anim_speed,
					animationSeconds = C.shootAnimation.duration / a.attack_anim_speed,
				},
			}
			kind.shotDamagePerWave = a.damage_increase_each_wave
		end
		result[id] = kind
	end
	return result
end
return Kinds
