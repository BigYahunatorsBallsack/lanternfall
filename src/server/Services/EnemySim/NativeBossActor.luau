--!strict
-- Source boss phase/animation composition for explicitly ported elites; EnemySim retains actor ownership, targets, damage and projectile production.
local Shared = game:GetService("ReplicatedStorage").Shared
local Enemies = require(Shared.Config.Enemies)
local Shooting = require(Shared.Util.NativeBossShooting)
local Phases = require(script.Parent.NativeBossPhases)
local Actor = {}
export type State = {
	rules: Enemies.NativeBoss,
	phase: Phases.State,
	shooting: Shooting.State,
	untilCheck: number,
	pending: number,
	wrapperFrames: number,
	damages: { number }?,
	lateRootDamage: number?,
	customRequested: boolean,
}
function Actor.new(rules: Enemies.NativeBoss, random: () -> number): State
	assert(
		rules.family == "Therizinosaurus"
			or rules.family == "Silesaurus"
			or rules.family == "Diplodocus"
			or rules.family == "Baryonyx"
			or rules.family == "Carnotaurus",
		"Native boss family requires its own implemented controller"
	)
	return {
		rules = rules,
		phase = if rules.customJump
			then { current = -1, elapsed = 0, binding = rules.phases }
			else Phases.new(rules.phases),
		shooting = Shooting.new(rules.shooting, random),
		untilCheck = rules.init.timerSeconds,
		pending = 0,
		wrapperFrames = rules.initialWrapperFrames or 0,
		customRequested = false,
	}
end
-- Godot3 invokes derived physics before inherited Enemy jump physics. Check the previous landed flag first.
function Actor.beforeJump(state: State, jump: { landed: boolean, jumping: boolean, locked: boolean }): boolean
	if
		not state.rules.customJump
		or state.phase.current >= 0
		or not state.customRequested
		or not jump.landed
		or jump.jumping
	then
		return false
	end
	state.phase.current, state.customRequested = 0, false
	Shooting.phaseChanged(state.shooting)
	state.shooting.movement.locked = jump.locked
	return true
end
local function frame(
	state: State,
	dt: number,
	health: () -> number,
	distance: number,
	random: () -> number,
	emit: (number) -> (),
	changed: ((number) -> ())?
)
	state.untilCheck -= dt
	if state.untilCheck <= 1e-9 then
		state.untilCheck += state.rules.init.timerSeconds
		if state.rules.customJump then
			state.customRequested = true -- source override does not increment Boss.elapsed_time
		else
			Phases.onTimeout(state.phase, health, function(index)
				Shooting.select(state.shooting, index + 2) -- root is profile1; source child0 is profile2
				Shooting.phaseChanged(state.shooting)
				if changed then
					changed(index + 2)
				end
			end)
		end
	end
	if state.rules.customJump and state.phase.current < 0 then
		return
	end
	if state.wrapperFrames > 0 then
		state.wrapperFrames -= 1
		if state.wrapperFrames == 0 and state.lateRootDamage ~= nil and state.damages then
			state.damages[1] = state.lateRootDamage -- first registration uses no earlier reset modifier
			state.lateRootDamage = nil
		end
		return -- source DetectEvolution selects/registers normal here; its clock first advances on the following callback
	end
	Shooting.physics(state.shooting, dt, distance)
	Shooting.advanceAnimation(state.shooting, dt, random, emit)
end

function Actor.step(
	state: State,
	dt: number,
	health: () -> number,
	distance: number,
	random: () -> number,
	emit: (number) -> (),
	changed: ((number) -> ())?
)
	local seconds = 1 / state.rules.shooting.frameRate
	state.pending += dt
	while state.pending >= seconds - 1e-9 do
		state.pending = math.max(0, state.pending - seconds)
		frame(state, seconds, health, distance, random, emit, changed)
	end
end
-- Source Boss.init rounds the already rounded Unit HP a second time; damage modifiers still precede final rounding.
function Actor.initialShares(
	rules: Enemies.NativeBoss,
	wave: number,
	zone: number,
	danger: number,
	doubleBoss: boolean
): (number, number)
	local c = rules.init
	if wave <= c.earlyWave then
		return c.firstHpShare, 1
	end
	if (doubleBoss and wave == c.endWave) or wave <= c.middleWave then
		return c.middleHpShare, if wave <= c.middleWave then c.middleDamageShare else 1
	end
	if wave == c.endWave and danger <= 0 and zone ~= 0 then
		return c.easyZoneHpShare, 1
	end
	return 1, 1
end
return Actor
