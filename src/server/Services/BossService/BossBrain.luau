--!strict
-- A boss's states and its attack cycle as a pure state machine (DESIGN.md section 7, WP10; Brotato 1.2.0.1 boss.gd
-- and the shooting/charging/spawning attack behaviors). Owned by BossService, which feeds it the time, the boss's HP
-- share and how far the nearest player is from its centre, and carries out what it reports. No Roblox APIs here, so
-- tests/BossBrain.spec.luau runs it.
--
-- States: once a second (Brotato's CheckStateTimer) the boss switches to the last later state whose hpStart share or
-- timerStart seconds since its spawn is reached. A new state's attack waits its rolled cooldown plus initialSeconds.
-- Attack cycle: Ready (cooldown runs out, nearest player in range) -> Windup (the "shoot" animation) -> Strike; a
-- Shoot or Spawn is back to Ready with a new cooldown, a Charge rushes for chargeSeconds (reporting "ChargeShot" for
-- the state's chargeShots every chargeShotEvery seconds, the first right away) and then recovers. An attack that is
-- under way when the state changes finishes as it started.

local Enemies = require(game:GetService("ReplicatedStorage").Shared.Config.Enemies)

local FRAME = 1 / 60 -- Brotato's shortest cooldown
local CHECK_SECONDS = 1 -- Brotato's CheckStateTimer

export type Mode = "Ready" | "Windup" | "Charge" | "Recover"

export type Event =
	{ kind: "State", state: number }
	| { kind: "Windup", attack: Enemies.BossAttack }
	| { kind: "Strike", attack: Enemies.BossAttack }
	| { kind: "ChargeShot", attack: Enemies.BossAttack }
	| { kind: "ChargeEnd" }

export type Brain = {
	plan: Enemies.BossPlan,
	roll: () -> number, -- a random number in [0, 1)
	alive: number, -- seconds since it appeared
	checkTimer: number,
	elapsed: number, -- whole seconds counted by the state check
	state: number, -- index into plan.states
	mode: Mode,
	timer: number, -- seconds left in Windup, Charge or Recover
	cooldown: number, -- seconds until the state's attack may start
	attack: Enemies.BossAttack?, -- the attack under way
	attackState: number, -- the state it belongs to
	shotTimer: number, -- Charge: seconds until the next charge shot
	events: { Event },
}

local BossBrain = {}

-- Brotato get_cd(): cooldown +- its randomization, at least one frame.
function BossBrain.rollCooldown(attack: Enemies.BossAttack, roll: () -> number): number
	local spread = attack.cooldownRandomSeconds or 0
	local low = math.max(FRAME, attack.cooldownSeconds - spread)
	local high = math.max(low, attack.cooldownSeconds + spread)
	return low + (high - low) * roll()
end

local function enter(brain: Brain, state: number)
	brain.state = state
	local attack = brain.plan.states[state].attack
	brain.cooldown = BossBrain.rollCooldown(attack, brain.roll) + (attack.initialSeconds or 0)
end

function BossBrain.new(plan: Enemies.BossPlan, roll: () -> number): Brain
	local brain: Brain = {
		plan = plan,
		roll = roll,
		alive = 0,
		checkTimer = 0,
		elapsed = 0,
		state = 1,
		mode = "Ready",
		timer = 0,
		cooldown = 0,
		attack = nil,
		attackState = 1,
		shotTimer = 0,
		events = {},
	}
	enter(brain, 1)
	return brain
end

-- The state the boss should be in at the check: the last later one whose HP share or time is reached (never back).
function BossBrain.stateFor(plan: Enemies.BossPlan, current: number, hpFraction: number, elapsed: number): number
	local state = current
	for index = current + 1, #plan.states do
		local entry = plan.states[index]
		local byHp = entry.hpStart ~= nil and hpFraction <= entry.hpStart
		local byTime = entry.timerStart ~= nil and elapsed >= entry.timerStart
		if byHp or byTime then
			state = index
		end
	end
	return state
end

local function inRange(attack: Enemies.BossAttack, distance: number): boolean
	if attack.kind == "Spawn" then
		return true
	end
	return distance ~= math.huge and distance >= (attack.minRange or 0) and distance <= (attack.maxRange or math.huge)
end

-- Ends the attack under way; its cooldown only counts if the boss is still in the state it belongs to.
local function finish(brain: Brain, cooldown: number)
	if brain.attackState == brain.state then
		brain.cooldown = cooldown
	end
	brain.mode = "Ready"
	brain.attack = nil
end

-- Advances the brain by dt seconds. `hpFraction` is its HP share (0..1), `distance` how far the nearest living player
-- is from its centre (math.huge without one: no Shoot or Charge starts). Returns what happened, in order (a reused
-- list).
function BossBrain.step(brain: Brain, dt: number, hpFraction: number, distance: number): { Event }
	local events = brain.events
	table.clear(events)
	brain.alive += dt
	brain.checkTimer += dt
	while brain.checkTimer >= CHECK_SECONDS do
		brain.checkTimer -= CHECK_SECONDS
		brain.elapsed += 1
		local state = BossBrain.stateFor(brain.plan, brain.state, hpFraction, brain.elapsed)
		if state ~= brain.state then
			enter(brain, state)
			table.insert(events, { kind = "State", state = state })
		end
	end

	local mode = brain.mode
	if mode == "Ready" then
		brain.cooldown = math.max(0, brain.cooldown - dt)
		local attack = brain.plan.states[brain.state].attack
		if brain.cooldown <= 0 and inRange(attack, distance) then
			brain.mode = "Windup"
			brain.timer = attack.windupSeconds
			brain.attack = attack
			brain.attackState = brain.state
			table.insert(events, { kind = "Windup", attack = attack })
		end
		return events
	end

	local attack = brain.attack :: Enemies.BossAttack
	brain.timer -= dt
	if mode == "Windup" then
		if brain.timer > 0 then
			return events
		end
		table.insert(events, { kind = "Strike", attack = attack })
		if attack.kind == "Charge" then
			local seconds = attack.chargeSeconds or 0
			if brain.attackState == brain.state then
				brain.cooldown = BossBrain.rollCooldown(attack, brain.roll) + seconds
			end
			brain.mode = "Charge"
			brain.timer = seconds
			local entry = brain.plan.states[brain.state]
			local shots, every = entry.chargeShots, entry.chargeShotEvery
			if shots and every and every > 0 then
				brain.shotTimer = every
				table.insert(events, { kind = "ChargeShot", attack = shots })
			end
		else
			finish(brain, BossBrain.rollCooldown(attack, brain.roll))
		end
		return events
	end

	brain.cooldown = math.max(0, brain.cooldown - dt)
	if mode == "Charge" then
		local entry = brain.plan.states[brain.state]
		local shots, every = entry.chargeShots, entry.chargeShotEvery
		-- shots while the rush lasts (none at the very moment it ends)
		if shots and every and every > 0 and brain.timer > 1e-6 then
			brain.shotTimer -= dt
			if brain.shotTimer <= 1e-6 then
				brain.shotTimer += every
				table.insert(events, { kind = "ChargeShot", attack = shots })
			end
		end
		if brain.timer <= 1e-6 then
			table.insert(events, { kind = "ChargeEnd" })
			brain.mode = "Recover"
			brain.timer = attack.recoverSeconds or 0
		end
	elseif mode == "Recover" and brain.timer <= 0 then
		brain.mode = "Ready"
		brain.attack = nil
	end
	return events
end

-- Whether the boss stands still right now: winding up a charge (its direction is fixed) or recovering from one.
-- Shoot and Spawn wind-ups keep it walking (Brotato).
function BossBrain.isHolding(brain: Brain): boolean
	local attack = brain.attack
	return (brain.mode == "Windup" and attack ~= nil and attack.kind == "Charge") or brain.mode == "Recover"
end

return BossBrain
