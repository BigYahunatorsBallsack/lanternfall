--!strict
-- Native character explosion facts; CharacterService resolves source references, WeaponService applies the hits.
export type Definition = {
	source: string,
	sourceMd5: string,
	damage: number,
	scaling: { [string]: number },
	critChance: number,
	critDamage: number,
	radiusPoints: number,
	offsetZPoints: number,
}
local bySource: { [string]: Definition } = {
	["res://items/characters/bull/bull_explosion_stats.tres"] = {
		source = "res://items/characters/bull/bull_explosion_stats.tres",
		sourceMd5 = "86de7e57b1501735719b383049d7a455",
		damage = 30,
		scaling = { meleeDamage = 3, rangedDamage = 3, elementalDamage = 3 },
		critChance = 0.03,
		critDamage = 1.5,
		-- res://projectiles/explosion.tscn: CircleShape2D radius and Collision.position.y.
		radiusPoints = 147.34,
		offsetZPoints = 3,
	},
}
return table.freeze({
	bySource = bySource,
	sceneSource = "res://projectiles/explosion.tscn",
	sceneMd5 = "d81ff40d7795be91af539a3dc847e22f",
	minimumAreaScale = 0.1, -- PlayerExplosion.set_area in stable 1.2.0.1
})
