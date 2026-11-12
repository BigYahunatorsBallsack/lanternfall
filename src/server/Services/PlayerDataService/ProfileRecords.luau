--!strict
-- What a finished run adds to the saved data (record, Embers and achievements since Paket 13), the lobby summary and
-- a readable dump for the Output (pure, tests/PlayerDataRules.spec.luau). Used by PlayerDataService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProgressRules = require(ReplicatedStorage.Shared.Util.ProgressRules)
local Types = require(ReplicatedStorage.Shared.Net.Types)
local ProfileTemplate = require(script.Parent.ProfileTemplate)
local Zones = require(ReplicatedStorage.Shared.Config.NativeZones)
local Characters = require(ReplicatedStorage.Shared.Config.CharacterCatalog)
local Nightmare = require(ReplicatedStorage.Shared.Config.Nightmare)
local NightmareRules = require(ReplicatedStorage.Shared.Util.NightmareRules)

export type RunRecord = {
	won: boolean,
	wave: number, -- the wave the run ended in
	danger: number, -- original danger level; the playable selection is gated independently
	zoneId: number?, -- original server-captured area; absent on legacy/unscoped records
	classId: string, -- the character played
	kills: number, -- team kills of the run
	bossKills: number,
	seconds: number, -- run length
	champions: number?, -- Paket 13: champions the team killed
	revives: number?, -- Paket 13: teammates this player revived
	players: number?, -- Paket 13: players in the run (party bonus)
	bonuses: { { label: string, share: number } }?, -- Paket 16: Ember bonuses of passes and the Ember Boost
	firstNight: boolean?, -- Paket 19: the short First Night run (never a win, no leaderboard score)
	debug: boolean?, -- Paket 23: changed by an admin's debug commands (no leaderboard score)
}

local ProfileRecords = {}

function ProfileRecords.nightmareUnlocked(data: ProfileTemplate.Data): boolean
	local canonical: { [string]: { [number]: number } } = {}
	for classId, zones in data.nativeZoneBest do
		if Characters[classId] and type(zones) == "table" then
			local best = {}
			for zoneId, danger in zones do
				local zone = Zones.byId[zoneId]
				if
					zone
					and type(danger) == "number"
					and danger >= 0
					and danger <= Nightmare.level
					and danger == math.floor(danger)
				then
					best[zone.id] = danger
				end
			end
			canonical[classId] = best
		end
	end
	return NightmareRules.unlocked(canonical)
end

-- Marks every achievement the data completes as done and pays its Embers (in place). Returns the new ids and the
-- names of what they unlocked.
function ProfileRecords.completeAchievements(data: ProfileTemplate.Data): ({ string }, { string }, number)
	local ids = ProgressRules.newlyDone(data :: any, data.achievements)
	local unlocked = {}
	local embers = 0
	for _, id in ids do
		local achievement = ProgressRules.get(id) :: any
		data.achievements[id] = true
		embers += achievement.embers
		for _, name in ProgressRules.unlockNames(achievement) do
			table.insert(unlocked, name)
		end
	end
	data.embers += embers
	data.stats.embersEarned += embers
	return ids, unlocked, embers
end

