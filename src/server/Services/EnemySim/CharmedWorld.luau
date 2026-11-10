--!strict
-- Invulnerable charmed actors retain native World AI in a disjoint faction; EnemySim owns conversion and death callbacks.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.Charm)
local World = require(script.Parent.World)
local Volleys = require(script.Parent.Volleys)
local Friends = {}
Friends.__index = Friends
function Friends.new(params: any, callbacks: any): any
	local options = table.clone(params)
	options.goalsWithoutTargets = true
	return setmetatable({
		world = World.new(options),
		members = {},
		counts = {},
		callbacks = callbacks,
		targetIds = {},
		targetXs = {},
		targetZs = {},
		targetRadii = {},
		shots = Volleys.new(options),
		shotSources = {},
		shotOwners = {},
		previous = {},
	}, Friends)
end
function Friends.count(self: any, owner: number): number
	return self.counts[owner] or 0
end
function Friends.convert(self: any, source: any, id: number, owner: number, now: number, base: any): boolean
	local index = source.indexOf[id]
	if not index or not source:isAlive(id) or self.members[id] or self:count(owner) >= C.maximumPerOwner then
		return false
	end
	local kind = source.kinds[index]
	if not source:transferTo(self.world, id) then
		return false
	end
	local actor = self.world.indexOf[id]
	local friendly = table.clone(kind)
	local movement = C.movement[kind.id]
	if movement then
		friendly.wander = {
			around = if movement == "AroundTarget" then "Target" else "Arena",
			range = C.aroundRange,
			rangeJitter = C.aroundRandomization,
			arriveStuds = C.goalPrecision,
			maxSeconds = math.huge,
		}
		self.world.hasGoal[actor] = false
		self.world.wanderLeft[actor] = if kind.wander and self.world.wanderLeft[actor] > 0 then math.huge else 0
	end
	friendly.pulse = nil -- charmed Healer/Buffer target players and structures through the support callback
	self.world.kinds[actor] = friendly
	self.world.burning[actor] = false
	self.world.contactDamage[actor] = math.round(base.contact * C.damageMultiplier)
	self.world.shotDamage[actor] = math.round(base.shot * C.damageMultiplier)
	if kind.speed * self.world.speedFactors[actor] * self.world.boosts[actor] > 0 then
		self.world.speedBonuses[actor] += C.bonusSpeedPoints * Config.Stats.range.studsPerPoint
	end
	self.world.maxSpeed = math.max(
		self.world.maxSpeed,
		kind.speed * self.world.speedFactors[actor] * self.world.boosts[actor] + self.world.speedBonuses[actor]
	)
	self.members[id] = { id = id, owner = owner, kind = kind, expires = now + C.duration, base = base }
	self.counts[owner] = (self.counts[owner] or 0) + 1
	return true
end
function Friends.clear(self: any)
	self.world:clear()
	self.shots:clear()
	table.clear(self.shotSources)
	table.clear(self.shotOwners)
	table.clear(self.previous)
	table.clear(self.members)
	table.clear(self.counts)
end
local function emit(self: any, owner: number, event: any)
	if self.callbacks.emitShot then
		self.callbacks.emitShot(owner, event)
	end
end
function Friends.fire(
	self: any,
	member: any,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	range: number,
	radius: number,
	damage: number
)
	local id = self.shots:fire(x, z, dx, dz, speed, range, radius, damage)
	self.shotSources[id], self.shotOwners[id] = member.id, member.owner
	emit(
		self,
		member.owner,
		{ kind = "CharmFire", id = id, x = x, z = z, dx = dx, dz = dz, speed = speed, range = range }
	)
end
local function stepShots(self: any, dt: number)
	self.shots:step(dt, self.targetXs, self.targetZs, #self.targetIds, self.targetRadii)
	for index = 1, self.shots.hitCount do
		local offset = (index - 1) * 2
		local target = self.targetIds[self.shots.hits[offset + 1]]
		self.callbacks.damage(target, self.shots.hits[offset + 2], self.shotSources[self.shots.hitSources[index]])
	end
	for index = 0, self.shots.endedCount - 1 do
		local id = self.shots.ended[index * 2 + 1]
		emit(self, self.shotOwners[id], { kind = "End", id = id, distance = self.shots.ended[index * 2 + 2] })
	end
	local alive = {}
	for _, shot in self.shots.shots do
		alive[shot.id] = true
	end
	for id in self.shotSources do
		if not alive[id] then
			self.shotSources[id] = nil
			self.shotOwners[id] = nil
		end
	end
end
local function fireShots(self: any, dt: number)
	local world = self.world
	for index = 0, world.shotCount - 1 do
		local offset = index * 5
		local member = self.members[world.shots[offset + 1]]
		local ranged = member and member.kind.ranged
		if not ranged then
			continue
		end
		local x, z, target, damage =
			world.shots[offset + 2], world.shots[offset + 3], world.shots[offset + 4], world.shots[offset + 5]
		local tx, tz = self.targetXs[target], self.targetZs[target]
		local previous = self.previous[self.targetIds[target]]
		if previous then
			local flight = math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2) / ranged.projectileSpeed
			tx += (self.targetXs[target] - previous.x) / dt * flight * ranged.aimLead
			tz += (self.targetZs[target] - previous.z) / dt * flight * ranged.aimLead
		end
		local dx, dz = tx - x, tz - z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance > 0 then
			dx, dz = dx / distance, dz / distance
			local spread = ranged.spreadRadians or 0
			if spread > 0 then
				local random = if self.callbacks.random then self.callbacks.random(member.owner) else math.random()
				local angle = (random * 2 - 1) * spread
				local c, s = math.cos(angle), math.sin(angle)
				dx, dz = dx * c - dz * s, dx * s + dz * c
			end
			self:fire(
				member,
				x + dx * member.kind.radius,
				z + dz * member.kind.radius,
				dx,
				dz,
				ranged.projectileSpeed,
				ranged.projectileRange,
				ranged.projectileRadius,
				damage
			)
		end
	end
