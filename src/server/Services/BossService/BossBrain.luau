--!strict
-- A boss's phases and attacks as a pure state machine (DESIGN.md section 7, WP10, Brotato's boss "mutations").
-- Owned by BossService, which feeds it the time, the boss's HP share and how far the nearest player is, and carries
-- out what it reports. No Roblox APIs here, so tests/BossBrain.spec.luau runs it.
--
-- A phase starts when the boss is at or below its fromHp share or afterSeconds after the boss appeared, whichever
-- comes first; it switches only between attacks. Inside a phase the boss walks for pauseSeconds, then starts the
-- next attack of the phase's list that is off cooldown and in range (in list order, after the last one it used):
--   Walk -> Windup (the warning; reported as "Windup") -> Act (a Dash's rush or a Ring's bursts; "Strike" for each
--   burst) -> Recover -> Walk
-- Attacks without an Act report one "Strike" when the wind-up ends and go straight to Recover.

local Enemies = require(game:GetService("ReplicatedStorage").Shared.Config.Enemies)

export type State = "Walk" | "Windup" | "Act" | "Recover"

export type Event =
	{ kind: "Phase", phase: number }
	| { kind: "Windup", attackId: string }
	| { kind: "Strike", attackId: string, burst: number }
	| { kind: "Done", attackId: string }

export type Brain = {
	plan: Enemies.BossPlan,
	alive: number, -- seconds since it appeared
	phase: number,
	state: State,
	timer: number, -- seconds left in the state (Walk: until the next attack may start)
	attackId: string?, -- the attack in progress
	nextIndex: number, -- where the phase's list is tried next
	burst: number, -- bursts done of the attack in progress
	cooldowns: { [string]: number },
	events: { Event },
}

local BossBrain = {}

function BossBrain.new(plan: Enemies.BossPlan): Brain
	return {
		plan = plan,
		alive = 0,
		phase = 1,
		state = "Walk",
		timer = plan.phases[1].pauseSeconds,
		attackId = nil,
		nextIndex = 1,
		burst = 0,
		cooldowns = {},
		events = {},
	}
end

-- The phase the boss should be in: the last one whose HP share or time is reached (never back).
function BossBrain.phaseFor(plan: Enemies.BossPlan, current: number, hpFraction: number, alive: number): number
	local phase = current
	for index = current + 1, #plan.phases do
		local entry = plan.phases[index]
		local byHp = entry.fromHp ~= nil and hpFraction <= entry.fromHp
		local byTime = entry.afterSeconds ~= nil and alive >= entry.afterSeconds
		if byHp or byTime then
			phase = index
		end
	end
	return phase
end

-- How long an attack's Act lasts after its first strike: a Dash's rush, the gaps between a Ring's bursts; 0 for
-- the rest.
function BossBrain.actSeconds(attack: Enemies.BossAttack): number
	if attack.kind == "Dash" then
		return (attack.distance or 0) / math.max(attack.speed or 1, 1e-3)
	end
	return math.max(0, (attack.bursts or 1) - 1) * (attack.burstGapSeconds or 0)
end

local function attackOf(brain: Brain, attackId: string): Enemies.BossAttack
	return brain.plan.attacks[attackId]
end

-- The next attack of the phase that may start now, or nil.
local function pickAttack(brain: Brain, distance: number): (string?, number)
	local list = brain.plan.phases[brain.phase].attacks
	local count = #list
	for offset = 0, count - 1 do
		local index = (brain.nextIndex - 1 + offset) % count + 1
		local attackId = list[index]
		local attack = attackOf(brain, attackId)
		local ready = (brain.cooldowns[attackId] or 0) <= 0
		local inRange = attack.range == nil or distance <= attack.range
		if ready and inRange then
			return attackId, index
		end
	end
	return nil, brain.nextIndex
end

local function recover(brain: Brain, attack: Enemies.BossAttack)
	brain.state = "Recover"
	brain.timer = attack.recoverSeconds
end

-- Advances the brain by dt seconds. `hpFraction` is its HP share (0..1), `distance` how far the nearest living player
-- is from its edge (math.huge without one: no attack starts). Returns what happened, in order (a reused list).
function BossBrain.step(brain: Brain, dt: number, hpFraction: number, distance: number): { Event }
	local events = brain.events
	table.clear(events)
	brain.alive += dt
	for attackId, left in brain.cooldowns do
		brain.cooldowns[attackId] = left - dt
	end

	local state = brain.state
	if state == "Walk" then
		local phase = BossBrain.phaseFor(brain.plan, brain.phase, hpFraction, brain.alive)
		if phase ~= brain.phase then
			brain.phase = phase
			brain.nextIndex = 1
			table.clear(brain.cooldowns)
			brain.timer = brain.plan.phases[phase].pauseSeconds
			table.insert(events, { kind = "Phase", phase = phase })
			return events
		end
		brain.timer = math.max(0, brain.timer - dt)
		if brain.timer > 0 or distance == math.huge then
			return events
		end
		local attackId, index = pickAttack(brain, distance)
		if attackId then
			local attack = attackOf(brain, attackId)
			local list = brain.plan.phases[brain.phase].attacks
			brain.nextIndex = index % #list + 1
			brain.attackId = attackId
			brain.state = "Windup"
			brain.timer = attack.windupSeconds
			brain.burst = 0
			brain.cooldowns[attackId] = attack.cooldownSeconds or 0
			table.insert(events, { kind = "Windup", attackId = attackId })
		end
		return events
	end

	local attackId = brain.attackId :: string
	local attack = attackOf(brain, attackId)
	brain.timer -= dt
	if brain.timer > 0 then
		return events
	end
	if state == "Windup" then
		brain.burst = 1
		table.insert(events, { kind = "Strike", attackId = attackId, burst = 1 })
		local act = BossBrain.actSeconds(attack)
		if act > 0 then
			brain.state = "Act"
			brain.timer = if attack.kind == "Dash" then act else attack.burstGapSeconds or 0
		else
			recover(brain, attack)
		end
	elseif state == "Act" then
		if attack.kind ~= "Dash" and brain.burst < (attack.bursts or 1) then
			brain.burst += 1
			table.insert(events, { kind = "Strike", attackId = attackId, burst = brain.burst })
			if brain.burst < (attack.bursts or 1) then
				brain.timer = attack.burstGapSeconds or 0
				return events
			end
		end
		recover(brain, attack)
	elseif state == "Recover" then
		brain.state = "Walk"
		brain.attackId = nil
		brain.timer = brain.plan.phases[brain.phase].pauseSeconds
		table.insert(events, { kind = "Done", attackId = attackId })
	end
	return events
end

-- Ends the Act of the attack in progress early (a Dash that hit a wall or the arena edge).
function BossBrain.endAct(brain: Brain)
	if brain.state == "Act" and brain.attackId then
		recover(brain, attackOf(brain, brain.attackId))
	end
end

-- Whether the boss stands still right now (winding up, striking or recovering from an attack that is not `moving`).
function BossBrain.isHolding(brain: Brain): boolean
	if brain.state == "Walk" or not brain.attackId then
		return false
	end
	return not attackOf(brain, brain.attackId).moving
end

return BossBrain
