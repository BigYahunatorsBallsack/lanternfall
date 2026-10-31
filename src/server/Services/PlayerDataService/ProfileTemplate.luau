--!strict
-- Default player data, schema v2 (DESIGN.md section 16). Used by PlayerDataService (ProfileStore template) and
-- Migrations. Schema change = SCHEMA_VERSION + 1 and a step in Migrations; never drop a field without a step.

-- One character's record (Paket 12; Paket 13 unlocks the danger levels per character from it).
export type CharacterStats = {
	runs: number,
	wins: number,
	bestWave: number,
	bestDanger: number, -- highest danger level won with it, -1 = never won
}

export type Data = {
	schemaVersion: number,
	embers: number,
	talents: { toughness: number, power: number, reach: number, greed: number, rescuer: number, rerolls: number },
	classes: { string },
	difficultyUnlocked: string,
	cosmetics: { owned: { string }, equipped: { [string]: string } },
	stats: {
		runs: number,
		kills: number, -- every enemy the team killed in the player's runs
		bossKills: number, -- bosses only (not champions)
		bestTime: number, -- longest run in seconds
		wins: number, -- v2
		bestWave: number, -- v2: furthest wave reached
		bestDanger: number, -- v2: highest danger level won, -1 = never won
	},
	characterStats: { [string]: CharacterStats }, -- v2, by Config.Classes id
	quests: { day: string, list: { any } },
	streak: { lastLogin: number, count: number },
	pass: { season: number, xp: number, premium: boolean, claimed: { [string]: boolean } },
	receipts: { [string]: boolean }, -- PurchaseIds that were already granted
}

local ProfileTemplate = {}

ProfileTemplate.SCHEMA_VERSION = 2

-- Fresh default data; every call returns new tables.
function ProfileTemplate.new(): Data
	return {
		schemaVersion = ProfileTemplate.SCHEMA_VERSION,
		embers = 0,
		talents = { toughness = 0, power = 0, reach = 0, greed = 0, rescuer = 0, rerolls = 0 },
		classes = { "BladeWarden", "SparkMage" },
		difficultyUnlocked = "Normal",
		cosmetics = { owned = {}, equipped = {} },
		stats = { runs = 0, kills = 0, bossKills = 0, bestTime = 0, wins = 0, bestWave = 0, bestDanger = -1 },
		characterStats = {},
		quests = { day = "", list = {} },
		streak = { lastLogin = 0, count = 0 },
		pass = { season = 1, xp = 0, premium = false, claimed = {} },
		receipts = {},
	}
end

function ProfileTemplate.newCharacterStats(): CharacterStats
	return { runs = 0, wins = 0, bestWave = 0, bestDanger = -1 }
end

return ProfileTemplate