-- Adds one finished run to the player's data (in place): record, the run's Embers and achievements it completes.
-- Returns what the run paid (results screen).
function ProfileRecords.applyRun(data: ProfileTemplate.Data, run: RunRecord): Types.RunRewards
	local stats = data.stats
	stats.runs += 1
	-- Paket 19: any finished run means the First Night is not needed any more
	data.tutorial = data.tutorial or { firstNight = true, lobbyHint = false }
	data.tutorial.firstNight = true
	stats.kills += run.kills
	stats.bossKills += run.bossKills
	stats.championKills += run.champions or 0
	stats.revives += run.revives or 0
	stats.bestTime = math.max(stats.bestTime, math.floor(run.seconds))
	stats.bestWave = math.max(stats.bestWave, run.wave)
	if run.won then
		stats.wins += 1
		stats.bestDanger = math.max(stats.bestDanger, run.danger)
	end

	if run.classId ~= "" then
		local character = data.characterStats[run.classId] or ProfileTemplate.newCharacterStats()
		character.runs += 1
		character.bestWave = math.max(character.bestWave, run.wave)
		if run.won then
			character.wins += 1
			character.bestDanger = math.max(character.bestDanger, run.danger)
		end
		data.characterStats[run.classId] = character
	end
	-- Only complete, area-identified native results can establish this distinct-character/zone prerequisite.
	if
		run.won
		and not run.firstNight
		and run.wave >= #Config.Run.spawn.waves.lengthsSeconds
		and type(run.zoneId) == "number"
		and Zones.byId[tostring(run.zoneId)]
		and Characters[run.classId]
		and run.danger >= 0
		and run.danger <= Nightmare.level
		and run.danger == math.floor(run.danger)
	then
		local zones = data.nativeZoneBest[run.classId]
		if type(zones) ~= "table" then
			zones = {}
		end
		local key = tostring(run.zoneId)
		local previous = zones[key]
		if
			type(previous) ~= "number"
			or previous < 0
			or previous > Nightmare.level
			or previous ~= math.floor(previous)
		then
			previous = -1
		end
		zones[key] = math.max(previous, run.danger)
		data.nativeZoneBest[run.classId] = zones
	end

	local embers, lines = ProgressRules.runEmbers({
		seconds = run.seconds,
		champions = run.champions or 0,
		bosses = run.bossKills,
		danger = run.danger,
		players = run.players or 1,
		bonuses = run.bonuses,
	})
	data.embers += embers
	stats.embersEarned += embers
	local ids, unlocked, bonus = ProfileRecords.completeAchievements(data)
	return {
		embers = embers + bonus,
		lines = lines,
		achievements = ids,
		unlocked = unlocked,
		totalEmbers = data.embers,
	}
end

-- The local player's record for the lobby.
function ProfileRecords.info(data: ProfileTemplate.Data, saveMode: Types.SaveMode): Types.ProfileInfo
	local stats = data.stats
	local progress = {}
	for _, achievement in Config.Progress.achievements do
		progress[achievement.id] = (ProgressRules.progress(achievement, data :: any))
	end
	local characterDanger = {}
	local nightmareUnlocked = ProfileRecords.nightmareUnlocked(data)
	for classId, class in Config.Classes do
		if class.available then
			characterDanger[classId] = ProgressRules.maxDanger(data :: any, classId, nightmareUnlocked)
		end
	end
	return {
		saveMode = saveMode,
		nativeNightmareUnlocked = nightmareUnlocked,
		schemaVersion = data.schemaVersion,
		runs = stats.runs,
		wins = stats.wins,
		kills = stats.kills,
		bossKills = stats.bossKills,
		bestWave = stats.bestWave,
		bestDanger = stats.bestDanger,
		embers = data.embers,
		achievements = table.clone(data.achievements),
		progress = progress,
		characterDanger = characterDanger,
		ownedClasses = table.clone(data.classes),
		settings = if type(data.settings) == "table" then table.clone(data.settings) else nil,
		cosmetics = {
			owned = table.clone(data.cosmetics.owned),
			equipped = table.clone(data.cosmetics.equipped),
		},
	}
end

local function dumpInto(lines: { string }, value: any, indent: string)
	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, key in keys do
		local item = value[key]
		if type(item) == "table" then
			if next(item) == nil then
				table.insert(lines, `{indent}{key} = \{}`)
			else
				table.insert(lines, `{indent}{key}:`)
				dumpInto(lines, item, indent .. "  ")
			end
		else
			table.insert(lines, `{indent}{key} = {tostring(item)}`)
		end
	end
end

-- Every saved value as sorted "key = value" lines (debug button "Print my saved data").
function ProfileRecords.dump(data: any): { string }
	local lines = {}
	dumpInto(lines, data, "")
	return lines
end

return ProfileRecords
