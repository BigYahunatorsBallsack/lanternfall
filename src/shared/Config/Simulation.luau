--!strict
-- Enemy engine settings and performance budgets (DESIGN.md section 15). Read by EnemySim, SpawnDirector,
-- WeaponService, EnemyRenderer and the debug stats panel. Values marked "assumption" get tuned in playtests (WP7, WP9).

local Stats = require(script.Parent.Stats)
local PlayerColliders = require(script.Parent.PlayerColliders)

-- Brotato 1.2.0.1 measured at 0.1 studs per pixel: the potato is 75 px tall (body 69 px with its feet,
-- entities/units/player), our figures were drawn 5.4 studs tall. Bodies (figures, hit circles, drops) grow by this so they
-- have Brotato's size next to the arena, speeds and ranges (09.11.2026).
local BROTATO_FIGURE_PIXELS = 75
local OLD_FIGURE_STUDS = 5.4

return table.freeze({
	bodyScale = BROTATO_FIGURE_PIXELS * Stats.range.studsPerPoint / OLD_FIGURE_STUDS,
	tickRate = 15, -- server simulation steps per second
	maxCatchUpSteps = 3, -- after a server hitch at most this many steps run in one frame, the rest is dropped
	spatialHashCellSize = 8, -- studs
	interpolationDelay = 0.1, -- seconds the client renders behind the newest snapshot

	-- Native player hurt radius for damage overlap; physical body geometry is stored separately in PlayerColliders.
	playerRadius = PlayerColliders.hurt.radiusPoints * Stats.range.studsPerPoint,
	contactMargin = 0, -- native Area2D overlap uses the actual circles, without additional gameplay padding
	enemyPlayerBodyCollision = false, -- native enemy layer4/mask132 and player layer2/mask130 exclude each other; see player-enemy-body-filter-source.json
	-- Brotato 1.2.0.1 Enemy._on_hit_something: after its touch lands, an enemy loses max(200, 0.8 x its speed) speed
	-- points (px/s) as a decaying slow (EnemySim.contactRecoil), so it stops for a moment
	contactRecoil = table.freeze({ minPoints = 200, speedShare = 0.8 }),
	-- Players see enemies a little in the past (interpolationDelay + travel time) while the server sees the
	-- player a little in the past too. Contacts are therefore checked where the player is moving to:
	-- position + velocity * (contactLeadSeconds + ping), at most contactLeadMaxStuds ahead.
	contactLeadSeconds = 0.15,
	contactLeadMaxPing = 0.3, -- seconds; higher pings count as this
	contactLeadMaxStuds = 5,
	separationStiffness = 0.8, -- share of the overlap of two enemies removed per pass, 0-1 (assumption)
	separationPasses = 5, -- settles dense crowds at the original movement scale; still checked against the step budget
	obstacleSteerMargin = 2, -- studs; enemies start sliding around an obstacle this far from it (assumption)
	keepDistanceTolerance = 2, -- studs; ranged enemies stand still within +- this of their keepDistance
	-- Weapons step right after the enemies (WeaponService). A spinning blade is checked in pieces so its tip
	-- moves at most this far per check; smaller is more exact but costs more server time.
	weaponSweepStep = 1.5, -- studs

	-- Shown in the admin stats panel; red when a value breaks its budget.
	budget = table.freeze({
		stepMilliseconds = 4, -- server time per simulation step
		clientFps = 30, -- at least, on a mid-range phone
		networkKilobytesPerSecond = 50, -- at most, per client
		clientMemoryMegabytes = 1000, -- at most on a phone (Paket 22, assumption: low-end phones close apps far above it)
	}),

	-- Paket 22: estimated bytes per remote call (Net/NetSize). Roblox does not publish its format; these follow
	-- community measurements (assumption). Only used by the performance spec (tests/Perf22); in the game the debug
	-- panel reads Roblox's own counter (Stats.DataReceiveKbps).
	netSize = table.freeze({
		callOverhead = 9, -- per call: which remote, how many arguments
		typeByte = 1, -- every value
		number = 8, -- a double
		maxDepth = 8, -- nested tables deeper than this count as empty
		other = table.freeze({
			Vector3 = 12,
			Vector2 = 8,
			CFrame = 24,
			Color3 = 12,
			EnumItem = 3,
			Instance = 4,
			default = 8,
		}),
	}),
})