end
local function fireChargeTrails(self: any)
	local world = self.world
	for id, member in self.members do
		local index = world.indexOf[id]
		local charge = member.kind.charge
		if not charge or not charge.projectileDamage or world.modes[index] ~= World.MODE_RUSH then
			member.trail = nil
			continue
		end
		local x, z = world.xs[index], world.zs[index]
		local trail = member.trail or { x = x, z = z, distance = charge.trailEvery }
		member.trail = trail
		trail.distance += math.sqrt((x - trail.x) ^ 2 + (z - trail.z) ^ 2)
		trail.x, trail.z = x, z
		if trail.distance >= charge.trailEvery then
			trail.distance %= charge.trailEvery
			local c, s = math.cos(charge.trailAngle), math.sin(charge.trailAngle)
			local rx, rz = world.rushXs[index], world.rushZs[index]
			for _, side in { -1, 1 } do
				self:fire(
					member,
					x,
					z,
					rx * c - rz * s * side,
					rx * s * side + rz * c,
					charge.projectileSpeed,
					charge.projectileRange,
					charge.projectileRadius,
					world:getShotDamage(id)
				)
			end
		end
	end
end
function Friends.step(self: any, dt: number, now: number, hostile: any)
	if next(self.members) == nil and self.shots:getCount() == 0 then
		return
	end
	for id, member in self.members do
		if now >= member.expires then
			local x, z = self.world:getPosition(id)
			self.world:remove(id)
			self.members[id] = nil
			self.counts[member.owner] -= 1
			self.callbacks.expired(member, x, z)
		end
	end
	local ids, xs, zs, radii = self.targetIds, self.targetXs, self.targetZs, self.targetRadii
	table.clear(ids)
	table.clear(xs)
	table.clear(zs)
	table.clear(radii)
	for index = 1, hostile.count do
		if hostile.hp[index] > 0 and hostile.kinds[index].id ~= "Tree" then
			table.insert(ids, hostile.ids[index])
			table.insert(xs, hostile.xs[index])
			table.insert(zs, hostile.zs[index])
			table.insert(radii, (hostile.kinds[index].hurtRadius or hostile.kinds[index].radius))
		end
	end
	local contacts = self.world:step(dt, xs, zs, #ids, nil, nil, radii)
	stepShots(self, dt)
	fireShots(self, dt)
	fireChargeTrails(self)
	for index, id in ids do
		if contacts[index] > 0 then
			self.callbacks.damage(id, contacts[index], self.world.contactSources[index])
		end
	end
	for index = 1, self.world.summonCount do
		local id = self.world.summons[index]
		local member = self.members[id]
		if member and member.kind.summon and self.callbacks.spawn then
			local x, z = self.world:getPosition(id)
			local summon = member.kind.summon
			self.callbacks.spawn(member, summon.enemy, x, z, summon.count, member.kind.radius + C.summonPadding)
		end
	end
	for index = 1, self.world.hatchCount do
		local id = self.world.hatches[index]
		local member = self.members[id]
		if member and member.kind.hatch and self.callbacks.spawn then
			local x, z = self.world:getPosition(id)
			local hatch = member.kind.hatch
			self.world:remove(id)
			self.members[id] = nil
			self.counts[member.owner] -= 1
			self.callbacks.spawn(member, hatch.enemy, x, z, hatch.count, hatch.spread)
		end
	end
	table.clear(self.previous)
	for index, id in ids do
		self.previous[id] = { x = xs[index], z = zs[index] }
	end
	if self.callbacks.support then
		for id, member in self.members do
			local x, z = self.world:getPosition(id)
			self.callbacks.support(member, x, z, dt)
		end
	end
end
return Friends
