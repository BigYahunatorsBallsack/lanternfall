--!strict
-- Original weapon hit rules and secondary shots, called by BrotatoMelee/Projectile without changing Arsenal.
local Arsenal = require(script.Parent.Arsenal)
local Combat = {}
local adapter: { [string]: any } = {}
-- Only native hitboxes carry this classification; burn ticks and stat strikes have no hitbox.
local hitOwner: number? = nil
local hitElemental: boolean? = nil
local hitStats: { [string]: number }? = nil
-- A living carrier can be temporarily unable to attack (Soldier movement); flight must continue.
function Combat.ownerAlive(ownerId: number, placed: boolean): boolean
	return if adapter.ownerAlive then adapter.ownerAlive(ownerId) else placed
end
function Combat.resetHitContext()
	hitOwner, hitElemental, hitStats = nil, nil, nil
end
function Combat.elementalHit(ownerId: number): boolean?
	return if hitOwner == ownerId then hitElemental else nil
end
function Combat.digChance(ownerId: number): number
	return if hitOwner == ownerId and hitStats then hitStats.digCrateChance or 0 else 0
end

function Combat.roundHit(ownerId: number, amount: number): number
	return if hitOwner == ownerId
			and hitStats
			and (hitStats.nativeTiming or hitStats.nativeExplosive)
		then math.round(amount)
		else amount
end

function Combat.targetBonus(ownerId: number, id: number): number
	local stats = if hitOwner == ownerId then hitStats else nil
	if not stats or not adapter.healthShare or (not stats.belowHealthThreshold and not stats.aboveHealthThreshold) then
		return 0
	end
	local share = adapter.healthShare(id)
	local bonus = 0
	if stats.belowHealthThreshold and share <= stats.belowHealthThreshold then
		bonus += stats.belowHealthDamagePercent
	end
	if stats.aboveHealthThreshold and share >= stats.aboveHealthThreshold then
		bonus += stats.aboveHealthDamagePercent
	end
	return bonus
end

function Combat.configure(callbacks: { [string]: any })
	adapter = callbacks
end

-- A native explosion is one distinct attack, with per-target crits and a single aggregate unlock observation.
function Combat.explode(
	weapon: Arsenal.Weapon,
	ctx: Arsenal.Context,
	x: number,
	z: number,
	skip: number?,
	share: number?,
	snapshot: { [string]: number }?
)
	local original = weapon.stats
	local stats = table.clone(snapshot or original)
	local ids: { number } = {}
	local count = ctx:queryCircle(x, z + (stats.explosionOffsetZ or 0), stats.explosionRadius, ids)
	if adapter.emitExplosion then
		adapter.emitExplosion(weapon.ownerId, x, z, stats.explosionRadius)
	else
		ctx:emit(weapon, { kind = "Blast", x = x, z = z, radius = stats.explosionRadius })
	end
	local previousOwner, previousElemental, previousStats = hitOwner, hitElemental, hitStats
	hitOwner, hitStats = weapon.ownerId, stats
	local scaling = if weapon.config.tierScaling then weapon.config.tierScaling[weapon.tier] else weapon.config.scaling
	hitElemental = scaling.elementalDamage ~= nil
	weapon.stats = stats
	local kills = 0
	for index = 1, count do
		local id = ids[index]
		if id ~= skip and ctx:hit(weapon, id, share, "Explosion") then
			kills += 1
		end
	end
	weapon.stats = original
	hitOwner, hitElemental, hitStats = previousOwner, previousElemental, previousStats
	if adapter.explosionResolved then
		adapter.explosionResolved(weapon.ownerId, kills)
	end
end

