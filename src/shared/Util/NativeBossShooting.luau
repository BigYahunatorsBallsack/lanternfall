--!strict
-- Shared source shoot animation and independent behavior clocks; native boss controllers feed physics and animation phases separately.
local Shooting = {}
export type Profile = {
	cooldown: number,
	randomization: number,
	initial: number,
	longEvery: number,
	longFrames: number,
	animationSpeed: number,
	minRange: number,
	maxRange: number,
	unrestricted: boolean?, -- an unlimited source spawning attack does not test the parent's target distance
	spawnLimit: number?, -- explicit finite SpawningAttackBehavior cap; counts children, not shoot animations
	exhaustedFrames: number?,
	moveLocked: boolean?,
	recoveryFrames: number?,
}
export type Rules = {
	frameRate: number,
	minimumCooldownFrames: number,
	fireAt: number,
	animationSeconds: number,
	profiles: { Profile },
}
export type Clock = { initial: number, remaining: number, recovery: number, shots: number, spawns: number }
export type State = {
	rules: Rules,
	current: number,
	clocks: { Clock },
	animation: { playing: boolean, cursor: number, speed: number, fired: boolean },
	movement: { canMove: boolean, locked: boolean },
}
local function cooldown(clock: Clock, profile: Profile, rules: Rules, random: () -> number): number
	if profile.longEvery ~= 0 and clock.shots >= profile.longEvery then
		clock.shots = 0
		return profile.longFrames
	end
	local low = math.max(rules.minimumCooldownFrames, profile.cooldown - profile.randomization)
	return low + random() * (profile.cooldown + profile.randomization - low)
end
local function newClock(profile: Profile, rules: Rules, random: () -> number, ready: boolean?): Clock
	local clock = { initial = profile.initial, remaining = 0, recovery = 0, shots = 0, spawns = 0 }
	clock.remaining = if ready and profile.spawnLimit == 0
		then assert(profile.exhaustedFrames, "Finite spawning needs its source exhausted cooldown")
		else cooldown(clock, profile, rules, random)
	return clock
end
function Shooting.new(rules: Rules, random: () -> number): State
	local clocks = {}
	for index, profile in rules.profiles do
		clocks[index] = newClock(profile, rules, random, true)
	end
	assert(#clocks > 0, "Native boss requires a root shooting profile")
	return {
		rules = rules,
		current = 1,
		clocks = clocks,
		animation = { playing = false, cursor = 0, speed = 1, fired = false },
		movement = { canMove = true, locked = false },
	}
end
function Shooting.select(state: State, index: number)
	assert(state.clocks[index], "Unknown native boss shooting profile")
	state.current = index -- switching does not reset either clock or the parent's animation
end
function Shooting.resetCurrent(state: State, random: () -> number): number
	local index = state.current
	state.clocks[index] = newClock(state.rules.profiles[index], state.rules, random)
	return index -- source projectile-damage reset is the owning controller's separate responsibility
end
-- Source increments per emitted child request, including requests whose eventual body is refused by the world cap.
function Shooting.recordSpawns(state: State, index: number, count: number)
	state.clocks[index].spawns += count
end
function Shooting.isMovementLocked(state: State): boolean
	return not state.movement.canMove or state.movement.locked
end
function Shooting.phaseChanged(state: State)
	state.movement.canMove = true -- source Boss.on_state_changed leaves _move_locked untouched
end
function Shooting.physics(state: State, dt: number, distance: number): boolean
	local clock = state.clocks[state.current]
	local profile = state.rules.profiles[state.current]
	local frames = state.rules.frameRate * dt
	if clock.initial > 0 then
		clock.initial = math.max(0, clock.initial - frames)
		return false -- source returns even when this frame consumes the last initial-cooldown fraction
	end
	clock.remaining = math.max(0, clock.remaining - frames)
	if state.animation.playing and profile.moveLocked then
		state.movement.canMove, state.movement.locked = false, true
	end
	if clock.recovery > 0 then
		clock.recovery = math.max(0, clock.recovery - frames)
		if clock.recovery <= 0 and profile.moveLocked then
			state.movement.canMove, state.movement.locked = true, false
		end
	end
	if
		not state.animation.playing
		and clock.remaining <= 0
		and clock.recovery <= 0
		and (profile.spawnLimit == nil or clock.spawns < profile.spawnLimit)
		and (profile.unrestricted or (distance >= profile.minRange and distance <= profile.maxRange))
	then
		state.animation.playing, state.animation.fired = true, false
		state.animation.cursor, state.animation.speed = 0, profile.animationSpeed
		return true
	end
	return false
end
-- Source Enemy.shoot and animation_finished dereference the current behavior at each callback, not at animation start.
function Shooting.advanceAnimation(state: State, dt: number, random: () -> number, shoot: ((number) -> ())?): { number }
	local animation, fired = state.animation, {}
	if not animation.playing then
		return fired
	end
	animation.cursor += dt * animation.speed
	if not animation.fired and animation.cursor >= state.rules.fireAt - 1e-9 then
		animation.fired = true
		local index, clock = state.current, state.clocks[state.current]
		table.insert(fired, index)
		if shoot then
			shoot(index)
		end
		clock.shots += 1 -- the invoked behavior owns the shot even if its callback selects another behavior
	end
	if animation.playing and animation.cursor >= state.rules.animationSeconds - 1e-9 then
		animation.playing = false
		local index = state.current
		local clock, profile = state.clocks[index], state.rules.profiles[index]
		clock.remaining = if profile.spawnLimit ~= nil and clock.spawns >= profile.spawnLimit
			then assert(profile.exhaustedFrames, "Finite spawning needs its source exhausted cooldown")
			else cooldown(clock, profile, state.rules, random)
		clock.recovery = profile.recoveryFrames or 0
		if profile.moveLocked and clock.recovery == 0 then
			state.movement.canMove, state.movement.locked = true, false
		end
	end
	return fired
end
return Shooting
