--!strict
-- Weapon evolutions (DESIGN.md section 6). Only offered from elite or boss chests (WP9). Read by WeaponService
-- (stats via WeaponStats), UpgradeService (who may evolve what) and the client (HUD name, weapon look).

export type Evolution = {
	id: string,
	displayName: string,
	weapon: string, -- must be at the max tier (IV, since B3; before level 5)
	item: string, -- key in Config.Items, owned at least once
	behavior: string,
	stats: { [string]: number }, -- overrides on top of the max-tier weapon
}

local Evolutions: { [string]: Evolution } = {} -- The original game has weapon tiers, not evolutions.

return table.freeze(Evolutions)
