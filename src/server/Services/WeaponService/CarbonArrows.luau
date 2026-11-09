--!strict
-- Native Carbon Bow weighted per-projectile variants; WeaponService primes the next arrow and Projectile consumes it.
local Carbon = {}
local suffixes = { "Melee", "Ranged", "Elemental", "Engineering" }
function Carbon.pick(stats: { [string]: number }, random: () -> number): number
	local total = 0
	for _, suffix in suffixes do
		total += stats["carbonWeight" .. suffix] or 0
	end
	local roll = random()
	if total <= 0 then
		return math.min(#suffixes, math.floor(roll * #suffixes) + 1)
	end
	local left = roll * total
	for index, suffix in suffixes do
		left -= stats["carbonWeight" .. suffix] or 0
		if left < 0 then
			return index
		end
	end
	return #suffixes
end
function Carbon.initialise(weapon: any, random: () -> number)
	if weapon.stats.carbonBow and not weapon.state.nextCarbon then
		weapon.state.nextCarbon = Carbon.pick(weapon.stats, random)
	end
end
function Carbon.take(weapon: any, stats: { [string]: number }, random: () -> number): { [string]: number }
	Carbon.initialise(weapon, random)
	local index = weapon.state.nextCarbon
	weapon.state.nextCarbon = Carbon.pick(stats, random)
	local result = table.clone(stats)
	result.damage = stats["carbonDamage" .. suffixes[index]]
	result.nativeElemental = if index == 3 then 1 else 0
	if index == 1 then
		result.carbonMeleeSlow = stats.carbonSlow
	elseif index == 2 then
		result.pierce += stats.carbonPierce
	elseif index == 3 then
		result.burnDamage = stats.carbonBurnDamage
		result.burnTicks = stats.carbonBurnTicks
		result.burnInterval = stats.carbonBurnInterval
		result.burnSpread = stats.carbonBurnSpread
		result.burnChance = 1
	elseif index == 4 then
		result.nativeMineChance = stats.carbonMineChance
	end
	return result
end
return Carbon
