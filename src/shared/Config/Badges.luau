--!strict
-- Roblox badges (Paket 18, DESIGN.md section 11). The badges are made by the owner in the Creator Hub (experience ->
-- Engagement -> Badges); their ids go into `experiences` (0 = not set up yet, then the badge is skipped). A badge is
-- awarded once its condition is met: `join` (first visit) or a saved stat reaching `goal` (ProfileTemplate.Data.stats).
-- Read by BadgeService and ConfigCheck.

export type Badge = {
	key: string,
	name: string, -- name and text to use in the Creator Hub
	text: string,
	join: boolean?,
	stat: string?,
	goal: number?,
}

-- The badge ids of one experience. gameId 0 matches any experience (like Config.Store).
export type Ids = { name: string, gameId: number, ids: { [string]: number } }

return table.freeze({
	badges = table.freeze({
		table.freeze({ key = "Welcome", name = "Lantern Lit", text = "Join Lanternfall", join = true }),
		table.freeze({ key = "FirstNight", name = "First Night", text = "Finish a run", stat = "runs", goal = 1 }),
		table.freeze({ key = "Kingslayer", name = "Kingslayer", text = "Defeat a boss", stat = "bossKills", goal = 1 }),
		table.freeze({
			key = "TenThousand",
			name = "Ten Thousand Shades",
			text = "Kill 10,000 enemies",
			stat = "kills",
			goal = 10000,
		}),
		table.freeze({
			key = "LanternSaint",
			name = "Lantern Saint",
			text = "Win a run on danger 5",
			stat = "bestDanger",
			goal = 5,
		}),
	}) :: { Badge },
	experiences = table.freeze({
		table.freeze({
			name = "Lanternfall Test",
			gameId = 0, -- Creator Hub -> experience -> "Copy Universe ID"; 0 = any experience
			ids = table.freeze({ Welcome = 0, FirstNight = 0, Kingslayer = 0, TenThousand = 0, LanternSaint = 0 }),
		}),
	}) :: { Ids },
	attempts = 3, -- tries per award when Roblox does not answer
})
