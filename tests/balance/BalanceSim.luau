-- Balance simulation: plays whole runs headlessly with the real server code (tests/helpers/RobloxMock) and a bot
-- instead of a human, then prints when the bot died, its lowest HP and the team level per wave and its build.
-- Not part of the normal test run (slow). Run it with:
--   cargo run --release --manifest-path tools/luau-test-runner/Cargo.toml -- . tests/balance/BalanceSim.luau
-- Bots: "idle" never moves, "evade" walks away from nearby enemies and collects XP orbs when it is safe, "kite" runs
-- a wide circle with detours for orbs, "fight" keeps enemies at weapon
-- distance (the closest to an average player), "stop3" kites until 3:00 and then stands still (DESIGN.md section 9: "without dodging dead from minute 3 in under 20 s").
-- Since WP9 every moving bot also sidesteps Spitter shots that come close (late, like a decent player) and walks to
-- elite chests when nothing is close; "evade" and "fight" also go after Spitters, as good players do. Since the fun
-- package after WP9 they also step out of the rush path of a Charger that winds up (its path glows for players).
-- Since B1 (Brotato direction) the bot also shops after every wave: it picks its level-up cards, buys what it can
-- afford and presses Ready. Since B2 it rates stat cards and items by a simple stat taste (STAT_TASTE: its class's
-- damage type, then Max HP, Damage, Attack Speed and Armor) and buys weapons it owns before new ones. Since B3 weapons
-- come in tiers (worth their price factor), the bot skips offers it cannot take (slots full) and merges every pair of
-- equal weapons it can. Since B4 every run has its own seed for the random streams (RandomService), and the bot
-- values item effects by rough stat equivalents (effectScore) and the new secondary stats (it never rerolls or sells,
-- so Free Rerolls and Sell Value are worth nothing to it).
-- Change SCENARIOS / SEEDS below to test other setups (since B3's 20 waves one good bot with 6 seeds takes about 10 min;
-- run scenarios in parallel from copies of the repo). Results feed the
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
local RandomService = require(Services.RandomService)
local ShopService = require(Services.ShopService)
local StatService = require(Services.StatService)
local WeaponService = require(Services.WeaponService)
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
-- How much the bot wants one level-up step (tier I value) of a stat; the class's damage type gets CLASS_DAMAGE.
local STAT_TASTE = {
	maxHp = 3,
	hpRegen = 2,
	lifeSteal = 1.5,
	damage = 3,
	attackSpeed = 3,
	critChance = 1.5,
	range = 1,
	armor = 3,
	dodge = 2,
	speed = 1.5,
	luck = 1,
	harvesting = 2,
	xpGain = 1,
	pickupRange = 0.5,
	itemPrice = -1.5,
	freeRerolls = 0,
	sellValue = 0,
	doubleShards = 1.5,
	shardHealing = 1,
	eliteDamage = 0.3,
	enemyCount = -0.3, -- more enemies: more Shards and XP, but more danger
	enemyHp = -1,
	enemyDamage = -1.5,
}
local CLASS_DAMAGE = { BladeWarden = "meleeDamage", SparkMage = "rangedDamage" }
local CLASS_DAMAGE_TASTE = 4
-- "one step" of stats without level-up values
local SECONDARY_STEP = {
	xpGain = 5,
	pickupRange = 20,
	itemPrice = 5,
	doubleShards = 5,
	shardHealing = 8,
	eliteDamage = 10,
	enemyCount = 10,
	enemyHp = 10,
	enemyDamage = 10,
}
local WEAPON_TASTE = { owned = 6, new = 5 } -- a tier I copy of an owned weapon and a new weapon, in the same units
-- Item effects (since B4): bots move most of the time, so "standing still" counts little; a bonus for one wave counts
-- TEMPORARY_SHARE of the same bonus for good. Rough counts per wave of each trigger for a good bot in mid-run.
local STATE_SHARE = { Still = 0.15, Moving = 0.85 }
local TEMPORARY_SHARE = 0.3
local TRIGGERS_PER_WAVE = {
	WaveStart = 1,
	WaveEnd = 1,
	ShopEnter = 1,
	Reroll = 0,
	Buy = 3,
	Sell = 0,
	LevelUp = 2,
	Hit = 300,
	Crit = 40,
	Kill = 120,
	Dodge = 6,
	Hurt = 10,
	Pickup = 120,
	Chest = 0.3,
}
local CRIT_SHARE = 0.15 -- share of hits and kills that are crits
local ELITE_SHARE = 0.02 -- share of hits and kills on elites
local WAVE_SECONDS = 50 -- for Timer effects
local HEAL_PER_REGEN = 100 -- HP one point of HP Regeneration heals in a wave
local HELD_SHARDS = 40 -- Shards the bot holds when a wave starts
local TIER_STEP = 6 -- one weapon tier more, in WEAPON_TASTE units

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

