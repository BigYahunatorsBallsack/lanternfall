--!strict
-- Source-backed Pursuer timers, entry resets and independent Baby T-Rex collision growth; World owns timer stepping and faction transfer.
local Enemies = require(game:GetService("ReplicatedStorage").Shared.Config.Enemies)
local Pursuer = {}
export type State = {
	stage: number,
	clock: number,
	baseDamage: number,
	referenceSpeed: number?,
	contacts: { [number | string]: boolean }?,
	nextContacts: { [number | string]: boolean }?,
}
function Pursuer.new(damage: number): State
	return { stage = 0, clock = 0, baseDamage = damage, referenceSpeed = nil }
end
function Pursuer.step(
	rule: Enemies.Pursuer,
	state: State,
	kind: Enemies.Enemy,
	dt: number
): (Enemies.Enemy?, number, number?)
	state.clock += dt
	local ticks = math.floor(state.clock / rule.everySeconds)
	state.clock -= ticks * rule.everySeconds
	local count = math.min(rule.maxSteps - state.stage, ticks)
	if count <= 0 then
		return nil, 0, nil
	end
	local previous = state.stage
	state.stage += count
	local speed = count * rule.speedPerStep
	if previous < rule.changeAt and state.stage >= rule.changeAt then
		speed += rule.changeSpeed
	end
	local before = 1 + previous * rule.sizePerStep * rule.collisionScalingShare
	local after = 1 + state.stage * rule.sizePerStep * rule.collisionScalingShare
	local grown = table.clone(kind)
	grown.radius = kind.radius * after / before
	grown.hurtRadius = (kind.hurtRadius or kind.radius) * after / before
	grown.hitRadius = (kind.hitRadius or kind.radius) * after / before
	if kind.nativeHurtOffsetX ~= nil or kind.nativeHurtOffsetZ ~= nil then
		grown.nativeHurtOffsetX = (kind.nativeHurtOffsetX or 0) + (kind.nativeHurtChildX or 0) * (after - before)
		grown.nativeHurtOffsetZ = (kind.nativeHurtOffsetZ or 0) + (kind.nativeHurtChildZ or 0) * (after - before)
	end
	if kind.nativeHitOffsetX ~= nil or kind.nativeHitOffsetZ ~= nil then
		grown.nativeHitOffsetX = (kind.nativeHitOffsetX or 0) + (kind.nativeHitChildX or 0) * (after - before)
		grown.nativeHitOffsetZ = (kind.nativeHitOffsetZ or 0) + (kind.nativeHitChildZ or 0) * (after - before)
	end
	return grown, speed, math.round(state.baseDamage * (1 + rule.damagePercentPerStep * state.stage / 100))
end
function Pursuer.beginContacts(state: State)
	state.contacts = state.contacts or {}
	state.nextContacts = state.nextContacts or {}
	table.clear(state.nextContacts)
end
function Pursuer.contact(state: State, key: number | string): boolean
	assert(state.nextContacts)[key] = true
	if not assert(state.contacts)[key] then
		state.stage = 0
		return true
	end
	return false
end
function Pursuer.endContacts(state: State)
	state.contacts, state.nextContacts = state.nextContacts, state.contacts
end

function Pursuer.cap(rule: Enemies.Pursuer, state: State, speed: number): number
	local reference = state.referenceSpeed
	return if reference
			and reference >= 0
			and rule.playerSpeedShare
		then math.min(speed, reference * rule.playerSpeedShare)
		else speed
end
return Pursuer
