--!strict
--!native
-- Burning enemies (DESIGN.md section 6, Brotato's burn since B5) as plain data, owned by WeaponService/Arsenal: weapons
-- with burnDamage and item effects ignite enemies, and every `interval` seconds a burn deals its damage once, until
-- its ticks are used up or the enemy is gone. Burns do not stack: igniting a burning enemy keeps the higher damage, the
-- more ticks left and the larger spread of the two, and the running tick timer. A burn with `spread` passes a copy to
-- that many of the nearest enemies within spreadRadius that do not burn yet on each of its ticks; copies spread on.
-- The world is reached through Hooks (Arsenal: enemy queries, the damage itself, the burning mark for the snapshots).
-- Tested in tests/Weapons.spec.luau.

export type Burn = {
	ownerId: number,
	weapon: any?, -- the Arsenal.Weapon that lit it (its damage counts there); nil for item effects
	damage: number, -- per tick
	ticks: number, -- ticks of a fresh burn, also for the copies it spreads
	ticksLeft: number,
	interval: number, -- seconds between ticks
	timer: number, -- seconds until the next tick
	spread: number,
}

export type Hooks = {
	isAlive: (id: number) -> boolean,
	position: (id: number) -> (number?, number?),
	queryCircle: (x: number, z: number, radius: number, out: { number }) -> number,
	tick: (burn: Burn, id: number) -> (), -- deals one tick of damage
	setBurning: (id: number, on: boolean) -> (),
}

local Afflictions = {}
Afflictions.__index = Afflictions

export type Afflictions = typeof(setmetatable(
	{} :: {
		hooks: Hooks,
		spreadRadius: number,
		burns: { [number]: Burn }, -- by enemy id
		ignitions: { number }, -- spread copies of this step, as enemy ids (burns in `pending`)
		pending: { Burn },
		found: { number },
		ending: { number },
	},
	Afflictions
))

function Afflictions.new(hooks: Hooks, spreadRadius: number): Afflictions
	return setmetatable({
		hooks = hooks,
		spreadRadius = spreadRadius,
		burns = {},
		ignitions = {},
		pending = {},
		found = {},
		ending = {},
	}, Afflictions)
end

-- A fresh burn record: `ticks` ticks of `damage`, one every `interval` seconds, the first after one interval.
function Afflictions.newBurn(
	ownerId: number,
	weapon: any?,
	damage: number,
	ticks: number,
	interval: number,
	spread: number
): Burn
	return {
		ownerId = ownerId,
		weapon = weapon,
		damage = damage,
		ticks = ticks,
		ticksLeft = ticks,
		interval = interval,
		timer = interval,
		spread = spread,
	}
end

-- Sets a living enemy on fire or merges the burn into the one it has. Returns true if it burns now.
function Afflictions.ignite(self: Afflictions, id: number, burn: Burn): boolean
	if not (burn.ticks >= 1 and burn.damage > 0) or not self.hooks.isAlive(id) then
		return false
	end
	local current = self.burns[id]
	if not current then
		self.burns[id] = burn
		self.hooks.setBurning(id, true)
		return true
	end
	if burn.damage > current.damage then
		current.damage = burn.damage
		current.ownerId, current.weapon = burn.ownerId, burn.weapon -- the stronger burn gets the credit
	end
	current.ticks = math.max(current.ticks, burn.ticks)
	current.ticksLeft = math.max(current.ticksLeft, burn.ticks)
	current.spread = math.max(current.spread, burn.spread)
	current.interval = math.min(current.interval, burn.interval)
	current.timer = math.min(current.timer, current.interval)
	return true
end

function Afflictions.isBurning(self: Afflictions, id: number): boolean
	return self.burns[id] ~= nil
end

-- Number of burning enemies.
function Afflictions.count(self: Afflictions): number
	local count = 0
	for _ in self.burns do
		count += 1
	end
	return count
end

-- Puts out every burn (run start, wave end). The enemies are cleared at the same time, so no marks are reset.
function Afflictions.clear(self: Afflictions)
	table.clear(self.burns)
	table.clear(self.ignitions)
	table.clear(self.pending)
end

-- Copies of `burn` for the nearest enemies around `id` that do not burn yet, at most burn.spread of them.
local function spread(self: Afflictions, burn: Burn, id: number)
	local x, z = self.hooks.position(id)
	if not (x and z) then
		return
	end
	local found = self.found
	local count = self.hooks.queryCircle(x, z, self.spreadRadius, found)
	for _ = 1, burn.spread do
		local best, bestSquared = nil, math.huge
		for i = 1, count do
			local other = found[i]
			if other ~= id and not self.burns[other] and not table.find(self.ignitions, other) then
				local ox, oz = self.hooks.position(other)
				if ox and oz then
					local squared = (ox - x) ^ 2 + (oz - z) ^ 2
					if squared < bestSquared then
						best, bestSquared = other, squared
					end
				end
			end
		end
		if not best then
			return
		end
		table.insert(self.ignitions, best)
		table.insert(
			self.pending,
			Afflictions.newBurn(burn.ownerId, burn.weapon, burn.damage, burn.ticks, burn.interval, burn.spread)
		)
	end
end

-- Runs every burn for dt seconds: ticks that are due deal their damage (and spread), spent burns go out.
function Afflictions.step(self: Afflictions, dt: number)
	local hooks = self.hooks
	local ending = self.ending
	for id, burn in self.burns do
		if not hooks.isAlive(id) then
			table.insert(ending, id)
			continue
		end
		burn.timer -= dt
		while burn.timer <= 0 and burn.ticksLeft > 0 do
			burn.timer += burn.interval
			burn.ticksLeft -= 1
			if burn.spread > 0 then
				spread(self, burn, id)
			end
			hooks.tick(burn, id)
			if not hooks.isAlive(id) then
				break
			end
		end
		if burn.ticksLeft <= 0 or not hooks.isAlive(id) then
			table.insert(ending, id)
		end
	end
	for _, id in ending do
		self.burns[id] = nil
		hooks.setBurning(id, false)
	end
	table.clear(ending)
	for index, id in self.ignitions do
		self:ignite(id, self.pending[index])
	end
	table.clear(self.ignitions)
	table.clear(self.pending)
end

return Afflictions
