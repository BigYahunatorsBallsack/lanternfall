--!strict
-- Authoritative native fire-puddle entry/expiry; WeaponService supplies collision, ignition and cosmetic callbacks.
local growthAt = require(game:GetService("ReplicatedStorage").Shared.Util.FirePuddleShape)
local Arsenal = require(script.Parent.Arsenal)
type Stats = { [string]: number }
type Entry = { weapon: Arsenal.Weapon, x: number, z: number, stats: Stats, age: number, inside: { [number]: boolean } }
export type Hooks = {
	query: (number, number, number, { number }) -> number,
	ignite: (Arsenal.Weapon, number, Stats) -> (),
	emit: (Arsenal.Weapon, { [string]: any }) -> (),
}
local Puddles = {}
Puddles.__index = Puddles
export type Puddles = typeof(setmetatable({} :: { hooks: Hooks, entries: { Entry }, found: { number } }, Puddles))
function Puddles.new(hooks: Hooks): Puddles
	return setmetatable({ hooks = hooks, entries = {}, found = {} }, Puddles)
end
function Puddles.spawn(self: Puddles, weapon: Arsenal.Weapon, x: number, z: number, stats: Stats)
	table.insert(self.entries, { weapon = weapon, x = x, z = z, stats = table.clone(stats), age = 0, inside = {} })
	self.hooks.emit(
		weapon,
		{ kind = "Puddle", x = x, z = z, radius = stats.puddleRadius, duration = stats.puddleSeconds }
	)
end
function Puddles.step(self: Puddles, dt: number)
	for index = #self.entries, 1, -1 do
		local entry = self.entries[index]
		entry.age += dt
		if entry.age >= entry.stats.puddleSeconds then
			table.remove(self.entries, index)
			continue
		end
		local growth = growthAt(entry.age)
		local n = self.hooks.query(entry.x, entry.z, entry.stats.puddleRadius * growth, self.found)
		local inside: { [number]: boolean } = {}
		for i = 1, n do
			local id = self.found[i]
			inside[id] = true
			if not entry.inside[id] then
				self.hooks.ignite(entry.weapon, id, entry.stats)
			end
		end
		entry.inside = inside
	end
end
function Puddles.clear(self: Puddles)
	table.clear(self.entries)
end
return Puddles
