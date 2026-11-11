--!strict
-- Original Blazemander physics flags and asynchronous melee enable; PetActors advances one native frame at a time.
local C = require(game:GetService("ReplicatedStorage").Shared.Config.Pets)
local Rules = require(script.Parent.PetRules)
local Timing = {}
local function refresh(o: any, sheet: { [string]: number })
	if o.blazeSheet ~= sheet then
		o.blazeSheet = sheet
		o.blazeMeleeStats = Rules.compute(o.pet.weapon, sheet, o.beastMaster)
		o.blazeRangedStats = Rules.compute(o.pet.ranged, sheet, o.beastMaster)
	end
end
function Timing.init(o: any, sheet: { [string]: number }, random: () -> number)
	o.blazeSheet = nil
	refresh(o, sheet)
	o.blazeFrame, o.blazeAttacking, o.blazeFiring, o.blazeHitbox = 0, false, false, false
	o.blazeTimers, o.blazeHitIds = {}, {}
	o.blazeMeleeFrames = o.blazeMeleeStats.cooldown * C.frameRate
	o.blazeRangedFrames = o.blazeRangedStats.cooldown
		* C.frameRate
		* (o.pet.rangedInitialMinimumShare + (1 - o.pet.rangedInitialMinimumShare) * random())
end
function Timing.step(o: any, sheet: { [string]: number }, nearby: boolean): (boolean, boolean)
	refresh(o, sheet)
	o.blazeFrame += 1
	if not o.blazeAttacking then
		o.blazeMeleeFrames = math.max(0, o.blazeMeleeFrames - 1)
		o.blazeRangedFrames = math.max(0, o.blazeRangedFrames - 1)
	end
	local fire = false
	if o.blazeRangedFrames <= 0 and not o.blazeFiring and not o.blazeAttacking then
		if nearby then
			o.blazeFiring, fire = true, true
		end
	elseif o.blazeMeleeFrames <= 0 and not o.blazeAttacking and not o.blazeFiring then
		if nearby then
			o.blazeAttacking = true
			table.insert(o.blazeTimers, o.blazeFrame + o.pet.meleeDelaySeconds * C.frameRate)
		end
	elseif o.blazeRangedFrames == 0 and o.blazeFiring then
		o.blazeFiring = false
		o.blazeRangedFrames = o.blazeRangedStats.cooldown * C.frameRate
	elseif o.blazeMeleeFrames == 0 and o.blazeAttacking then
		o.blazeAttacking, o.blazeHitbox = false, false
		o.blazeMeleeFrames = o.blazeMeleeStats.cooldown * C.frameRate
		table.clear(o.blazeHitIds)
	end
	local hitbox = o.blazeHitbox
	-- SceneTreeTimer resumes the yielded attack independently; a reopened area participates in the next physics query.
	for index = #o.blazeTimers, 1, -1 do
		if o.blazeTimers[index] <= o.blazeFrame then
			o.blazeHitbox = true
			table.remove(o.blazeTimers, index)
		end
	end
	return fire, hitbox
end
return Timing
