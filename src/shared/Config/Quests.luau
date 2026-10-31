--!strict
-- Daily quests and the login streak (Paket 18, DESIGN.md section 11). Every player gets `daily` quests per UTC day,
-- picked from `pool` by a seed of the player and the day; finished runs count towards them and a quest pays its Embers
-- once when it is done. One quest a day can be swapped for another. The login streak pays something on the first
-- login of each UTC day: Embers on days 1-6, a cosmetic on day 7 (Embers instead once it is owned), then day 1 again.
-- Read by Util/QuestRules (server and client), QuestService and QuestController.

-- One way to fill a quest. `goal` and `embers` of the picked tier are saved with the quest, so changing the numbers
-- here never changes a quest a player already has.
export type Tier = { goal: number, embers: number }

-- `stat` is what a finished run adds (Util/QuestRules.runValues): kills (team kills), minutes (full minutes survived
-- with the quest's character), revives (teammates this player revived), champions, wave (wave reached; best of the
-- day, not a sum), runs, wins, partyRuns (runs with 2+ players).
export type Template = {
	id: string,
	text: string, -- game text; {goal} and {class} are filled in
	stat: string,
	best: boolean?, -- progress is the best single run of the day instead of the sum
	withClass: boolean?, -- picks one of the player's characters ({class}); only runs with it count
	tiers: { Tier },
}

-- One day of the login streak: Embers, or a cosmetic (Config.Cosmetics id with reward = "Streak") and the Embers
-- paid instead once the player owns it.
export type StreakDay = { embers: number, cosmetic: string? }

local pool: { Template } = {
	{
		id = "Kills",
		text = "Kill {goal} enemies",
		stat = "kills",
		tiers = { { goal = 800, embers = 50 }, { goal = 1500, embers = 75 } },
	},
	{
		id = "Survive",
		text = "Survive {goal} minutes with {class}",
		stat = "minutes",
		withClass = true,
		tiers = { { goal = 10, embers = 75 } },
	},
	{ id = "Revive", text = "Revive {goal} teammates", stat = "revives", tiers = { { goal = 2, embers = 100 } } },
	{ id = "Champions", text = "Kill {goal} champions", stat = "champions", tiers = { { goal = 3, embers = 75 } } },
	{
		id = "Wave",
		text = "Reach wave {goal}",
		stat = "wave",
		best = true,
		tiers = { { goal = 12, embers = 75 }, { goal = 16, embers = 100 } },
	},
	{ id = "Runs", text = "Finish {goal} runs", stat = "runs", tiers = { { goal = 3, embers = 50 } } },
	{ id = "Win", text = "Win a run", stat = "wins", tiers = { { goal = 1, embers = 100 } } },
	{
		id = "Party",
		text = "Finish {goal} runs with friends (2+ players)",
		stat = "partyRuns",
		tiers = { { goal = 2, embers = 75 } },
	},
}

for _, template in pool do
	for _, tier in template.tiers do
		table.freeze(tier)
	end
	table.freeze(template.tiers)
	table.freeze(template)
end

return table.freeze({
	daily = 3, -- quests per day
	swapsPerDay = 1, -- quests a player may swap per day (only quests that are not done)
	pool = table.freeze(pool),
	checkSeconds = 30, -- how often QuestService looks for a new day for players in the server
	streak = table.freeze({
		days = table.freeze({
			table.freeze({ embers = 25 }),
			table.freeze({ embers = 50 }),
			table.freeze({ embers = 75 }),
			table.freeze({ embers = 100 }),
			table.freeze({ embers = 125 }),
			table.freeze({ embers = 150 }),
			table.freeze({ embers = 300, cosmetic = "VigilLantern" }),
		}) :: { StreakDay },
		-- A missed day does not end the streak, it only goes back this many days (DESIGN.md section 11): after day 5
		-- and a missed day the next login pays day 4 instead of day 6. Never below day 1.
		missedPenalty = 2,
	}),
	-- Game texts
	texts = table.freeze({
		questDone = "Quest done: ", -- + quest text + " +N Embers"
		streakDay = "Login streak day ", -- + day + ": " + reward
		swapUsed = "No quest swaps left today",
		swapDone = "That quest is already done",
		notLoaded = "Your saved data is not loaded yet",
	}),
})
