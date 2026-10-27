--!strict
-- Weapon framework core (DESIGN.md section 6) as plain data without Roblox instances, so tests/Weapons.spec.luau
-- can run it against a real enemy World. Owned by WeaponService, which places the owners before every step, sends
-- their loadouts and passes the effects on to the clients.
--
-- Owners (players, by userId) carry up to `maxWeapons` weapons, each up to `maxLevel`. Each step, per weapon:
--   1. behavior.step moves what the weapon already has going (blades, projectiles in flight)
--   2. once the weapon's cooldown is over and its owner is placed (alive), behavior.fire starts the next attack;
--      a fire without a target returns false and is tried again on the next step
-- Behaviors (WeaponService/Behaviors, one module per weapon, picked by Config.Weapons[id].behavior) reach the
-- world only through the Context: enemy queries, hit (damage with crits and life steal, counted per weapon), push (knockback)
-- and emit (an effect for the clients' visuals).

local Shared = game:GetService("ReplicatedStorage").Shared
local Evolutions = require(Shared.Config.Evolutions)
local Weapons = require(Shared.Config.Weapons)

local WeaponStats = require(script.Parent.WeaponStats)

export type Bonuses = WeaponStats.Bonuses

-- How weapons reach the enemies: EnemySim in the game, a World in tests. Positions are floor x/z.
export type Enemies = {
	queryCircle: (x: number, z: number, radius: number, out: { number }) -> number,
	querySegment: (x0: number, z0: number, x1: number, z1: number, radius: number, out: { number }) -> number,
	getPosition: (id: number) -> (number?, number?),
	-- returns whether the hit killed the enemy, and the HP it took; `crit` only tells (damage numbers)
	damage: (id: number, amount: number, ownerId: number, crit: boolean) -> (boolean, number),
	push: (id: number, dx: number, dz: number) -> (),
}

-- Becomes a Net/Types.WeaponEffect: the behavior sets kind and its fields, emit adds weapon, userId and at.
export type Effect = { [string]: any }

export type Weapon = {
	id: string, -- key in Config.Weapons
	config: Weapons.Weapon,
	behaviorName: string,
	behavior: Behavior,
	ownerId: number,
	level: number,
	evolution: string?,
	stats: WeaponStats.Stats,
	addedAt: number, -- server time
	cooldownLeft: number,
	state: { [string]: any }, -- the behavior's own data; starts empty
	damageDealt: number,
	kills: number,
}

-- Handed to behaviors; owner fields are set before each owner's weapons run.
export type Context = {
	now: number, -- server time of this step
	active: boolean, -- the owner is placed (alive) this step; behaviors start nothing new around inactive owners
	x: number, -- owner position on the floor
	z: number,
	vx: number, -- owner velocity, studs/s
	vz: number,
	sweepStep: number, -- see Config.Simulation.weaponSweepStep
	queryCircle: (self: Context, x: number, z: number, radius: number, out: { number }) -> number,
	querySegment: (
		self: Context,
		x0: number,
		z0: number,
		x1: number,
		z1: number,
		radius: number,
		out: { number }
	) -> number,
	-- up to maxCount enemies overlapping the circle (x, z, range), closest first
	nearestEnemies: (self: Context, x: number, z: number, range: number, maxCount: number, out: { number }) -> number,
	enemyPosition: (self: Context, id: number) -> (number?, number?),
	-- damages one enemy with the weapon's damage times `multiplier`, rolls crits and life steal; true if it died
	hit: (self: Context, weapon: Weapon, id: number, multiplier: number?) -> boolean,
	push: (self: Context, id: number, dx: number, dz: number) -> (),
	emit: (self: Context, weapon: Weapon, effect: Effect) -> (),
	random: (self: Context) -> number, -- 0 <= n < 1
	nextId: (self: Context) -> number, -- projectile ids, unique within the run
}

export type Behavior = {
	-- Every step while the run is active, also while the owner is down (ctx.active false).
	step: ((weapon: Weapon, ctx: Context, dt: number) -> ())?,
	-- When the cooldown (stats.cooldown) is over and the owner is active. Returns false if there was nothing to
	-- attack, so it is tried again next step.
	fire: ((weapon: Weapon, ctx: Context) -> boolean)?,
}

export type Params = {
	enemies: Enemies,
	behaviors: { [string]: Behavior }, -- by behavior name
	maxWeapons: number,
	maxLevel: number,
	critChance: number, -- for weapons whose stats carry no critChance (WeaponStats sets it)
	critMultiplier: number,
	minCooldown: number,
	onLifeSteal: ((ownerId: number) -> ())?, -- a hit rolled the weapon's life steal (CombatService heals)
	sweepStep: number,
	random: () -> number,
}

type Owner = {
	weapons: { Weapon },
	bonuses: Bonuses,
	placed: boolean,
	x: number,
	z: number,
	vx: number,
	vz: number,
}

export type DamageStats = { [string]: { damage: number, kills: number } }

local MAX_PROJECTILE_ID = 2 ^ 31

local Arsenal = {}
Arsenal.__index = Arsenal

export type Arsenal = typeof(setmetatable(
	{} :: {
		params: Params,
		owners: { [number]: Owner },
		order: { number }, -- owner ids in the order they joined, so stepping order is stable
		effects: { Effect },
		nextProjectileId: number,
		context: Context,
	},
	Arsenal
))

local function makeContext(self: Arsenal): Context
	local params = self.params
	local enemies = params.enemies
	local candidates: { number } = {}
	local squaredDistances: { number } = {}

	local ctx = {
		now = 0,
		active = false,
		x = 0,
		z = 0,
		vx = 0,
		vz = 0,
		sweepStep = params.sweepStep,
	} :: any

	function ctx.queryCircle(_, x: number, z: number, radius: number, out: { number }): number
		return enemies.queryCircle(x, z, radius, out)
	end

	function ctx.querySegment(
		_,
		x0: number,
		z0: number,
		x1: number,
		z1: number,
		radius: number,
		out: { number }
	): number
		return enemies.querySegment(x0, z0, x1, z1, radius, out)
	end

	function ctx.nearestEnemies(_, x: number, z: number, range: number, maxCount: number, out: { number }): number
		if maxCount < 1 then
			return 0
		end
		local found = enemies.queryCircle(x, z, range, candidates)
		local count = 0
		for i = 1, found do
			local id = candidates[i]
			local ex, ez = enemies.getPosition(id)
			if ex and ez then
				local squared = (ex - x) ^ 2 + (ez - z) ^ 2
				if count < maxCount or squared < squaredDistances[count] then
					-- insert into the sorted list, dropping the furthest when full
					local slot = if count < maxCount then count + 1 else count
					count = slot
					while slot > 1 and squaredDistances[slot - 1] > squared do
						out[slot] = out[slot - 1]
						squaredDistances[slot] = squaredDistances[slot - 1]
						slot -= 1
					end
					out[slot] = id
					squaredDistances[slot] = squared
				end
			end
		end
		return count
	end

	function ctx.enemyPosition(_, id: number): (number?, number?)
		return enemies.getPosition(id)
	end

	function ctx.hit(_, weapon: Weapon, id: number, multiplier: number?): boolean
		local stats = weapon.stats
		local amount = stats.damage * (multiplier or 1)
		local crit = params.random() < (stats.critChance or params.critChance)
		if crit then
			amount *= params.critMultiplier
		end
		local killed, dealt = enemies.damage(id, amount, weapon.ownerId, crit)
		local lifeSteal = stats.lifeSteal or 0
		if dealt > 0 and lifeSteal > 0 and params.onLifeSteal and params.random() < lifeSteal then
			params.onLifeSteal(weapon.ownerId)
		end
		weapon.damageDealt += dealt
		if killed then
			weapon.kills += 1
		end
		return killed
	end

	function ctx.push(_, id: number, dx: number, dz: number)
		enemies.push(id, dx, dz)
	end

	function ctx.emit(_, weapon: Weapon, effect: Effect)
		effect.weapon = weapon.behaviorName
		effect.userId = weapon.ownerId
		effect.at = ctx.now
		table.insert(self.effects, effect)
	end

	function ctx.random(_): number
		return params.random()
	end

	function ctx.nextId(_): number
		self.nextProjectileId = self.nextProjectileId % MAX_PROJECTILE_ID + 1
		return self.nextProjectileId
	end

	return ctx :: Context
end

function Arsenal.new(params: Params): Arsenal
	local self = setmetatable({
		params = params,
		owners = {},
		order = {},
		effects = {},
		nextProjectileId = 0,
		context = nil :: any,
	}, Arsenal)
	self.context = makeContext(self)
	return self
end

-- Owners -------------------------------------------------------------------------------

-- Adds an owner without weapons. Adding an existing owner only replaces their bonuses.
function Arsenal.addOwner(self: Arsenal, ownerId: number, bonuses: Bonuses?)
	if self.owners[ownerId] then
		self:setBonuses(ownerId, bonuses or {})
		return
	end
	self.owners[ownerId] = { weapons = {}, bonuses = bonuses or {}, placed = false, x = 0, z = 0, vx = 0, vz = 0 }
	table.insert(self.order, ownerId)
end

function Arsenal.removeOwner(self: Arsenal, ownerId: number)
	self.owners[ownerId] = nil
	local index = table.find(self.order, ownerId)
	if index then
		table.remove(self.order, index)
	end
end

function Arsenal.hasOwner(self: Arsenal, ownerId: number): boolean
	return self.owners[ownerId] ~= nil
end

-- Removes every owner and weapon (run start).
function Arsenal.clear(self: Arsenal)
	table.clear(self.owners)
	table.clear(self.order)
	self.effects = {}
end

local function recompute(self: Arsenal, weapon: Weapon, owner: Owner)
	local evolution = if weapon.evolution then Evolutions[weapon.evolution] else nil
	weapon.stats = WeaponStats.compute(weapon.config, weapon.level, owner.bonuses, evolution, self.params.minCooldown)
end

-- Replaces the owner's stats (StatService) and recomputes every weapon.
function Arsenal.setBonuses(self: Arsenal, ownerId: number, bonuses: Bonuses)
	local owner = self.owners[ownerId]
	if not owner then
		return
	end
	owner.bonuses = bonuses
	for _, weapon in owner.weapons do
		recompute(self, weapon, owner)
	end
end

-- Where the owner is this step (floor x/z and velocity). Owners not placed before a step count as down.
function Arsenal.place(self: Arsenal, ownerId: number, x: number, z: number, vx: number, vz: number)
	local owner = self.owners[ownerId]
	if owner then
		owner.placed = true
		owner.x, owner.z, owner.vx, owner.vz = x, z, vx, vz
	end
end

-- Weapons --------------------------------------------------------------------------------

-- True if the weapon exists in Config.Weapons and has a behavior module.
function Arsenal.isImplemented(self: Arsenal, weaponId: string): boolean
	local config = Weapons[weaponId]
	return config ~= nil and self.params.behaviors[config.behavior] ~= nil
end

-- Ids of every weapon players can get right now, sorted by id.
function Arsenal.getImplemented(self: Arsenal): { string }
	local ids = {}
	for id in Weapons do
		if self:isImplemented(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

local function findWeapon(owner: Owner, weaponId: string): (Weapon?, number?)
	for index, weapon in owner.weapons do
		if weapon.id == weaponId then
			return weapon, index
		end
	end
	return nil, nil
end

-- Gives the owner a weapon at level 1; it fires as soon as it has a target. Reasons for false: "NotParticipant",
-- "UnknownWeapon", "NotImplemented", "AlreadyOwned", "SlotsFull".
function Arsenal.addWeapon(self: Arsenal, ownerId: number, weaponId: string, now: number): (boolean, string?)
	local owner = self.owners[ownerId]
	if not owner then
		return false, "NotParticipant"
	end
	local config = Weapons[weaponId]
	if not config then
		return false, "UnknownWeapon"
	end
	local behavior = self.params.behaviors[config.behavior]
	if not behavior then
		return false, "NotImplemented"
	end
	if findWeapon(owner, weaponId) then
		return false, "AlreadyOwned"
	end
	if #owner.weapons >= self.params.maxWeapons then
		return false, "SlotsFull"
	end
	local weapon: Weapon = {
		id = weaponId,
		config = config,
		behaviorName = config.behavior,
		behavior = behavior,
		ownerId = ownerId,
		level = 1,
		evolution = nil,
		stats = {},
		addedAt = now,
		cooldownLeft = 0,
		state = {},
		damageDealt = 0,
		kills = 0,
	}
	recompute(self, weapon, owner)
	table.insert(owner.weapons, weapon)
	return true, nil
end

function Arsenal.removeWeapon(self: Arsenal, ownerId: number, weaponId: string): boolean
	local owner = self.owners[ownerId]
	if not owner then
		return false
	end
	local _, index = findWeapon(owner, weaponId)
	if not index then
		return false
	end
	table.remove(owner.weapons, index)
	return true
end

-- One level up. Reasons for false: "NotParticipant", "NotOwned", "MaxLevel".
function Arsenal.levelUp(self: Arsenal, ownerId: number, weaponId: string): (boolean, string?)
	local owner = self.owners[ownerId]
	if not owner then
		return false, "NotParticipant"
	end
	local weapon = findWeapon(owner, weaponId)
	if not weapon then
		return false, "NotOwned"
	end
	if weapon.level >= self.params.maxLevel then
		return false, "MaxLevel"
	end
	weapon.level += 1
	recompute(self, weapon, owner)
	return true, nil
end

-- Turns a max-level weapon into its evolution (Config.Evolutions). The item it needs is checked by the caller,
-- which knows the items (chests, WP9). Reasons for false: "NotParticipant", "NotOwned", "WrongEvolution",
-- "NotMaxLevel", "AlreadyEvolved", "NotImplemented".
function Arsenal.evolve(self: Arsenal, ownerId: number, weaponId: string, evolutionId: string): (boolean, string?)
	local owner = self.owners[ownerId]
	if not owner then
		return false, "NotParticipant"
	end
	local weapon = findWeapon(owner, weaponId)
	if not weapon then
		return false, "NotOwned"
	end
	local evolution = Evolutions[evolutionId]
	if not (evolution and evolution.weapon == weaponId) then
		return false, "WrongEvolution"
	end
	if weapon.level < self.params.maxLevel then
		return false, "NotMaxLevel"
	end
	if weapon.evolution then
		return false, "AlreadyEvolved"
	end
	local behavior = self.params.behaviors[evolution.behavior]
	if not behavior then
		return false, "NotImplemented"
	end
	if evolution.behavior ~= weapon.behaviorName then
		weapon.state = {} -- a different behavior starts with its own data
	end
	weapon.evolution = evolutionId
	weapon.behaviorName = evolution.behavior
	weapon.behavior = behavior
	recompute(self, weapon, owner)
	return true, nil
end

-- The owner's weapons in slot order (live; do not change them).
function Arsenal.getWeapons(self: Arsenal, ownerId: number): { Weapon }
	local owner = self.owners[ownerId]
	return if owner then owner.weapons else {}
end

-- Damage dealt and kills per weapon the owner still has (for the results screen, WP14).
function Arsenal.getDamageStats(self: Arsenal, ownerId: number): DamageStats
	local result: DamageStats = {}
	for _, weapon in self:getWeapons(ownerId) do
		result[weapon.id] = { damage = weapon.damageDealt, kills = weapon.kills }
	end
	return result
end

-- Step ---------------------------------------------------------------------------------------

-- Runs every weapon once. `now` is the server time (spinning weapons follow it); dt the simulation step.
function Arsenal.step(self: Arsenal, dt: number, now: number)
	local ctx = self.context
	ctx.now = now
	for _, ownerId in self.order do
		local owner = self.owners[ownerId]
		local active = owner.placed
		ctx.active = active
		ctx.x, ctx.z, ctx.vx, ctx.vz = owner.x, owner.z, owner.vx, owner.vz
		for _, weapon in owner.weapons do
			local behavior = weapon.behavior
			if behavior.step then
				behavior.step(weapon, ctx, dt)
			end
			local cooldown = weapon.stats.cooldown
			if active and cooldown and behavior.fire then
				weapon.cooldownLeft -= dt
				if weapon.cooldownLeft <= 0 and behavior.fire(weapon, ctx) then
					-- keep the part of a step it was late, but never bank shots while waiting for a target
					weapon.cooldownLeft = math.max(weapon.cooldownLeft, -dt) + cooldown
				end
			end
		end
		owner.placed = false
	end
end

-- Effects emitted since the last call, in order. The arsenal starts a new list.
function Arsenal.drainEffects(self: Arsenal): { Effect }
	local effects = self.effects
	if #effects > 0 then
		self.effects = {}
	end
	return effects
end

return Arsenal
