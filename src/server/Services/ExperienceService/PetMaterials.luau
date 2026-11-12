--!strict
-- Native Lootworm attraction and gold contact over the existing OrbField; ExperienceService owns rewards and feeds.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.Pets)
local scale = require(Shared.Config.Stats).range.studsPerPoint
local Pets = {}
Pets.__index = Pets
function Pets.new(field: any, now: () -> number): any
	return setmetatable({ field = field, now = now, revision = 0, claims = {}, scales = {}, readyAt = {} }, Pets)
end
function Pets.forget(self: any, id: number)
	self.claims[id], self.scales[id], self.readyAt[id] = nil, nil, nil
end
function Pets.clear(self: any)
	table.clear(self.claims)
	table.clear(self.scales)
	table.clear(self.readyAt)
	self.revision += 1
end
function Pets.spawned(self: any, id: number, merged: boolean, bagged: boolean, addedValue: number?)
	self.revision += 1
	if merged then
		self.scales[id] =
			math.min(C.material.maximumScale, (self.scales[id] or 1) + C.material.mergeGrowth * (addedValue or 1))
	else
		self.scales[id] = if bagged then C.material.bagScale else 1
		self.readyAt[id] = self.now() + C.material.idleFrames / C.frameRate
	end
end
function Pets.release(self: any, actorId: number)
	for id, claim in self.claims do
		if claim.actor == actorId then
			self.claims[id] = nil
		end
	end
end
function Pets.isClaimed(self: any, id: number): boolean
	return self.claims[id] ~= nil
end
function Pets.touches(self: any, id: number, at: Vector3, radius: number): boolean
	local x, z = self.field:get(id)
	if not x then
		return false
	end
	local size = self.scales[id] or 1
	local dx = math.max(0, math.abs(x - at.X) - C.material.halfXPoints * size * scale)
	local dz = math.max(0, math.abs(z - at.Z) - C.material.halfZPoints * size * scale)
	return dx * dx + dz * dz <= radius * radius
end
function Pets.step(
	self: any,
	actorId: number,
	at: Vector3,
	dt: number,
	roll: () -> number,
	onPickup: (number, number, number) -> (),
	onMove: (number, number, number, number) -> ()
): number
	local rule = C.kinds.Lootworm
	local pickup = at + Vector3.new(rule.pickupOffsetXPoints * scale, 0, rule.pickupOffsetZPoints * scale)
	local bonus = 0
	for _, id in table.clone(self.field.ids) do
		local x, z = self.field:get(id)
		if not x then
			continue
		end
		local claim = self.claims[id]
		if not claim and self:touches(id, at, rule.attractRadiusPoints * scale) then
			claim = { actor = actorId, speed = C.material.attractSpeedPoints * scale }
			self.claims[id] = claim
		end
		if claim and claim.actor == actorId and self.now() >= (self.readyAt[id] or 0) then
			local offset = at - Vector3.new(x, at.Y, z)
			if offset.Magnitude > 0 then
				local point = Vector3.new(x, at.Y, z) + offset.Unit * math.min(offset.Magnitude, claim.speed * dt)
				self.field:move(id, point.X, point.Z)
				onMove(id, point.X, point.Z, select(3, self.field:get(id)))
			end
			claim.speed += C.material.accelerationPointsPerFrame * scale * dt * C.frameRate
		end
		if self:touches(id, pickup, rule.pickupRadiusPoints * scale) then
			local value = self.field:take(id)
			self:forget(id)
			if value then
				local factor = if rule.doubleChance > 0 and roll() <= rule.doubleChance then 2 else 1
				bonus += value * (factor - 1)
				onPickup(id, value * factor, factor)
			end
		end
	end
	return bonus
end
return Pets
