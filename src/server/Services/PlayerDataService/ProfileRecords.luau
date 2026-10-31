--!strict
-- What a finished run adds to the saved data, the lobby summary and a readable dump for the Output (pure,
-- tests/PlayerDataRules.spec.luau). Used by PlayerDataService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Net.Types)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

export type RunRecord = {
	won: boolean,
	wave: number, -- the wave the run ended in
	danger: number, -- danger level 0-5 (B11)
	classId: string, -- the character played
	kills: number, -- team kills of the run
	bossKills: number,
	seconds: number, -- run length
}

local ProfileRecords = {}

-- Adds one finished run to the player's data (in place).
function ProfileRecords.applyRun(data: ProfileTemplate.Data, run: RunRecord)
	local stats = data.stats
	stats.runs += 1
	stats.kills += run.kills
	stats.bossKills += run.bossKills
	stats.bestTime = math.max(stats.bestTime, math.floor(run.seconds))
	stats.bestWave = math.max(stats.bestWave, run.wave)
	if run.won then
		stats.wins += 1
		stats.bestDanger = math.max(stats.bestDanger, run.danger)
	end

	if run.classId == "" then
		return
	end
	local character = data.characterStats[run.classId] or ProfileTemplate.newCharacterStats()
	character.runs += 1
	character.bestWave = math.max(character.bestWave, run.wave)
	if run.won then
		character.wins += 1
		character.bestDanger = math.max(character.bestDanger, run.danger)
	end
	data.characterStats[run.classId] = character
end

-- The local player's record for the lobby.
function ProfileRecords.info(data: ProfileTemplate.Data, saveMode: Types.SaveMode): Types.ProfileInfo
	local stats = data.stats
	return {
		saveMode = saveMode,
		schemaVersion = data.schemaVersion,
		runs = stats.runs,
		wins = stats.wins,
		kills = stats.kills,
		bossKills = stats.bossKills,
		bestWave = stats.bestWave,
		bestDanger = stats.bestDanger,
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