function Combat.hit(
	weapon: Arsenal.Weapon,
	ctx: Arsenal.Context,
	id: number,
	share: number?,
	shotStats: { [string]: number }?,
	critical: boolean?,
	secondary: boolean?,
	bounced: boolean?
): (boolean, boolean)
	if weapon.state.broken then
		return false, false
	end
	local original = weapon.stats
	local stats = table.clone(shotStats or original)
	if
		stats.charmChance
		and adapter.tryCharm
		and adapter.tryCharm(weapon.ownerId, id, stats, function()
			return ctx:random()
		end)
	then
		return false, false
	end
	local crit = if critical ~= nil then critical else ctx:random() < stats.critChance
	if stats.critBurning and adapter.isBurning and adapter.isBurning(id) then
		crit = true
	end
	local hitX, hitZ = ctx:enemyPosition(id)
	if stats.impactSlowRadius and adapter.slowArea and hitX and hitZ then
		adapter.slowArea(id, hitX, hitZ, stats.impactSlowRadius, stats.impactSlowPercent, stats.impactSlowHold)
	end
	stats.critChance = if crit then 1 else 0
	if stats.executeChance and adapter.health and not adapter.isElite(id) and ctx:random() < stats.executeChance then
		stats.damage = math.max(stats.damage, adapter.health(id) / math.max(share or 1, 1e-6))
	end
	local previousOwner, previousElemental, previousStats = hitOwner, hitElemental, hitStats
	hitStats = stats
	hitOwner = weapon.ownerId
	local scaling = if weapon.config.tierScaling then weapon.config.tierScaling[weapon.tier] else weapon.config.scaling
	hitElemental = if secondary then stats.secondaryElemental ~= nil else scaling.elementalDamage ~= nil
	if stats.nativeElemental ~= nil then
		hitElemental = stats.nativeElemental == 1
	end
	weapon.stats = stats
	weapon.state.secondaryHit = secondary == true
	if stats.vulnerabilityPercent and adapter.weakness then
		adapter.weakness(
			id,
			weapon.id,
			stats.vulnerabilityPercent,
			stats.vulnerabilitySeconds,
			stats.vulnerabilityStacks
		)
	end
	local killed = ctx:hit(weapon, id, share, if bounced then "Bounce" else nil)
	if not killed and stats.carbonMeleeSlow and adapter.nativeSlow then
		adapter.nativeSlow(id, -stats.carbonMeleeSlow, true, stats.carbonSlowSeconds)
	end
	if stats.nativeMineChance and adapter.spawnMine and hitX and hitZ and ctx:random() < stats.nativeMineChance then
		adapter.spawnMine(weapon.ownerId, hitX, hitZ)
	end
	if
		not killed
		and (not bounced or stats.knockback < 0)
		and stats.knockbackPiercing
		and adapter.knockbackPiercing
	then
		adapter.knockbackPiercing(id, ctx.x, ctx.z, stats.knockback, stats.knockbackPiercing, ctx.hitDirX, ctx.hitDirZ)
	end
	weapon.state.secondaryHit = false
	if
		not secondary
		and stats.explosionRadius
		and (not stats.explosionChance or ctx:random() < stats.explosionChance)
	then
		local x, z = hitX, hitZ
		if x and z then
			Combat.explode(weapon, ctx, x, z, id, share, shotStats or original)
		end
	end
	hitOwner, hitElemental, hitStats = previousOwner, previousElemental, previousStats
	weapon.stats = original
	if not secondary and (stats.secondaryCount or 0) > 0 then
		local x, z = hitX, hitZ
		if x and z then
			local pending = weapon.state.secondaryShots or {}
			weapon.state.secondaryShots = pending
			table.insert(pending, { x = x, z = z, skip = id, stats = shotStats or original })
		end
	end
	if stats.breakChance and stats.breakChance > 0 and adapter.breakWeapon and ctx:random() <= stats.breakChance then
		weapon.state.broken = true
		local x, z = require(game:GetService("ReplicatedStorage").Shared.Util.WeaponPose).anchor(
			ctx.x,
			ctx.z,
			ctx.slot,
			ctx.slotCount,
			weapon.id
		)
		adapter.breakWeapon(weapon, x, z, stats.breakMaterials)
	end
	return killed, crit
end

return Combat