-- What the bot thinks stats are worth: taste x value / one level-up step, summed (negatives count against).
local function statScore(classId, stats)
	local score = 0
	for statId, value in stats do
		local stat = Config.Stats.byId[statId]
		local step = if stat and stat.upgrade then stat.upgrade[1] else SECONDARY_STEP[statId] or 1
		local taste = if CLASS_DAMAGE[classId] == statId then CLASS_DAMAGE_TASTE else STAT_TASTE[statId] or 0.5
		score += taste * value / step
	end
	return score
end

-- How many of `source` the bot has now (for per-X effects): Shards, different weapons or a stat.
local function sourceAmount(source)
	if source == "shards" then
		return ShopService.getShards(bot)
	elseif source == "distinctWeapons" then
		local ids = {}
		for _, weapon in WeaponService.getWeapons(bot) do
			ids[weapon.id] = true
		end
		local count = 0
		for _ in ids do
			count += 1
		end
		return count + 1 -- usually the next purchase adds one
	end
	return StatService.getSheet(bot)[source] or 0
end

-- What the item effects are roughly worth from now on, in statScore units: growth and repeated payouts count for
-- the waves left (on average half of what they add up to), per-X bonuses with what the bot has now, payouts without
-- stats as a stat they roughly equal.
local function effectScore(classId, effects, wave)
	local score = 0
	local wavesLeft = math.max(RunSchedule.waveCount() - wave, 0)
	for _, effect in effects or {} do
		if (effect.untilWave and wave >= effect.untilWave) or effect.chance == 0 then
			continue
		end
		local waves = if effect.untilWave then math.min(wavesLeft, effect.untilWave - wave) else wavesLeft
		local stats = if effect.stats then statScore(classId, effect.stats) else 0
		local perWave = if effect.trigger == "Timer"
			then WAVE_SECONDS / (effect.interval or WAVE_SECONDS)
			else TRIGGERS_PER_WAVE[effect.trigger] or 1
		perWave *= (effect.chance or 1) * (if effect.crit then CRIT_SHARE else 1) * (if effect.elite
			then ELITE_SHARE
			else 1)
		if effect.maxPerWave then
			perWave = math.min(perWave, effect.maxPerWave)
		end
		local action = effect.action
		if action == "Stats" then
			score += stats * (if effect.state then STATE_SHARE[effect.state] else 1)
		elseif action == "PerX" then
			local count = math.max(0, math.floor(sourceAmount(effect.source) / (effect.per or 1)))
			score += stats * math.min(count, effect.max or math.huge)
		elseif action == "Grow" then
			score += if effect.trigger == "Acquire" then stats else stats * perWave * waves / 2
		elseif action == "WaveStats" then
			score += stats * math.min(perWave, effect.maxStacks or math.huge) / 2
		elseif action == "TimedStats" then
			score += stats * math.min(1, perWave * (effect.seconds or 0) / WAVE_SECONDS)
		elseif action == "NextWaveStats" then
			score += stats * TEMPORARY_SHARE
		elseif action == "Heal" then
			score += statScore(classId, { hpRegen = (effect.amount or 0) * perWave / HEAL_PER_REGEN })
		elseif action == "Shards" then
			score += statScore(classId, { harvesting = (effect.amount or 0) * perWave })
		elseif action == "ShardShare" then
			score += statScore(classId, { harvesting = HELD_SHARDS * (effect.amount or 0) / 100 * perWave })
		elseif action == "Shields" then
			score += statScore(classId, { armor = (effect.amount or 0) * perWave })
		elseif action == "RandomStats" then
			local point, primaries = 0, 0
			for _, stat in Config.Stats.order do
				if stat.primary then
					point += statScore(classId, { [stat.id] = Config.Effects.randomPoint[stat.id] or 1 })
					primaries += 1
				end
			end
			score += point / math.max(primaries, 1) * (effect.amount or 0) * perWave * waves / 2
		elseif action == "UpgradeWeapon" then
			local headroom = 0
			for _, weapon in WeaponService.getWeapons(bot) do
				headroom += #Config.Shop.tierPriceFactors - weapon.tier
			end
			score += TIER_STEP * math.min(waves * perWave, headroom) / 2
		end
	end
	return score
