--!strict
-- Upgrades saved player data step by step to ProfileTemplate.SCHEMA_VERSION (pure, tests/PlayerDataRules.spec.luau).
-- Called by PlayerDataService right after a profile loads, before ProfileStore's Reconcile fills in missing keys.
-- Every schema change adds one step here; steps only add or convert fields, they never drop one.

local ProfileTemplate = require(script.Parent.ProfileTemplate)

local Migrations = {}

-- steps[v] turns data of version v into version v + 1 (in place).
local steps: { [number]: (data: any) -> () } = {
	-- v1 -> v2 (Paket 12): wins, furthest wave and highest danger won, plus a record per character
	[1] = function(data)
		local stats = if type(data.stats) == "table" then data.stats else {}
		data.stats = stats
		stats.wins = stats.wins or 0
		stats.bestWave = stats.bestWave or 0
		stats.bestDanger = stats.bestDanger or -1
		if type(data.characterStats) ~= "table" then
			data.characterStats = {}
		end
	end,
	-- v2 -> v3 (Paket 13): champion kills, revives, Embers earned and the achievements that are done
	[2] = function(data)
		local stats = if type(data.stats) == "table" then data.stats else {}
		data.stats = stats
		stats.championKills = stats.championKills or 0
		stats.revives = stats.revives or 0
		stats.embersEarned = stats.embersEarned or 0
		if type(data.achievements) ~= "table" then
			data.achievements = {}
		end
	end,
	-- v3 -> v4 (Paket 14): settings from the settings menu (ProfileStore's Reconcile would add them too)
	[3] = function(data)
		if type(data.settings) ~= "table" then
			data.settings = ProfileTemplate.newSettings()
		end
	end,
	-- v4 -> v5 (Paket 16): receipts become a list (oldest first), purchase counters, tokens, pass cache and boost
	[4] = function(data)
		local receipts = {}
		if type(data.receipts) == "table" then
			for key, value in data.receipts do
				if type(key) == "string" and value == true then
					table.insert(receipts, key) -- old map: no order known
				elseif type(key) == "number" and type(value) == "string" then
					table.insert(receipts, value)
				end
			end
			table.sort(receipts)
		end
		data.receipts = receipts
		local stats = if type(data.stats) == "table" then data.stats else {}
		data.stats = stats
		stats.embersBought = stats.embersBought or 0
		stats.purchases = stats.purchases or 0
		if type(data.tokens) ~= "table" then
			data.tokens = { revives = 0, rerolls = 0 }
		end
		if type(data.passCache) ~= "table" then
			data.passCache = {}
		end
		if type(data.boost) ~= "table" then
			data.boost = { untilTime = 0, by = "" }
		end
	end,
	-- v5 -> v6 (Paket 18): daily quests with swaps, the login streak by UTC day, badges and weekly leaderboard bests.
	-- quests and streak were never used before, so they start fresh.
	[5] = function(data)
		data.quests = { day = "", list = {}, swaps = 0 }
		data.streak = { lastLogin = 0, count = 0 }
		if type(data.badges) ~= "table" then
			data.badges = {}
		end
		if type(data.weekly) ~= "table" then
			data.weekly = { week = 0, best = {} }
		end
	end,
	-- v6 -> v7 (Paket 19): the First Night is done for everyone who already finished a run.
	[6] = function(data)
		local stats = if type(data.stats) == "table" then data.stats else {}
		local runs = if type(stats.runs) == "number" then stats.runs else 0
		data.tutorial = { firstNight = runs > 0, lobbyHint = false }
	end,
}

Migrations.steps = steps

-- Runs every step from the data's version up to `target`. Returns the version the data had. Data from a newer schema
-- (a newer server wrote it) is left untouched; PlayerDataService warns about it.
function Migrations.run(data: any, target: number): number
	local from = if type(data.schemaVersion) == "number" then data.schemaVersion else 1
	local version = from
	while version < target do
		local step = steps[version]
		assert(step, `No migration from schema {version}`)
		step(data)
		version += 1
	end
	if version > from then
		data.schemaVersion = version
	end
	return from
end

return Migrations
