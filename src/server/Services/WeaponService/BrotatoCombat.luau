--!strict
-- Original weapon hit rules and secondary shots, called by BrotatoMelee/Projectile without changing Arsenal.
local Arsenal = require(script.Parent.Arsenal)
local Combat = {}
local adapter: { [string]: any } = {}

function Combat.configure(callbacks: { [string]: any })
	adapter = callbacks
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
	local original = weapon.stats
	local stats = table.clone(shotStats or original)
	local crit = if critical ~= nil then critical else ctx:random() < stats.critChance
	local hitX, hitZ = ctx:enemyPosition(id)
	stats.critChance = if crit then 1 else 0
	if stats.executeChance and adapter.health and not adapter.isElite(id) and ctx:random() < stats.executeChance then
		stats.damage = math.max(stats.damage, adapter.health(id) / math.max(share or 1, 1e-6))
	end
	weapon.stats = stats
	weapon.state.secondaryHit = secondary == true
	local killed = ctx:hit(weapon, id, share, if bounced then "Bounce" else nil)
	if not killed and not bounced and stats.knockbackPiercing and adapter.knockbackPiercing then
		adapter.knockbackPiercing(id, ctx.x, ctx.z, stats.knockback, stats.knockbackPiercing)
	end
	weapon.state.secondaryHit = false
	if
		not secondary
		and stats.explosionRadius
		and (not stats.explosionChance or ctx:random() < stats.explosionChance)
	then
		local x, z = hitX, hitZ
		if x and z then
			ctx:explode(weapon, x, z, id, share)
		end
	end
	weapon.stats = original
	if not secondary and (stats.secondaryCount or 0) > 0 then
		local x, z = hitX, hitZ
		if x and z then
			local pending = weapon.state.secondaryShots or {}
			weapon.state.secondaryShots = pending
			table.insert(pending, { x = x, z = z, skip = id, stats = shotStats or original })
		end
	end
	return killed, crit
end

return Combat
