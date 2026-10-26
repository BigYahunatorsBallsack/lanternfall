-- Balance simulation: plays whole runs headlessly with the real server code (tests/helpers/RobloxMock) and a bot
-- instead of a human, then prints when the bot died, the team level per minute and its build.
-- Not part of the normal test run (slow). Run it with:
--   cargo run --release --manifest-path tools/luau-test-runner/Cargo.toml -- . tests/balance/BalanceSim.luau
-- Bots: "idle" never moves, "evade" walks away from nearby enemies and collects XP orbs when it is safe, "kite" runs
-- a wide circle with detours for orbs, "fight" keeps enemies at weapon
-- distance (the closest to an average player), "stop3" kites until 3:00 and then stands still (DESIGN.md section 9: "without dodging dead from minute 3 in under 20 s").
-- Change SCENARIOS / SEEDS below to test other setups. Results feed the balancing notes in DESIGN.md.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local RunDirector = require(Services.RunDirector)
local EnemySim = require(Services.EnemySim)
local CombatService = require(Services.CombatService)
local UpgradeService = require(Services.UpgradeService)
local RunStatsService = require(Services.RunStatsService)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local DT = 1 / 15 -- one enemy simulation step per frame
local PICK_DELAY = 1.5 -- seconds a bot needs to pick a card (a human: 1-3 s)
local EVADE_RANGE = 20 -- studs; the evade bot reacts to enemies this close
local KITE_RADIUS = 50 -- studs around the arena center
local FIGHT_DISTANCE = { BladeWarden = 6, SparkMage = 14 } -- studs the fight bot keeps enemies away
local STOP_AT = 180 -- seconds; the stop3 bot stands still from here on
local MAX_SECONDS = Config.Run.durationSeconds + 5

local SEEDS = { 11, 22, 33 }
local SCENARIOS = {
	{ class = "BladeWarden", bot = "idle" },
	{ class = "BladeWarden", bot = "stop3" },
	{ class = "BladeWarden", bot = "evade" },
	{ class = "BladeWarden", bot = "kite" },
	{ class = "BladeWarden", bot = "fight" },
	{ class = "SparkMage", bot = "idle" },
	{ class = "SparkMage", bot = "stop3" },
	{ class = "SparkMage", bot = "evade" },
	{ class = "SparkMage", bot = "kite" },
	{ class = "SparkMage", bot = "fight" },
}

local bot = world.addPlayer("Bot", 1, true) -- local player, so the XpOrbs remote reaches the bot
world.advance(0.5, DT)

local center = Config.Map.arena.center
local nearbyIds: { number } = {}

-- Simple card taste: upgrade owned weapons, then new weapons, then passives; rewards last.
local function pickCard(cards)
	local best, bestScore = cards[1], -1
	for _, card in cards do
		local score = (if card.kind == "Weapon" then 3 elseif card.kind == "Passive" then 2 else 0)
			+ (if card.isNew then 0 else 1)
		if score > bestScore then
			best, bestScore = card, score
		end
	end
	return best
end

-- XP orbs as a client sees them (XpOrbs remote), so bots can walk over to collect them.
local orbs: { [number]: Vector3 } = {}
world.getRemote("XpOrbs").OnClientEvent:Connect(function(events)
	if events.reset then
		table.clear(orbs)
	end
	for i = 1, #events.orbs, 4 do
		orbs[events.orbs[i]] = Vector3.new(events.orbs[i + 1], 0, events.orbs[i + 2])
	end
	for i = 1, #events.collected, 2 do
		orbs[events.collected[i]] = nil
	end
end)

local function unit(x, z)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-4 then
		return 0, 0
	end
	return x / length, z / length
end

-- Push away from enemies within `range` (closer = stronger) and the distance to the closest one.
local function threat(position, range)
	local px, pz, closest = 0, 0, math.huge
	local found = EnemySim.queryRadius(position, range, nearbyIds)
	for i = 1, found do
		local enemy = EnemySim.getPosition(nearbyIds[i])
		if enemy then
			local dx, dz = position.X - enemy.X, position.Z - enemy.Z
			local distance = math.max(math.sqrt(dx * dx + dz * dz), 0.5)
			closest = math.min(closest, distance)
			local weight = (1 - math.min(distance / range, 1)) ^ 2
			px += dx / distance * weight
			pz += dz / distance * weight
		end
	end
	return px, pz, closest
end

-- Unit direction to the nearest orb within `range`, or 0, 0.
local function orbPull(position, range)
	local bestX, bestZ, best = 0, 0, range
	for _, orb in orbs do
		local dx, dz = orb.X - position.X, orb.Z - position.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < best then
			bestX, bestZ, best = dx, dz, distance
		end
	end
	return unit(bestX, bestZ)
end

