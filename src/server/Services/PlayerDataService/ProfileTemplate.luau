--!strict
-- Default player data, schema v1 (DESIGN.md section 16). Used by PlayerDataService.
-- Schema change = SCHEMA_VERSION + 1 and a migration function (added with ProfileStore in WP12).

export type Data = {
	schemaVersion: number,
	embers: number,
	talents: { toughness: number, power: number, reach: number, greed: number, rescuer: number, rerolls: number },
	classes: { string },
	difficultyUnlocked: string,
	cosmetics: { owned: { string }, equipped: { [string]: string } },
	stats: { runs: number, kills: number, bossKills: number, bestTime: number },
	quests: { day: string, list: { any } },
	streak: { lastLogin: number, count: number },
	pass: { season: number, xp: number, premium: boolean, claimed: { [string]: boolean } },
	receipts: { [string]: boolean }, -- PurchaseIds that were already granted
}

local ProfileTemplate = {}

ProfileTemplate.SCHEMA_VERSION = 1

-- Fresh default data; every call returns new tables.
function ProfileTemplate.new(): Data
	return {
		schemaVersion = ProfileTemplate.SCHEMA_VERSION,
		embers = 0,
		talents = { toughness = 0, power = 0, reach = 0, greed = 0, rescuer = 0, rerolls = 0 },
		classes = { "BladeWarden", "SparkMage" },
		difficultyUnlocked = "Normal",
		cosmetics = { owned = {}, equipped = {} },
		stats = { runs = 0, kills = 0, bossKills = 0, bestTime = 0 },
		quests = { day = "", list = {} },
		streak = { lastLogin = 0, count = 0 },
		pass = { season = 1, xp = 0, premium = false, claimed = {} },
		receipts = {},
	}
end

return ProfileTemplate
