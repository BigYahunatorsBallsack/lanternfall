--!strict
-- First start "First Night" (Paket 19, DESIGN.md section 19): a new player's first join goes straight into a short,
-- easier solo run with hints. Read by FirstNightService (start, Looter, skip), RunDirector/RunFlow (the shorter run),
-- Util/DangerRules (options, label) and the client's FirstNightController and HUDController (hints, wave count).

return table.freeze({
	enabled = true,
	-- Studio playtests start in the lobby as before (the debug button "Start First Night" starts one there); live
	-- servers send every player whose data says "not played yet" into the First Night
	autoStartInStudio = false,
	startDelaySeconds = 2, -- after the data loaded, so the client's UI is ready
	label = "First Night", -- the run's difficulty text on the HUD and the results
	waves = 3, -- Brotato's first three waves (20 + 25 + 30 s fighting, two shops); surviving wave 3 wins
	-- easier than a normal danger 0 run (slider values in percent, see Config.Difficulty.sliders)
	options = table.freeze({
		danger = 0,
		enemyHp = 75,
		enemyDamage = 50,
		enemySpeed = 100,
		enemyCount = 75,
	}),
	-- a Looter shows up in this wave after a few seconds: catching it drops a crate (the "mini elite with a chest")
	looterWave = 3,
	looterDelaySeconds = 4,
	-- client hints
	moveStuds = 6, -- the "Move" hint goes away after the character walked this far
	jumpStuds = 30, -- a bigger step between two frames is a teleport (into the arena), not walking
	hintSeconds = 7, -- timed hints stay this long
	hints = table.freeze({
		move = "Move with W A S D (or the arrow keys)",
		moveTouch = "Move with the stick on the left",
		fight = "Your weapons fire on their own. Walk over the glowing orbs to level up!",
		levelUp = "Level up! Pick one card to grow stronger",
		shop = "The shop opens after every wave. Buy weapons and items with your Shards, then press READY",
		looter = "A Looter! Catch it before it runs away - it drops a crate",
		lastWave = "Last wave of the First Night - survive until dawn!",
		lobbyTitle = "Dawn breaks!",
		lobby = "You survived the First Night. Pick a character, set the danger level and start a run. "
			.. "Achievements (trophy button) open new characters.",
		skip = "Skip",
		ok = "OK",
	}),
})
