--!strict
-- Native Catling Gun targeting, gun poses, cadence and wandering; PetActors owns its body and fixed-frame stepping.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.Pets)
local Enemy = require(script.Parent.Parent.EnemySim)
local Map = require(script.Parent.Parent.MapService)
local Run = require(script.Parent.Parent.RunDirector)
local Random = require(script.Parent.Parent.RandomService)
local Rules = require(script.Parent.PetRules)
local Projectiles = require(script.Parent.Projectiles)
local Cat = {}
local scale = Config.Stats.range.studsPerPoint

local function rotate(x: number, z: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return x * c - z * s, x * s + z * c
end
function Cat.muzzle(o: any, side: string): Vector3
	local rig, pose = o.pet.guns[side], o.catGuns[side]
	local x, z = rotate(rig.muzzleXPoints, rig.muzzleZPoints * pose.flip, pose.angle)
	x, z = rotate(x + rig.pivotXPoints, z + rig.pivotZPoints, o.pet.bodyRotation)
	return o.position + Vector3.new((o.pet.muzzleOriginXPoints + x) * scale, 0, (o.pet.muzzleOriginZPoints + z) * scale)
end
function Cat.init(o: any, sheet: { [string]: number })
	o.catSheet, o.catStats = sheet, Rules.compute(o.pet.weapon, sheet, o.beastMaster)
	local frames = o.catStats.cooldown * C.frameRate
	o.catLeftFrames, o.catRightFrames, o.catFacing = frames, frames, 1
	o.catGuns = {}
	for side, rig in o.pet.guns do
		o.catGuns[side] = { angle = rig.restRotation, flip = 1 }
	end
end
function Cat.boosted(o: any, members: { any }): boolean
	local radius = o.pet.boostRadiusPoints * scale
	for _, player in Run.getParticipants() do
		local root = Map.getRootPosition(player)
		if root and Run.getParticipantState(player) == "Alive" then
			local body = Vector3.new(
				root.X + C.playerBody.offsetXPoints * scale,
				o.position.Y,
				root.Z + C.playerBody.offsetZPoints * scale
			)
			if (body - o.position).Magnitude <= radius + C.playerBody.radiusPoints * scale then
				return true
			end
		end
	end
	for _, other in members do
		local pet = other.pet
		if other ~= o and pet and not pet.catling then
			local body = other.position + Vector3.new(pet.bodyOffsetXPoints * scale, 0, pet.bodyOffsetZPoints * scale)
			if (body - o.position).Magnitude <= radius + pet.bodyRadiusPoints * scale then
				return true
			end
		end
	end
	return false
end
function Cat.goal(o: any, bounds: any, obstacles: { any }, random: () -> number): Vector3
	local rule = o.pet.wander
	if o.catGoal and (o.catGoal - o.position).Magnitude > rule.arrivalPoints * scale then
		return o.catGoal
	end
	local function sample(): Vector3
		return Vector3.new(
			bounds.center.X + (random() * 2 - 1) * math.max(0, bounds.halfX - rule.marginXPoints * scale),
			o.position.Y,
			bounds.center.Z + (random() * 2 - 1) * math.max(0, bounds.halfZ - rule.marginZPoints * scale)
		)
	end
	local point = sample()
	for _ = 1, rule.tries do
		local valid = true
		for _, obstacle in obstacles do
			if (point.X - obstacle.x) ^ 2 + (point.Z - obstacle.z) ^ 2 <= obstacle.radius ^ 2 then
				valid = false
				break
			end
		end
		if valid then
			o.catGoal = point
			return point
		end
		point = sample()
	end
	for _, obstacle in obstacles do
		local dx, dz = point.X - obstacle.x, point.Z - obstacle.z
		local squared = dx * dx + dz * dz
		if squared <= obstacle.radius ^ 2 then
			if squared < rule.zeroSquaredPoints * scale ^ 2 then
				dx, dz = 1, 0
			end
			local direction = Vector3.new(dx, 0, dz).Unit
			point = Vector3.new(obstacle.x, point.Y, obstacle.z)
				+ direction * (obstacle.radius + rule.forbiddenPushPoints * scale)
		end
	end
	o.catGoal = point
	return point
end
function Cat.step(o: any, sheet: { [string]: number }, boosted: boolean)
	if o.catSheet ~= sheet then
		o.catSheet, o.catStats = sheet, Rules.compute(o.pet.weapon, sheet, o.beastMaster)
	end
	local stats = o.catStats
	o.catLeftFrames, o.catRightFrames = math.max(0, o.catLeftFrames - 1), math.max(0, o.catRightFrames - 1)
	local nearby, targets = {}, {}
	Enemy.queryRadius(o.position, o.pet.targetRadiusPoints * scale, nearby)
	for _, side in { "left", "right" } do
		local muzzle, nearest = Cat.muzzle(o, side), math.huge
		for _, id in nearby do
			local at = Enemy.getPosition(id)
			local distance = if at then (at - muzzle).Magnitude else math.huge
			if
				Enemy.getKind(id) ~= "Tree"
				and distance >= o.pet.weapon.minRangePoints * scale
				and distance < nearest
			then
				targets[side], nearest = { at = at, distance = distance }, distance
			end
		end
	end
	for _, side in { "left", "right" } do
		local target = targets[side]
		if target then
			local direction = target.at - o.position
			local angle = math.atan2(direction.Z, direction.X)
			Random.number("Combat", o.owner) -- The original orientation pass rolls accuracy even without shooting.
			local flip = if direction.X > 0 then 1 else -1
			if o.catFacing < 0 then
				angle = math.rad(math.modf(180 - math.deg(angle)))
				flip = -flip
			end
			o.catGuns[side].angle, o.catGuns[side].flip = angle, flip
		end
	end
	local side = if o.catLeftFrames == 0
			and targets.left
			and targets.left.distance <= stats.range
		then "left"
		elseif o.catRightFrames == 0 and targets.right and targets.right.distance <= stats.range then "right"
		else nil
	if not side then
		return
	end
	local target = targets[side].at
	local physical = if o.catFacing >= 0 then side elseif side == "left" then "right" else "left"
	local direction = target - o.position
	if direction.Magnitude == 0 then
		direction = Vector3.new(1, 0, 0)
	end
	Projectiles.launchPet(o.owner, Cat.muzzle(o, physical), o.pet.weapon, sheet, { direction.Unit }, o.beastMaster)
	local frames = stats.cooldown * C.frameRate * (if boosted then o.pet.boostAttackRatio else 1)
	o.catLeftFrames = if side == "left" then frames else frames / 2
	o.catRightFrames = if side == "right" then frames else frames / 2
end
return Cat