-- Direction the bot wants to walk this frame (x, z), or 0, 0 to stand.
local function steer(kind, classId, position, elapsed, angle)
	if kind == "idle" or (kind == "stop3" and elapsed >= STOP_AT) then
		return 0, 0
	end
	local fromCenterX, fromCenterZ = position.X - center.X, position.Z - center.Z
	if kind == "kite" or kind == "stop3" then
		-- run the circle, step aside for orbs nearby, dodge enemies right in the way
		local cx, cz = unit(
			center.X + math.cos(angle) * KITE_RADIUS - position.X,
			center.Z + math.sin(angle) * KITE_RADIUS - position.Z
		)
		local ox, oz = orbPull(position, 15)
		local tx, tz, closest = threat(position, 8)
		local orbWeight = if closest > 6 then 0.8 else 0
		return unit(cx + ox * orbWeight + tx * 3, cz + oz * orbWeight + tz * 3)
	end
	local fromCenter = math.sqrt(fromCenterX * fromCenterX + fromCenterZ * fromCenterZ)
	local wx, wz = 0, 0
	if fromCenter > 100 then
		wx, wz = -fromCenterX / fromCenter, -fromCenterZ / fromCenter
	end
	if kind == "fight" then
		-- let enemies come into weapon range, back off when they get closer than that, grab orbs in between
		local keep = FIGHT_DISTANCE[classId]
		local tx, tz, closest = threat(position, keep)
		local ox, oz = orbPull(position, 30)
		local orbWeight = if closest > keep then 1.5 else 0.2
		return unit(tx * 4 + ox * orbWeight + wx, tz * 4 + oz * orbWeight + wz)
	end
	-- evade: get away from enemies, collect orbs when nothing is close, stay off the walls
	local tx, tz, closest = threat(position, EVADE_RANGE)
	local ox, oz = orbPull(position, 40)
	local orbWeight = if closest > 10 then 1 else 0.2
	return unit(tx * 4 + ox * orbWeight + wx, tz * 4 + oz * orbWeight + wz)
end

local function waitForPhase(name, limit)
	local waited = 0
	while RunDirector.getPhase() ~= name and waited < limit do
		world.step(DT)
		waited += DT
	end
	assert(RunDirector.getPhase() == name, `phase {RunDirector.getPhase()} instead of {name}`)
end

local function playRun(scenario, seed)
	math.randomseed(seed)
	world.fireServerAs(bot, "SelectClass", scenario.class)
	world.fireServerAs(bot, "SetReady", true)
	waitForPhase("Running", 15)

	local offerSeenAt = nil
	local angle = 0
	local minuteRows = {}
	local nextMinute = 60
	while RunDirector.isActive() and RunDirector.getElapsed() < MAX_SECONDS do
		local elapsed = RunDirector.getElapsed()
		local root = bot.Character.HumanoidRootPart
		local humanoid = bot.Character.Humanoid
		local speed = humanoid.WalkSpeed
		local position = root.Position

		local dx, dz = steer(scenario.bot, scenario.class, position, elapsed, angle)
		if speed > 0 and (dx ~= 0 or dz ~= 0) then
			root.Position = position + Vector3.new(dx, 0, dz) * speed * DT
			root.AssemblyLinearVelocity = Vector3.new(dx, 0, dz) * speed
			angle += speed * DT / KITE_RADIUS
		else
			root.AssemblyLinearVelocity = Vector3.zero
		end

		local offer = UpgradeService.getOffer(bot)
		if offer then
			offerSeenAt = offerSeenAt or elapsed
			if elapsed - offerSeenAt >= PICK_DELAY then
				world.fireServerAs(bot, "ChooseUpgrade", pickCard(offer).id)
				offerSeenAt = nil
			end
		else
			offerSeenAt = nil
		end

		if elapsed >= nextMinute then
			local hp, maxHp = CombatService.getHp(bot)
			table.insert(
				minuteRows,
				`{nextMinute // 60}m L{RunStatsService.getTally():getLevel()} {hp}/{maxHp}hp {EnemySim.getCount()}e`
			)
			nextMinute += 60
		end
		world.step(DT)
	end

	local survived = RunDirector.getElapsed()
	local tally = RunStatsService.getTally()
	waitForPhase("Ended", 2)
	waitForPhase("Lobby", Config.Run.flow.resultsSeconds + 2)
	return {
		survived = survived,
		level = tally:getLevel(),
		kills = tally.kills,
		minutes = minuteRows,
	}
end

local function format(seconds)
	return string.format("%d:%02d", seconds // 60, math.floor(seconds % 60))
end

describe("balance sim", function()
	local summary = {}
	for _, scenario in SCENARIOS do
		it(`{scenario.class} / {scenario.bot}`, function()
			local times, levels = {}, {}
			for _, seed in SEEDS do
				local result = playRun(scenario, seed)
				print(`  seed {seed}: {format(result.survived)}, level {result.level}, {result.kills} kills`)
				print(`    {table.concat(result.minutes, " | ")}`)
				local shown = if scenario.bot == "stop3" and result.survived >= STOP_AT
					then `{format(result.survived)} (+{math.floor(result.survived - STOP_AT)}s)`
					else format(result.survived)
				table.insert(times, shown)
				table.insert(levels, `L{result.level}`)
			end
			table.insert(
				summary,
				`{scenario.class} / {scenario.bot}: {table.concat(times, ", ")} · {table.concat(levels, ", ")}`
			)
			expect(#world.errors).toBe(0)
		end)
	end
	it("summary", function()
		print("\n===== Balance summary (survived time, final team level per seed) =====")
		for _, line in summary do
			print(line)
		end
	end)
end)
