--!strict
-- Difficulty tiers (DESIGN.md section 10). Read by RunDirector and SpawnDirector.
-- unlockedBy = the tier whose boss must be beaten first.

export type Tier = {
	id: string,
	order: number,
	enemyHp: number,
	enemyDamage: number,
	embers: number,
	unlockedBy: string?,
}

local Tiers: { [string]: Tier } = {
	Normal = { id = "Normal", order = 1, enemyHp = 1, enemyDamage = 1, embers = 1 },
	Hard = { id = "Hard", order = 2, enemyHp = 1.6, enemyDamage = 1.25, embers = 1.5, unlockedBy = "Normal" },
	Nightmare = { id = "Nightmare", order = 3, enemyHp = 2.5, enemyDamage = 1.5, embers = 2.2, unlockedBy = "Hard" },
}

return table.freeze({
	default = "Normal",
	tiers = table.freeze(Tiers),
})
