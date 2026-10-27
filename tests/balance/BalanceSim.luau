-- Balance simulation: plays whole runs headlessly with the real server code (tests/helpers/RobloxMock) and a bot
-- instead of a human, then prints when the bot died, the team level per minute and its build.
-- Not part of the normal test run (slow). Run it with:
--   cargo run --release --manifest-path tools/luau-test-runner/Cargo.toml -- . tests/balance/BalanceSim.luau
-- Bots: "idle" never moves, "evade" walks away from nearby enemies and collects XP orbs when it is safe, "kite" runs
-- a wide circle with detours for orbs, "fight" keeps enemies at weapon
-- distance (the closest to an average player), "stop3" kites until 3:00 and then stands still (DESIGN.md section 9: "without dodging dead from minute 3 in under 20 s").
-- Since WP9 every moving bot also sidesteps Spitter shots that come close (late, like a decent player) and walks to
-- elite chests when nothing is close; "evade" and "fight" also go after Spitters, as good players do. Since the fun
-- package after WP9 they also step out of the rush path of a Charger that winds up (its path glows for players).
-- Since B1 (Brotato direction) the bot also shops after every wave: it picks its level-up cards, buys what it can
-- afford (owned items first, then the cheapest) and presses Ready.
-- Change SCENARIOS / SEEDS below to test other setups (all of them with 6 seeds take about 75 s). Results feed the
-- balancing notes in DESIGN.md.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local RunDirector = require(Services.RunDirector)
local EnemySim = require(Services.EnemySim)
local CombatService = require(Services.CombatService)
local UpgradeService = require(Services.UpgradeService)
local RunStatsService = require(Services.RunStatsService)
local ShopService = require(Services.ShopService)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local EnemyKinds = require(game:GetService("ReplicatedStorage").Shared.Util.EnemyKinds)
local RunSchedule = require(game:GetService("ReplicatedStorage").Shared.Util.RunSchedule)

local DT = 1 / 15 -- one enemy simulation step per frame
local PICK_DELAY = 1.5 -- seconds a bot needs to pick a card (a human: 1-3 s)
local EVADE_RANGE = 20 -- studs; the evade bot reacts to enemies this close
local KITE_RADIUS = 50 -- studs around the arena center
local FIGHT_DISTANCE = { BladeWarden = 6, SparkMage = 14 } -- studs the fight bot keeps enemies away
local STOP_AT = 180 -- seconds; the stop3 bot stands still from here on
local DODGE_RANGE = 6 -- studs; a moving bot reacts to an enemy shot this close that is heading at it
local DODGE_MISS = 2.5 -- studs; shots passing farther away than this are ignored
local RUSH_WATCH = 36 -- studs; chargers winding up this close are watched
local RUSH_MARGIN = 1.5 -- studs on top of the charger's and the bot's radius
local RUSH_WEIGHT = 6 -- how much stepping out of a rush path counts against the other pulls
local TOUCH_MAX_RADIUS = 5 -- studs; the biggest enemy radius (elites), for finding who touched the bot
local MAX_SECONDS = Config.Run.durationSeconds + 5

local SEEDS = { 11, 22, 33, 44, 55, 66 }
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
-- the mock has no physics: keep the bot inside the arena walls (MapService) like a real character
local wallLimit = Config.Map.arena.size / 2 - Config.Simulation.playerRadius

-- Damage the bot took this run by source (before hit protection and armor).
local damageTaken = { contact = 0, shot = 0 }
local touchIds: { number } = {}
local touchByKind: { [string]: number } = {}
EnemySim.Contact:Connect(function(_, damage)
	if CombatService.getHp(bot) > 0 then
		damageTaken.contact += damage
		-- which kind it was: the one with the strongest touch next to the bot
		local position = EnemySim.getPlayerPosition(bot)
		local reach = Config.Simulation.playerRadius + Config.Simulation.contactMargin + 0.5
		local found = if position then EnemySim.queryRadius(position, reach + TOUCH_MAX_RADIUS, touchIds) else 0
		local best, name = -1, "?"
		for i = 1, found do
			local enemyId, elite = EnemySim.getKind(touchIds[i])
			local kind = enemyId and EnemyKinds.get(enemyId, elite)
			local enemy = EnemySim.getPosition(touchIds[i])
			if not (kind and enemy and position) then
				continue
			end
			local dx, dz = enemy.X - position.X, enemy.Z - position.Z
			if math.sqrt(dx * dx + dz * dz) <= kind.radius + reach and kind.contactDamage > best then
				best, name = kind.contactDamage, if elite then `Elite{enemyId}` else enemyId :: string
			end
		end
		touchByKind[name] = (touchByKind[name] or 0) + damage
	end
end)
EnemySim.ShotHit:Connect(function(_, damage)
	if CombatService.getHp(bot) > 0 then
		damageTaken.shot += damage
		damageTaken.hits += 1
	end
end)
local nearbyIds: { number } = {}
local rushIds: { number } = {}

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

