--!strict
-- Daily quest and login streak rules from Config.Quests as pure functions (Paket 18): the UTC day, which quests a
-- player gets on a day (seeded, the same in every server), swapping one, what a finished run adds and which quests it
-- finishes, quest texts, and the login streak (next day, reward). Shared, so the server (QuestService) and the lobby
-- window (QuestController) use the same rules. Tested in tests/QuestRules.spec.luau.

local Config = require(script.Parent.Parent.Config)
local QuestsConfig = require(script.Parent.Parent.Config.Quests)

local Quests = Config.Quests

local DAY_SECONDS = 86400

-- One saved quest (ProfileTemplate.Data.quests.list). Goal and Embers are copied from the template's tier.
export type Quest = {
	id: string, -- Config.Quests.pool id
	goal: number,
	embers: number,
	classId: string?, -- withClass quests: the character to play
	progress: number,
	done: boolean,
}

-- What a finished run tells the quests (built from PlayerDataService's run record).
export type Run = {
	kills: number,
	seconds: number,
	revives: number,
	champions: number,
	wave: number,
	won: boolean,
	players: number,
	classId: string,
}

export type Streak = { lastLogin: number, count: number } -- lastLogin = QuestRules.day of the last paid login

local QuestRules = {}

local byId: { [string]: QuestsConfig.Template } = {}
for _, template in Quests.pool do
	byId[template.id] = template
end

function QuestRules.template(id: string): QuestsConfig.Template?
	return byId[id]
end

-- The UTC day number of a unix time (days since 1970-01-01).
function QuestRules.day(unixTime: number): number
	return math.floor(unixTime / DAY_SECONDS)
end

-- Seconds until the next UTC day starts.
function QuestRules.secondsToNextDay(unixTime: number): number
	return (QuestRules.day(unixTime) + 1) * DAY_SECONDS - unixTime
end

-- A small seeded generator (Park-Miller), so every server and the tests pick the same quests for a player and day.
local function generator(seed: number): (number) -> number
	local state = seed % 2147483646 + 1
	return function(count: number): number -- 1..count
		state = (state * 16807) % 2147483647
		return state % count + 1
	end
end

local function seedOf(userId: number, day: number, salt: number): number
	return (math.abs(userId) % 1000003) * 7919 + day * 104729 + salt * 15485863
end

local function newQuest(template: QuestsConfig.Template, nextIndex: (number) -> number, classes: { string }): Quest
	local tier = template.tiers[nextIndex(#template.tiers)]
	return {
		id = template.id,
		goal = tier.goal,
		embers = tier.embers,
		classId = if template.withClass then classes[nextIndex(#classes)] else nil,
		progress = 0,
		done = false,
	}
end

-- Templates that can still be picked: not in `taken`, and withClass ones only if the player has a character.
local function candidates(taken: { [string]: boolean }, classes: { string }): { QuestsConfig.Template }
	local list = {}
	for _, template in Quests.pool do
		if not taken[template.id] and (not template.withClass or #classes > 0) then
			table.insert(list, template)
		end
	end
	return list
end

-- The day's quests of a player: Config.Quests.daily different templates. `classes` are the characters the player
-- can play, sorted (withClass quests pick one of them).
function QuestRules.roll(userId: number, day: number, classes: { string }): { Quest }
	local nextIndex = generator(seedOf(userId, day, 0))
	local taken: { [string]: boolean } = {}
	local list = {}
	for _ = 1, Quests.daily do
		local options = candidates(taken, classes)
		if #options == 0 then
			break
		end
		local template = options[nextIndex(#options)]
		taken[template.id] = true
		table.insert(list, newQuest(template, nextIndex, classes))
	end
	return list
end

-- Swaps quest `index` (not done) for a quest of another template than the list has; `swapNumber` counts the swaps of
-- the day (1 = first), so each swap of the day is different. Returns the new quest or nil (done, unknown, none left).
function QuestRules.swap(
	list: { Quest },
	index: number,
	userId: number,
	day: number,
	swapNumber: number,
	classes: { string }
): Quest?
	local old = list[index]
	if not old or old.done then
		return nil
	end
	local taken: { [string]: boolean } = {}
	for _, quest in list do
		taken[quest.id] = true
	end
	local options = candidates(taken, classes)
	if #options == 0 then
		return nil
	end
	local nextIndex = generator(seedOf(userId, day, swapNumber))
	local quest = newQuest(options[nextIndex(#options)], nextIndex, classes)
	list[index] = quest
	return quest
end

-- What one finished run adds to each quest stat (Config.Quests Template.stat).
function QuestRules.runValues(run: Run): { [string]: number }
	return {
		kills = run.kills,
		minutes = math.floor(math.max(0, run.seconds) / 60),
		revives = run.revives,
		champions = run.champions,
		wave = run.wave,
		runs = 1,
		wins = if run.won then 1 else 0,
		partyRuns = if run.players >= 2 then 1 else 0,
	}
end

-- Adds a finished run to the quests (in place). Returns the quests it finished (their Embers are not paid here).
function QuestRules.applyRun(list: { Quest }, run: Run): { Quest }
	local values = QuestRules.runValues(run)
	local finished = {}
	for _, quest in list do
		local template = byId[quest.id]
		if quest.done or not template then
			continue
		end
		if template.withClass and quest.classId ~= run.classId then
			continue
		end
		local value = values[template.stat] or 0
		local progress = if template.best then math.max(quest.progress, value) else quest.progress + value
		quest.progress = math.min(progress, quest.goal)
		if quest.progress >= quest.goal then
			quest.done = true
			table.insert(finished, quest)
		end
	end
	return finished
end

-- What to do, e.g. "Kill 800 enemies" or "Survive 10 minutes with Spark Mage".
function QuestRules.text(quest: Quest): string
	local template = byId[quest.id]
	if not template then
		return quest.id
	end
	local class = quest.classId and Config.Classes[quest.classId]
	local text = string.gsub(template.text, "{goal}", tostring(quest.goal))
	text = string.gsub(text, "{class}", if class then class.displayName else "")
	return text
end

-- The streak day the login on `today` pays (1-7), or nil if today was already paid. Consecutive days go up and wrap
-- after the last day; a missed day goes back Config.Quests.streak.missedPenalty days (never below day 1).
function QuestRules.streakDay(streak: Streak, today: number): number?
	local count = streak.count
	if count > 0 and streak.lastLogin == today then
		return nil
	end
	local days = #Quests.streak.days
	local nextDay = count % days + 1
	if count > 0 and streak.lastLogin == today - 1 then
		return nextDay
	elseif count <= 0 then
		return 1
	end
	return math.max(1, nextDay - Quests.streak.missedPenalty)
end

-- What a streak day pays: Embers, or its cosmetic when the player does not own it yet (then 0 Embers).
function QuestRules.streakReward(dayNumber: number, owned: { string }): (number, string?)
	local day = Quests.streak.days[dayNumber]
	if not day then
		return 0, nil
	end
	if day.cosmetic and not table.find(owned, day.cosmetic) then
		return 0, day.cosmetic
	end
	return day.embers, nil
end

return QuestRules
