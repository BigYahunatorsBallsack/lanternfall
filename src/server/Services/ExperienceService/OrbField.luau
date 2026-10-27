--!strict
-- XP orbs on the arena floor as plain arrays (DESIGN.md section 8): killed enemies drop one, living players pick up
-- every orb within their pickup radius. Pure and unit tested (tests/Experience.spec.luau); owned by
-- ExperienceService. With `maxOrbs` orbs on the floor, a new orb's XP joins the nearest orb instead, so a long
-- run never piles up thousands of parts on the clients.

local OrbField = {}
OrbField.__index = OrbField

export type OrbField = typeof(setmetatable(
	{} :: {
		maxOrbs: number,
		nextId: number,
		ids: { number },
		xs: { number },
		zs: { number },
		values: { number },
		indexOf: { [number]: number },
	},
	OrbField
))

function OrbField.new(maxOrbs: number): OrbField
	return setmetatable({
		maxOrbs = maxOrbs,
		nextId = 0,
		ids = {},
		xs = {},
		zs = {},
		values = {},
		indexOf = {},
	}, OrbField)
end

function OrbField.clear(self: OrbField)
	table.clear(self.ids)
	table.clear(self.xs)
	table.clear(self.zs)
	table.clear(self.values)
	table.clear(self.indexOf)
end

function OrbField.count(self: OrbField): number
	return #self.ids
end

-- Drops an orb worth `value` XP. Returns its id; when the field is full that is the id of the nearest orb, which
-- now holds the XP of both (merged = true).
function OrbField.spawn(self: OrbField, x: number, z: number, value: number): (number, boolean)
	local count = #self.ids
	if count >= self.maxOrbs and count > 0 then
		local best, bestDistance = 1, math.huge
		for i = 1, count do
			local dx, dz = self.xs[i] - x, self.zs[i] - z
			local distance = dx * dx + dz * dz
			if distance < bestDistance then
				best, bestDistance = i, distance
			end
		end
		self.values[best] += value
		return self.ids[best], true
	end
	self.nextId += 1
	local id = self.nextId
	local index = count + 1
	self.ids[index] = id
	self.xs[index] = x
	self.zs[index] = z
	self.values[index] = value
	self.indexOf[id] = index
	return id, false
end

local function removeAt(self: OrbField, index: number)
	local last = #self.ids
	self.indexOf[self.ids[index]] = nil
	if index ~= last then
		self.ids[index] = self.ids[last]
		self.xs[index] = self.xs[last]
		self.zs[index] = self.zs[last]
		self.values[index] = self.values[last]
		self.indexOf[self.ids[index]] = index
	end
	self.ids[last] = nil
	self.xs[last] = nil
	self.zs[last] = nil
	self.values[last] = nil
end

-- Removes every orb within `radius` of x/z, appends their ids to `out` and returns the XP they held.
function OrbField.collect(self: OrbField, x: number, z: number, radius: number, out: { number }): number
	local total = 0
	local radiusSquared = radius * radius
	for i = #self.ids, 1, -1 do
		local dx, dz = self.xs[i] - x, self.zs[i] - z
		if dx * dx + dz * dz <= radiusSquared then
			table.insert(out, self.ids[i])
			total += self.values[i]
			removeAt(self, i)
		end
	end
	return total
end

-- XP of every orb on the floor together.
function OrbField.total(self: OrbField): number
	local total = 0
	for _, value in self.values do
		total += value
	end
	return total
end

-- Position and value of an orb, nil for unknown ids.
function OrbField.get(self: OrbField, id: number): (number?, number?, number?)
	local index = self.indexOf[id]
	if not index then
		return nil, nil, nil
	end
	return self.xs[index], self.zs[index], self.values[index]
end

-- Every orb as a flat list id, x, z, value, ... (full sync for clients).
function OrbField.flatten(self: OrbField): { number }
	local list = table.create(#self.ids * 4)
	for i, id in self.ids do
		table.insert(list, id)
		table.insert(list, self.xs[i])
		table.insert(list, self.zs[i])
		table.insert(list, self.values[i])
	end
	return list
end

return OrbField
