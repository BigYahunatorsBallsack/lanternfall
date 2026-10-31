--!strict
-- Default player data, schema v7 (DESIGN.md section 16). Used by PlayerDataService (ProfileStore template) and
-- Migrations. Schema change = SCHEMA_VERSION + 1 and a step in Migrations; never drop a field without a step.

-- One character's record (Paket 12; since Paket 13 it opens the danger levels per character, Util/ProgressRules).
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
		championKills: number, -- v3: champions killed by the team in the player's runs
		revives: number, -- v3: teammates this player revived
		embersEarned: number, -- v3: every Ember ever earned (runs and achievements)
		embersBought: number, -- v5: Embers from Robux packs (not in embersEarned)
		purchases: number, -- v5: developer products granted
	},
	achievements: { [string]: boolean }, -- v3: Config.Progress achievement ids that are done
	characterStats: { [string]: CharacterStats }, -- v2, by Config.Classes id
	-- v6 (Paket 18): the UTC day of the list (Util/QuestRules.day as text, "" = none yet), the day's quests
	-- (QuestRules.Quest) and the swaps used that day
	quests: { day: string, list: { any }, swaps: number },
	streak: { lastLogin: number, count: number }, -- v6: lastLogin = UTC day of the last paid login, count = its day 1-7
	pass: { season: number, xp: number, premium: boolean, claimed: { [string]: boolean } },
	receipts: { string }, -- PurchaseIds already granted, oldest first (v5: a list, was an unused map before)
	settings: { shake: boolean, damageNumbers: boolean, music: number, effects: number }, -- v4 (Config.Settings)
	tokens: { revives: number, rerolls: number }, -- v5: bought revives and shop rerolls not used yet
	passCache: { [string]: boolean }, -- v5: game passes owned when last checked (used when the check fails)
	boost: { untilTime: number, by: string }, -- v5: Ember Boost until this os.time(), started by this player name
	badges: { [string]: boolean }, -- v6: Config.Badges keys awarded (or found owned)
	weekly: { week: number, best: { [string]: number } }, -- v6: this week's best leaderboard scores (LeaderboardRules)
	-- v7 (Paket 19): the First Night was played (or skipped) or a run was finished; lobbyHint = the lobby hint after the
	-- First Night is still to be shown (on the hub after the teleport back)
	tutorial: { firstNight: boolean, lobbyHint: boolean },
}

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local ProfileTemplate = {}

ProfileTemplate.SCHEMA_VERSION = 7

-- Default settings (Config.Settings.defaults) as a new table (v4).
function ProfileTemplate.newSettings(): { shake: boolean, damageNumbers: boolean, music: number, effects: number }
	local defaults = Config.Settings.defaults
	return {
		shake = defaults.shake,
		damageNumbers = defaults.damageNumbers,
		music = defaults.music,
		effects = defaults.effects,
	}
end

-- Fresh default data; every call returns new tables.
function ProfileTemplate.new(): Data
	return {
		schemaVersion = ProfileTemplate.SCHEMA_VERSION,
		embers = 0,
		talents = { toughness = 0, power = 0, reach = 0, greed = 0, rescuer = 0, rerolls = 0 },
		classes = { "BladeWarden", "SparkMage" },
		difficultyUnlocked = "Normal",
		cosmetics = { owned = {}, equipped = {} },
		stats = {
			runs = 0,
			kills = 0,
			bossKills = 0,
			bestTime = 0,
			wins = 0,
			bestWave = 0,
			bestDanger = -1,
			championKills = 0,
			revives = 0,
			embersEarned = 0,
			embersBought = 0,
			purchases = 0,
		},
		achievements = {},
		characterStats = {},
		quests = { day = "", list = {}, swaps = 0 },
		streak = { lastLogin = 0, count = 0 },
		pass = { season = 1, xp = 0, premium = false, claimed = {} },
		receipts = {},
		settings = ProfileTemplate.newSettings(),
		tokens = { revives = 0, rerolls = 0 },
		passCache = {},
		boost = { untilTime = 0, by = "" },
		badges = {},
		weekly = { week = 0, best = {} },
		tutorial = { firstNight = false, lobbyHint = false },
	}
end

function ProfileTemplate.newCharacterStats(): CharacterStats
	return { runs = 0, wins = 0, bestWave = 0, bestDanger = -1 }
end

return ProfileTemplate
