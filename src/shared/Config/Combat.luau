--!strict
-- Combat rules beyond a single hit (DESIGN.md section 6, Brotato direction since B5): knockback, burning, slows,
-- explosions, piercing and bouncing. Per weapon values stay in Config.Weapons; this holds what every weapon and item
-- effect shares. Read by WeaponService (WeaponStats, Arsenal, Afflictions), Util/StatMath and the client texts.

return table.freeze({
	-- Knockback in Brotato points (a crossbow has 8, a hammer 30), pushed directly away from the owner. The Knockback
	-- stat adds points to every weapon. Enemies keep 1 - knockbackResistance of it (Config.Enemies), elites none.
	knockback = table.freeze({
		studsPerPoint = 0.1, -- like Range: 30 points = 3 studs (the Shockwave push before B5)
	}),
	-- Burning (Brotato's burn): `ticks` hits of the burn damage, one every tickSeconds; Burning Speed shortens the
	-- interval by its percent (+20 % = 0.8 s, -100 % = 2 s), never below minTickSeconds. Burns do not stack: a new one
	-- keeps the higher damage and the more ticks of the two. Burns cannot crit or life steal. Spreading: on every tick a
	-- burn with `spread` passes a copy to that many of the nearest enemies within spreadRadius that do not burn yet,
	-- and copies spread on (spreadRadius is an assumption, Brotato gives no number).
	burn = table.freeze({
		tickSeconds = 1,
		minTickSeconds = 0.2,
		spreadRadius = 8, -- studs
	}),
	-- Explosions: a radius at 100 % size (Brotato's base size; assumption), for item effects whose `size` is a share
	-- of it. Explosion Size scales every radius, Explosion Damage every explosion's damage. Explosions crit like the
	-- weapon, never life steal and never knock back.
	explosion = table.freeze({
		baseRadius = 6, -- studs; Starfire's blast
	}),
	-- Piercing (Brotato): every enemy after the first takes `falloff` less than the one before, unless the weapon sets
	-- its own pierceFalloff; Piercing Damage gives some of it back, never above full damage.
	piercing = table.freeze({
		falloff = 0.5,
	}),
	-- Bouncing (Brotato): a projectile that would stop flies on to a random enemy within `range` studs it has not hit
	-- yet (Brotato: unlimited range; assumption), each bounce dealing `falloff` less. Bounces come before piercing and
	-- lose the knockback.
	bounce = table.freeze({
		falloff = 0.5,
		range = 25, -- studs
	}),
})