end

-- The stat card the bot likes best.
local function pickCard(classId, cards)
	local best, bestScore = cards[1], -math.huge
	for _, card in cards do
		local score = statScore(classId, { [card.stat] = card.amount })
		if score > bestScore then
			best, bestScore = card, score
		end
	end
	return best
end

-- The shop offer with the best score per Shard the bot can afford and likes, or nil.
local function pickOffer(classId, offers, shards, wave)
	local best, bestValue = nil, 0
	for _, offer in offers do
		if offer.sold or offer.blocked or offer.price > shards then
			continue
		end
		local score
		if offer.kind == "Weapon" then
			local taste = if offer.isNew then WEAPON_TASTE.new else WEAPON_TASTE.owned
			score = taste * Config.Shop.tierPriceFactors[offer.tier]
		else
			local item = Config.Items.byId[offer.itemId]
			score = statScore(classId, item.stats) + effectScore(classId, item.effects, wave)
		end
		local value = score / offer.price
		if score > 0 and value > bestValue then
			best, bestValue = offer, value
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
local ShotFeed = require(game:GetService("ReplicatedStorage").Shared.Net.ShotFeed)
world.getRemote("EnemyShots").OnClientEvent:Connect(function(packet)
	local events = if type(packet) == "buffer" then ShotFeed.decode(packet) else packet -- buffer since Paket 22
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
	RandomService.setNextSeed(seed)
	world.fireServerAs(bot, "SelectClass", scenario.class)
	world.fireServerAs(bot, "SetReady", true)
	waitForPhase("Running", 15)

	local offerSeenAt = nil
	local angle = 0
	damageTaken = { contact = 0, shot = 0, hits = 0 }
	table.clear(touchByKind)
	shotsFired = 0
	-- one row per wave: team level at its end, the lowest HP in it and the most enemies at once
	local waveRows = {}
	local wave = { number = 1, lowHp = math.huge, maxHp = 0, enemies = 0 }
	local function closeWave()
		table.insert(
			waveRows,
			`w{wave.number} L{RunStatsService.getTally():getLevel()} low {math.round(wave.lowHp)}/{wave.maxHp} {wave.enemies}e`
		)
	end
	local bought = 0
	while RunDirector.isOngoing() and RunDirector.getElapsed() < MAX_SECONDS do
		if RunDirector.getPhase() == "Shop" then
			local offer = UpgradeService.getOffer(bot)
			local mergeable = nil
			for _, weapon in WeaponService.getWeapons(bot) do
				if not mergeable and WeaponService.findMergePartner(bot, weapon.uid) then
					mergeable = weapon.uid
				end
			end
			if offer then
				world.fireServerAs(bot, "ChooseUpgrade", pickCard(scenario.class, offer).id)
			elseif mergeable then
				world.fireServerAs(bot, "MergeWeapons", mergeable)
			else
				local best = pickOffer(
					scenario.class,
					ShopService.getOffers(bot),
					ShopService.getShards(bot),
					RunDirector.getWave()
				)
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
				world.fireServerAs(bot, "ChooseUpgrade", pickCard(scenario.class, offer).id)
				offerSeenAt = nil
			end
		else
			offerSeenAt = nil
		end

		local number = RunSchedule.waveAt(elapsed).number
		if number ~= wave.number then
			closeWave()
			wave = { number = number, lowHp = math.huge, maxHp = 0, enemies = 0 }
		end
		local hp, maxHp = CombatService.getHp(bot)
		if RunDirector.getParticipantState(bot) == "Alive" and hp < wave.lowHp then
			wave.lowHp, wave.maxHp = hp, maxHp
		end
		wave.enemies = math.max(wave.enemies, EnemySim.getCount())
		world.step(DT)
	end

	closeWave()
	local survived = RunDirector.getElapsed()
	local tally = RunStatsService.getTally()
	-- the build at the end of the run (StatService and WeaponService reset in the lobby)
	local evolutions, build = {}, {}
	for _, weapon in WeaponService.getWeapons(bot) do
		table.insert(build, `{weapon.id} {weapon.tier}`)
		if weapon.evolution then
			table.insert(evolutions, weapon.evolution)
		end
	end
	for _, item in StatService.getItems(bot) do
		table.insert(build, `{item.id} x{item.count}`)
	end
	local sheet = StatService.getSheet(bot)
	local sheetText = {}
	for _, stat in Config.Stats.order do
		local value = sheet[stat.id] or 0
		if value ~= 0 then
			table.insert(sheetText, `{stat.id} {math.round(value)}`)
		end
	end
	waitForPhase("Ended", 2)
	waitForPhase("Lobby", Config.Run.flow.resultsSeconds + 2)
	local touches = {}
	for name, amount in touchByKind do
		table.insert(touches, `{name} {math.round(amount)}`)
	end
	table.sort(touches)
	return {
		touches = table.concat(touches, ", "),
		survived = survived,
		won = survived >= Config.Run.durationSeconds - 0.5,
		level = tally:getLevel(),
		kills = tally.kills,
		waves = waveRows,
		evolutions = evolutions,
		damageTaken = damageTaken,
		shotsFired = shotsFired,
		wave = RunSchedule.waveAt(survived).number,
		bought = bought,
		build = table.concat(build, ", "),
		stats = table.concat(sheetText, ", "),
	}
end

local function format(seconds)
	return string.format("%d:%02d", seconds // 60, math.floor(seconds % 60))
end

describe("balance sim", function()
	local summary = {}
	for _, scenario in SCENARIOS do
		it(`{scenario.class} / {scenario.bot}`, function()
			local times, levels, wins = {}, {}, 0
			for _, seed in SEEDS do
				local result = playRun(scenario, seed)
				print(
					`  seed {seed}: {format(result.survived)} (wave {result.wave}), level {result.level}, {result.kills} kills, {result.bought} bought, evolutions: {if #result.evolutions
							> 0
						then table.concat(result.evolutions, "+")
						else "none"}, {result.damageTaken.hits}/{result.shotsFired} shots hit ({result.damageTaken.shot} dmg), by touch {result.damageTaken.contact}`
				)
				print(`    {table.concat(result.waves, " | ")}`)
				print(`    touch damage by kind: {result.touches}`)
				print(`    build: {result.build}`)
				print(`    stats: {result.stats}`)
				local shown = if scenario.bot == "stop3" and result.survived >= STOP_AT
					then `{format(result.survived)} (+{math.floor(result.survived - STOP_AT)}s)`
					else format(result.survived)
				table.insert(times, `{shown} w{result.wave}`)
				if result.won then
					wins += 1
				end
				table.insert(levels, `L{result.level}`)
			end
			table.insert(
				summary,
				`{scenario.class} / {scenario.bot}: {wins}/{#SEEDS} won · {table.concat(times, ", ")} · {table.concat(
					levels,
					", "
				)}`
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
