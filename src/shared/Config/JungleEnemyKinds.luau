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
	end
	return result
end
return Kinds
