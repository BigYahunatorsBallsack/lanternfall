--!strict
-- Progress rules from Config.Progress as pure functions (Paket 13): achievement progress and which are newly done,
-- what is locked (characters, weapons, items) and what unlocks it, the danger levels open per character and the
-- Embers of a finished run. Shared, so the server (PlayerDataService, ShopService, UpgradeService, RunDirector) and
-- the lobby use the same rules. Tested in tests/ProgressRules.spec.luau.

local Config = require(script.Parent.Parent.Config)
local ProgressConfig = require(script.Parent.Parent.Config.Progress)

local Progress = Config.Progress

export type Kind = "characters" | "weapons" | "items"

-- What the rules read from the saved data (ProfileTemplate.Data has more).
export type Record = {
	stats: { [string]: number },
	characterStats: { [string]: { wins: number, bestDanger: number } },
}

export type RunEmbers = {
	seconds: number, -- run length
	champions: number, -- champions the team killed
	bosses: number, -- bosses the team killed
	danger: number,
	players: number, -- players in the run
	bonuses: { { label: string, share: number } }?, -- Paket 16: passes and Ember Boost (Util/PurchaseRules)
}

export type EmberLine = { label: string, amount: number }

local ProgressRules = {}

local byId: { [string]: ProgressConfig.Achievement } = {}
-- [kind][id] = the achievements that unlock it (one of them is enough)
local lockedBy: { [string]: { [string]: { string } } } = { characters = {}, weapons = {}, items = {} }
for _, achievement in Progress.achievements do
	byId[achievement.id] = achievement
	for kind, ids in (achievement.unlocks or {}) :: any do
		for _, id in ids do
			local list = lockedBy[kind][id] or {}
			table.insert(list, achievement.id)
			lockedBy[kind][id] = list
		end
	end
end

function ProgressRules.get(achievementId: string): ProgressConfig.Achievement?
	return byId[achievementId]
end

-- Current value and goal of an achievement for the progress bar (current never above the goal).
function ProgressRules.progress(achievement: ProgressConfig.Achievement, record: Record): (number, number)
	if achievement.winWith then
		local character = record.characterStats[achievement.winWith]
		return if character and character.wins > 0 then 1 else 0, 1
	end
	local goal = achievement.goal or 1
	local value = record.stats[achievement.stat or ""] or 0
	return math.clamp(value, 0, goal), goal
end

function ProgressRules.isComplete(achievement: ProgressConfig.Achievement, record: Record): boolean
	local current, goal = ProgressRules.progress(achievement, record)
	return current >= goal
end

-- Ids of the achievements the record completes that are not in `done` yet, in Config order.
function ProgressRules.newlyDone(record: Record, done: { [string]: boolean }): { string }
	local ids = {}
	for _, achievement in Progress.achievements do
		if not done[achievement.id] and ProgressRules.isComplete(achievement, record) then
			table.insert(ids, achievement.id)
		end
	end
	return ids
end

-- What the player has to do, e.g. "Reach wave 10" or "Win a run with Night Watch".
function ProgressRules.text(achievement: ProgressConfig.Achievement): string
	if achievement.text then
		return achievement.text
	end
	local class = Config.Classes[achievement.winWith or ""]
	return `Win a run with {if class then class.displayName else achievement.winWith}`
end

-- Whether some achievement unlocks this (so it starts locked).
function ProgressRules.isLockable(kind: Kind, id: string): boolean
	return lockedBy[kind][id] ~= nil
end

-- Unlocked: never locked, or one of its achievements is done (characters also when bought: `owned`).
function ProgressRules.isUnlocked(kind: Kind, id: string, done: { [string]: boolean }, owned: { string }?): boolean
	local by = lockedBy[kind][id]
	if not by then
		return true
	end
	for _, achievementId in by do
		if done[achievementId] then
			return true
		end
	end
	return owned ~= nil and table.find(owned, id) ~= nil
end

-- Every locked id of a kind as a set (shop and crates skip these).
function ProgressRules.lockedSet(kind: Kind, done: { [string]: boolean }, owned: { string }?): { [string]: boolean }
	local set = {}
	for id in lockedBy[kind] do
		if not ProgressRules.isUnlocked(kind, id, done, owned) then
			set[id] = true
		end
	end
	return set
end

-- How to unlock it, e.g. "Reach wave 10"; nil if it is never locked.
function ProgressRules.requirement(kind: Kind, id: string): string?
	local by = lockedBy[kind][id]
	return if by then ProgressRules.text(byId[by[1]]) else nil
end

-- The names of what an achievement unlocks, e.g. { "Many Hands" }.
function ProgressRules.unlockNames(achievement: ProgressConfig.Achievement): { string }
	local names = {}
	local unlocks = achievement.unlocks or {}
	for _, id in unlocks.characters or {} do
		table.insert(names, Config.Classes[id].displayName)
	end
	for _, id in unlocks.weapons or {} do
		table.insert(names, Config.Weapons[id].displayName)
	end
	for _, id in unlocks.items or {} do
		table.insert(names, Config.Items.byId[id].displayName)
	end
	return names
end

-- Highest danger level open for a character: startDanger, or one above the highest danger won with it.
function ProgressRules.maxDanger(record: Record, classId: string?): number
	local character = classId and record.characterStats[classId]
	local won = if character then character.bestDanger else -1
	return math.clamp(math.max(Progress.startDanger, won + 1), 0, #Config.Difficulty.levels - 1)
end

-- Embers of a finished run as lines for the results screen and their total. Since Paket 16 with the bonuses of
-- passes and the Ember Boost (run.bonuses) as the last lines.
function ProgressRules.runEmbers(run: RunEmbers): (number, { EmberLine })
	local base = Config.Economy.embers
	local minutes = math.floor(math.max(0, run.seconds) / 60)
	local lines: { EmberLine } = {}
	local subtotal = 0
	local function add(label: string, amount: number)
		if amount > 0 then
			table.insert(lines, { label = label, amount = amount })
			subtotal += amount
		end
	end
	add(`{minutes} min survived`, minutes * base.perMinuteSurvived)
	add(`{run.champions} champions`, run.champions * base.perElite)
	add(`{run.bosses} bosses`, run.bosses * base.bossKill)
	local total = subtotal
	local danger = subtotal * Progress.embers.perDangerLevel * math.max(0, run.danger)
	if danger >= 1 then
		table.insert(lines, { label = `Danger {run.danger}`, amount = math.floor(danger) })
		total += math.floor(danger)
	end
	if run.players >= Progress.embers.partyMinPlayers then
		local party = math.floor(total * Config.Economy.bonuses.party)
		if party > 0 then
			table.insert(lines, { label = "Party bonus", amount = party })
			total += party
		end
	end
	-- Paket 16: purchase bonuses add up, each counted from the Embers before them (not from each other)
	local before = total
	for _, bonus in run.bonuses or {} do
		local amount = math.floor(before * bonus.share)
		if amount > 0 then
			table.insert(lines, { label = `{bonus.label} (+{math.round(bonus.share * 100)}%)`, amount = amount })
			total += amount
		end
	end
	return total, lines
end

return ProgressRules
