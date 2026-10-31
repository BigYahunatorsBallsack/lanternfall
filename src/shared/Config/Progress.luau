--!strict
-- Progress and unlocks (Paket 13, DESIGN.md section 10; Brotato direction): achievements count up over all runs and
-- unlock characters, weapons and items; each also pays Embers once. Whatever an achievement unlocks is locked until
-- it is done: locked characters cannot be picked, locked weapons and items never show up in the shop or in crates.
-- Danger levels are opened per character: winning danger d with a character opens d + 1 for it.
-- Read by Util/ProgressRules (server and client), PlayerDataService, ConfigCheck and the lobby.

export type Unlocks = {
	characters: { string }?, -- Config.Classes ids
	weapons: { string }?, -- Config.Weapons ids (never a starting weapon, ConfigCheck)
	items: { string }?, -- Config.Items ids
}

-- One achievement. Exactly one condition: `stat` + `goal` (a saved stat reaches the goal) or `winWith` (win a run
-- with that character).
export type Achievement = {
	id: string,
	name: string, -- game text
	text: string?, -- what to do; generated for `winWith` when nil
	stat: string?, -- key of the saved stats (ProfileTemplate.Data.stats)
	goal: number?,
	winWith: string?, -- Config.Classes id
	embers: number, -- paid once when it is done
	unlocks: Unlocks?,
}

local achievements: { Achievement } = {
	{ id = "FirstNight", name = "First Night", text = "Finish a run", stat = "runs", goal = 1, embers = 50 },
	{
		id = "DeepNight",
		name = "Deep Into the Night",
		text = "Reach wave 10",
		stat = "bestWave",
		goal = 10,
		embers = 100,
		unlocks = { characters = { "ManyHands" } },
	},
	{
		id = "Dawn",
		name = "Dawn",
		text = "Win a run",
		stat = "wins",
		goal = 1,
		embers = 200,
		unlocks = { items = { "LanternCodex" } },
	},
	{
		id = "ThousandShades",
		name = "A Thousand Shades",
		text = "Kill 2,000 enemies",
		stat = "kills",
		goal = 2000,
		embers = 100,
		unlocks = { characters = { "SoleConductor" } },
	},
	{
		id = "EndlessSwarm",
		name = "Endless Swarm",
		text = "Kill 20,000 enemies",
		stat = "kills",
		goal = 20000,
		embers = 300,
		unlocks = { items = { "EightEyedIdol" } },
	},
	{
		id = "ChampionHunter",
		name = "Champion Hunter",
		text = "Kill 5 champions",
		stat = "championKills",
		goal = 5,
		embers = 150,
		unlocks = { weapons = { "MortarLantern" } },
	},
	{
		id = "Kingslayer",
		name = "Kingslayer",
		text = "Kill a boss",
		stat = "bossKills",
		goal = 1,
		embers = 200,
		unlocks = { weapons = { "CathedralEngine" } },
	},
	{
		id = "Rescuer",
		name = "Rescuer",
		text = "Revive 5 teammates",
		stat = "revives",
		goal = 5,
		embers = 100,
		unlocks = { items = { "HearthSprite" } },
	},
	{
		id = "Regular",
		name = "Regular",
		text = "Finish 25 runs",
		stat = "runs",
		goal = 25,
		embers = 200,
		unlocks = { weapons = { "TithePalm" } },
	},
	-- Winning with a character unlocks the next one or a weapon/item (like Brotato's character wins)
	{
		id = "WinBladeWarden",
		name = "Warden's Oath",
		winWith = "BladeWarden",
		embers = 100,
		unlocks = { characters = { "MarbleHost" } },
	},
	{
		id = "WinSparkMage",
		name = "Kindled",
		winWith = "SparkMage",
		embers = 100,
		unlocks = { characters = { "CandleScholar" } },
	},
	{
		id = "WinNightWatch",
		name = "Long Watch",
		winWith = "NightWatch",
		embers = 100,
		unlocks = { characters = { "FarSeer" } },
	},
	{
		id = "WinDuelMaestro",
		name = "Final Bow",
		winWith = "DuelMaestro",
		embers = 100,
		unlocks = { characters = { "TwinLedger" } },
	},
	{
		id = "WinManyHands",
		name = "All Hands",
		winWith = "ManyHands",
		embers = 100,
		unlocks = { weapons = { "DuskSabre" } },
	},
	{
		id = "WinSoleConductor",
		name = "Solo",
		winWith = "SoleConductor",
		embers = 100,
		unlocks = { items = { "TitanArms" } },
	},
	{
		id = "WinFarSeer",
		name = "Foreseen",
		winWith = "FarSeer",
		embers = 100,
		unlocks = { items = { "FortuneCoin" } },
	},
	{
		id = "WinMarbleHost",
		name = "Unbroken",
		winWith = "MarbleHost",
		embers = 100,
		unlocks = { items = { "ColossusHeart" } },
	},
	{
		id = "WinTwinLedger",
		name = "Balanced Books",
		winWith = "TwinLedger",
		embers = 100,
		unlocks = { weapons = { "CinderBreath" } },
	},
	{
		id = "WinCandleScholar",
		name = "Burnt Out",
		winWith = "CandleScholar",
		embers = 100,
		unlocks = { items = { "EternalFlame" } },
	},
	-- Highest danger level won (any character)
	{
		id = "Danger1",
		name = "Brave",
		text = "Win on danger 1",
		stat = "bestDanger",
		goal = 1,
		embers = 150,
		unlocks = { items = { "CrimsonHand" } },
	},
	{
		id = "Danger3",
		name = "Fearless",
		text = "Win on danger 3",
		stat = "bestDanger",
		goal = 3,
		embers = 250,
		unlocks = { items = { "ThunderShells" } },
	},
	{
		id = "Danger5",
		name = "Lantern Saint",
		text = "Win on danger 5",
		stat = "bestDanger",
		goal = 5,
		embers = 500,
		unlocks = { items = { "PyreAshes" } },
	},
}

for _, achievement in achievements do
	table.freeze(achievement)
end

return table.freeze({
	achievements = table.freeze(achievements),
	-- Highest danger level open for a character without a win; winning danger d with it opens d + 1 (Brotato)
	startDanger = 0,
	-- Embers of a finished run (DESIGN.md section 10): Config.Economy.embers per full minute survived, per champion
	-- (perElite) and per boss, times (1 + perDangerLevel * danger), times (1 + Config.Economy.bonuses.party) with
	-- partyMinPlayers or more players in the run
	embers = table.freeze({
		perDangerLevel = 0.1,
		partyMinPlayers = 2,
	}),
})