-- Enemy shots and chests as a client sees them (EnemyShots, Chests), so bots can dodge and loot.
local shots = {}
local shotsFired = 0
world.getRemote("EnemyShots").OnClientEvent:Connect(function(events)
	if events.reset then
		table.clear(shots)
	end
	for _, fired in events.fired do
		shots[fired.id] = fired
		shotsFired += 1
	end
	for i = 1, #events.ended, 2 do
		shots[events.ended[i]] = nil
	end
end)
local chests = {}
world.getRemote("Chests").OnClientEvent:Connect(function(list)
	chests = list
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

-- Sideways step away from enemy shots about to hit, or 0, 0.
local function dodge(position)
	local now = workspace:GetServerTimeNow()
	local px, pz = 0, 0
	for id, shot in shots do
		local flown = shot.speed * (now - shot.at)
		if flown > shot.range then
			shots[id] = nil
			continue
		end
		local sx, sz = shot.x + shot.dx * flown, shot.z + shot.dz * flown
		local rx, rz = position.X - sx, position.Z - sz
		local ahead = rx * shot.dx + rz * shot.dz
		if ahead > 0 and ahead < DODGE_RANGE then
			local side = rx * -shot.dz + rz * shot.dx -- which side of the line the bot is on
			if math.abs(side) < DODGE_MISS then
				local sign = if side >= 0 then 1 else -1
				px += -shot.dz * sign
				pz += shot.dx * sign
			end
		end
	end
	return unit(px, pz)
end

-- Sideways step out of the path of chargers winding up or rushing, or 0, 0. Blended into the normal steering (not
-- instead of it like a shot dodge): chargers aim at the bot, so a wind-up nearby would otherwise blind it to the
-- rest of the crowd for a second or more.
local function rushDodge(position)
	local px, pz = 0, 0
	for i = 1, EnemySim.queryRadius(position, RUSH_WATCH, rushIds) do
		local id = rushIds[i]
		local mode, dx, dz = EnemySim.getMode(id)
		local charger = EnemySim.getPosition(id)
		if (mode == 1 or mode == 2) and charger then
			local rx, rz = position.X - charger.X, position.Z - charger.Z
			local ahead = rx * dx + rz * dz
			local side = rx * -dz + rz * dx
			local enemyId, elite = EnemySim.getKind(id)
			local kind = enemyId and EnemyKinds.get(enemyId, elite)
			local reach = (if kind then kind.radius else 2) + Config.Simulation.playerRadius + RUSH_MARGIN
			if ahead > -2 and math.abs(side) < reach then
				local sign = if side >= 0 then 1 else -1
				px += -dz * sign * 2
				pz += dx * sign * 2
			end
		end
	end
	return unit(px, pz)
end

-- Unit direction to the nearest Spitter within `range` (good players go after them), or 0, 0.
local huntIds: { number } = {}
local function huntPull(position, range)
	local bestX, bestZ, best = 0, 0, range
	for i = 1, EnemySim.queryRadius(position, range, huntIds) do
		if EnemySim.getKind(huntIds[i]) == "Spitter" then
			local enemy = EnemySim.getPosition(huntIds[i])
			if enemy then
				local dx, dz = enemy.X - position.X, enemy.Z - position.Z
				local distance = math.sqrt(dx * dx + dz * dz)
				if distance < best then
					bestX, bestZ, best = dx, dz, distance
				end
			end
		end
	end
	return unit(bestX, bestZ)
end

-- Unit direction to the nearest chest within `range`, or 0, 0.
local function chestPull(position, range)
	local bestX, bestZ, best = 0, 0, range
	for _, chest in chests do
		local dx, dz = chest.x - position.X, chest.z - position.Z
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
	local rx, rz = rushDodge(position)
	local dodgeX, dodgeZ = dodge(position)
	if dodgeX ~= 0 or dodgeZ ~= 0 then
		return unit(dodgeX + rx, dodgeZ + rz)
	end
	rx, rz = rx * RUSH_WEIGHT, rz * RUSH_WEIGHT
	local fromCenterX, fromCenterZ = position.X - center.X, position.Z - center.Z
	if kind == "kite" or kind == "stop3" then
		-- run the circle, step aside for orbs nearby, dodge enemies right in the way
		local cx, cz = unit(
			center.X + math.cos(angle) * KITE_RADIUS - position.X,
			center.Z + math.sin(angle) * KITE_RADIUS - position.Z
		)
		local ox, oz = orbPull(position, 15)
		local kx, kz = chestPull(position, 40)
		local tx, tz, closest = threat(position, 8)
		local orbWeight = if closest > 6 then 0.8 else 0
		return unit(cx + (ox + kx) * orbWeight + tx * 3 + rx, cz + (oz + kz) * orbWeight + tz * 3 + rz)
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
		local kx, kz = chestPull(position, 60)
		local hx, hz = huntPull(position, 40)
		local orbWeight = if closest > keep then 1.5 else 0.2
		return unit(
			tx * 4 + (ox + kx * 2 + hx * 2) * orbWeight + wx + rx,
			tz * 4 + (oz + kz * 2 + hz * 2) * orbWeight + wz + rz
		)
	end
	-- evade: get away from enemies, collect orbs when nothing is close, stay off the walls
	local tx, tz, closest = threat(position, EVADE_RANGE)
	local ox, oz = orbPull(position, 40)
	local kx, kz = chestPull(position, 60)
	local hx, hz = huntPull(position, 40)
	local orbWeight = if closest > 10 then 1 else 0.2
	return unit(
		tx * 4 + (ox + kx * 2 + hx * 2) * orbWeight + wx + rx,
		tz * 4 + (oz + kz * 2 + hz * 2) * orbWeight + wz + rz
	)
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
	damageTaken = { contact = 0, shot = 0, hits = 0 }
	table.clear(touchByKind)
	shotsFired = 0
	local minuteRows = {}
	local nextMinute = 60
	local bought = 0
	while RunDirector.isOngoing() and RunDirector.getElapsed() < MAX_SECONDS do
		if RunDirector.getPhase() == "Shop" then
			local offer = UpgradeService.getOffer(bot)
			if offer then
				world.fireServerAs(bot, "ChooseUpgrade", pickCard(offer).id)
			else
				local best = nil
				for _, item in ShopService.getOffers(bot) do
					if not item.sold and item.price <= ShopService.getShards(bot) then
						local better = best == nil
							or (not item.isNew and best.isNew)
							or (item.isNew == best.isNew and item.price < best.price)
						if better then
							best = item
						end
					end
				end
				if best then
					local before = ShopService.getShards(bot)
					world.fireServerAs(bot, "BuyShopOffer", best.id)
					if ShopService.getShards(bot) < before then
						bought += 1
					end
				else
					world.fireServerAs(bot, "SetShopReady", true)
				end
			end
			world.step(0.25) -- rate limits: a few clicks per second
			continue
		end
		local elapsed = RunDirector.getElapsed()
		local root = bot.Character.HumanoidRootPart
		local humanoid = bot.Character.Humanoid
		local speed = humanoid.WalkSpeed
		local position = root.Position

		local dx, dz = steer(scenario.bot, scenario.class, position, elapsed, angle)
		if speed > 0 and (dx ~= 0 or dz ~= 0) then
			local moved = position + Vector3.new(dx, 0, dz) * speed * DT
			root.Position = Vector3.new(
				math.clamp(moved.X, center.X - wallLimit, center.X + wallLimit),
				moved.Y,
				math.clamp(moved.Z, center.Z - wallLimit, center.Z + wallLimit)
			)
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
			local spitters = 0
			local all = {}
			for i = 1, EnemySim.queryRadius(center, 1000, all) do
				if EnemySim.getKind(all[i]) == "Spitter" then
					spitters += 1
				end
			end
			table.insert(
				minuteRows,
				`{nextMinute // 60}m L{RunStatsService.getTally():getLevel()} {math.round(hp)}/{maxHp}hp {EnemySim.getCount()}e {spitters}s dmg {math.round(
					damageTaken.contact
				)}t+{damageTaken.shot}s @{math.round(position.X)},{math.round(position.Z)} {RunDirector.getParticipantState(
					bot
				)}`
			)
			nextMinute += 60
		end
		world.step(DT)
	end

	local survived = RunDirector.getElapsed()
	local tally = RunStatsService.getTally()
	waitForPhase("Ended", 2)
	waitForPhase("Lobby", Config.Run.flow.resultsSeconds + 2)
	local evolutions = {}
	for _, weapon in require(Services.WeaponService).getWeapons(bot) do
		if weapon.evolution then
			table.insert(evolutions, weapon.evolution)
		end
	end
	local touches = {}
	for name, amount in touchByKind do
		table.insert(touches, `{name} {math.round(amount)}`)
	end
	table.sort(touches)
	return {
		touches = table.concat(touches, ", "),
		survived = survived,
		level = tally:getLevel(),
		kills = tally.kills,
		minutes = minuteRows,
		evolutions = evolutions,
		damageTaken = damageTaken,
		shotsFired = shotsFired,
		wave = RunSchedule.waveAt(survived).number,
		bought = bought,
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
				print(
					`  seed {seed}: {format(result.survived)} (wave {result.wave}), level {result.level}, {result.kills} kills, {result.bought} bought, evolutions: {if #result.evolutions
							> 0
						then table.concat(result.evolutions, "+")
						else "none"}, {result.damageTaken.hits}/{result.shotsFired} shots hit ({result.damageTaken.shot} dmg), by touch {result.damageTaken.contact}`
				)
				print(`    {table.concat(result.minutes, " | ")}`)
				print(`    touch damage by kind: {result.touches}`)
				local shown = if scenario.bot == "stop3" and result.survived >= STOP_AT
					then `{format(result.survived)} (+{math.floor(result.survived - STOP_AT)}s)`
					else format(result.survived)
				table.insert(times, `{shown} w{result.wave}`)
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
