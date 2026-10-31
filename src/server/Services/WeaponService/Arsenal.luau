--!strict
--!native
-- Weapon framework core (DESIGN.md section 6) as plain data without Roblox instances, so tests/Weapons.spec.luau
-- can run it against a real enemy World. Owned by WeaponService, which places the owners before every step, sends
-- their loadouts and passes the effects on to the clients.
--
-- Owners (players, by userId) carry up to `maxWeapons` weapons, each of tier I to `maxTier` (Brotato's tiers since B3);
-- the same weapon may be carried several times, every copy has its own `uid`, and two copies of the same tier merge
-- into one of the next tier. Each step, per weapon:
--   1. behavior.step moves what the weapon already has going (blades, projectiles in flight)
--   2. once the weapon's cooldown is over and its owner is placed (alive), behavior.fire starts the next attack;
--      a fire without a target returns false and is tried again on the next step
-- Behaviors (WeaponService/Behaviors, one module per weapon, picked by Config.Weapons[id].behavior) reach the
-- world only through the Context: enemy queries, hit (damage with crits and life steal, counted per weapon), push (knockback)
-- and emit (an effect for the clients' visuals). Since B4 hits on elites take the owner's Damage vs Elites, and every
-- hit is reported to `onHit` (item effects: Hit, Crit, Kill).
-- Since B5 (Brotato's combat, Config.Combat) a hit also knocks the enemy straight away from the owner (the weapon's
-- knockback, not for explosions and bounces), slows it and may set it on fire (the weapon's slow and burn stats);
-- ctx:explode blasts around a point with the weapon's explosion stats, ctx:bounceTarget picks where a bouncing
-- projectile goes next. Burns run in WeaponService/Afflictions. Item effects queue burns and explosions of an owner
-- (queueBurn, queueExplosion); they happen at the end of the step, so a chain of explosions spreads step by step.

local Shared = game:GetService("ReplicatedStorage").Shared
local Combat = require(Shared.Config.Combat)
local Evolutions = require(Shared.Config.Evolutions)
local Weapons = require(Shared.Config.Weapons)
local StatMath = require(Shared.Util.StatMath)
local Copy = require(Shared.Util.Copy)

local Afflictions = require(script.Parent.Afflictions)
local WeaponStats = require(script.Parent.WeaponStats)

export type Bonuses = WeaponStats.Bonuses

-- How weapons reach the enemies: EnemySim in the game, a World in tests. Positions are floor x/z.
export type Enemies = {
	queryCircle: (x: number, z: number, radius: number, out: { number }) -> number,
	querySegment: (x0: number, z0: number, x1: number, z1: number, radius: number, out: { number }) -> number,
	getPosition: (id: number) -> (number?, number?),
	-- returns whether the hit killed the enemy, and the HP it took; `crit` and `burn` only tell (damage numbers)
	damage: (id: number, amount: number, ownerId: number, crit: boolean, burn: boolean) -> (boolean, number),
	push: (id: number, dx: number, dz: number) -> (),
	isAlive: (id: number) -> boolean,
	isElite: ((id: number) -> boolean)?, -- Damage vs Elites; without it no enemy counts as elite
	slow: ((id: number, factor: number, seconds: number) -> ())?, -- keeps `factor` of its speed (B5)
	setBurning: ((id: number, on: boolean) -> ())?, -- shows it burning in the snapshots (B5)
}

-- What dealt a hit (onHit): a weapon's own hit, an explosion (weapon or item effect) or a burn tick (B5).
-- Since B8 also "Strike": a direct hit of an item effect (no crit, life steal or knockback).
export type HitSource = "Weapon" | "Explosion" | "Burn" | "Strike"

-- How ctx:hit lands (B5): nil for a normal hit, "Explosion" (no life steal, no knockback) or "Bounce" (a bounced
-- projectile: no knockback).
export type HitMode = "Explosion" | "Bounce"

-- Becomes a Net/Types.WeaponEffect: the behavior sets kind and its fields, emit adds weapon, userId and at.
export type Effect = { [string]: any }

export type Weapon = {
	uid: number, -- unique within the arsenal; the shop and the client name a weapon by it
	id: string, -- key in Config.Weapons
	config: Weapons.Weapon,
	behaviorName: string,
	behavior: Behavior,
	ownerId: number,
	tier: number, -- 1..maxTier
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
	-- damages one enemy with the weapon's damage times `multiplier`, rolls crits and life steal, knocks it back, slows
	-- and burns it (B5, see HitMode); true if it died
	hit: (self: Context, weapon: Weapon, id: number, multiplier: number?, mode: HitMode?) -> boolean,
	push: (self: Context, id: number, dx: number, dz: number) -> (),
	-- blasts every enemy within the weapon's explosionRadius of (x, z) but `skipId` for its damage times
	-- explosionDamage (times `multiplier`), with the "Explosion" visual (B5)
	explode: (self: Context, weapon: Weapon, x: number, z: number, skipId: number?, multiplier: number?) -> (),
	-- a random enemy within Config.Combat.bounce.range of (x, z) not in `skip`, for a bouncing projectile (B5)
	bounceTarget: (self: Context, x: number, z: number, skip: { [number]: boolean }) -> number?,
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
	maxTier: number,
	critChance: number, -- for weapons whose stats carry no critChance (WeaponStats sets it)
	critMultiplier: number,
	minCooldown: number,
	onLifeSteal: ((ownerId: number) -> ())?, -- a hit rolled the weapon's life steal (CombatService heals)
	-- every hit that took HP (item effects): the owner, the weapon (nil for item explosions and burns), the enemy, the
	-- HP it took, crit, killed and what dealt it
	onHit: ((
		ownerId: number,
		weapon: Weapon?,
		id: number,
		dealt: number,
		crit: boolean,
		killed: boolean,
		source: HitSource
	) -> ())?,
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

-- An item effect's burn or explosion waiting for the end of the step (B5).
type Queued = {
	kind: "Burn" | "Explosion" | "Strike",
	ownerId: number,
	id: number?, -- Burn: the enemy
	x: number, -- Explosion: the center
	z: number,
	damage: number, -- base damage before the owner's stats
	scaling: { [string]: number }?,
	ticks: number, -- Burn
	size: number, -- Explosion: share of Config.Combat.explosion.baseRadius
	flat: number?, -- Strike: damage added after the owner's stats (B8)
}

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
		nextUid: number,
		context: Context,
		afflictions: Afflictions.Afflictions,
		queue: { Queued },
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

	-- B5: what a hit does to an enemy that survived it besides the damage: knockback straight away from the owner (not
	-- for explosions and bounces), the weapon's slow and its burn (with its chance).
	local function afflict(weapon: Weapon, id: number, killed: boolean, mode: HitMode?)
		local stats = weapon.stats
		if killed then
			return
		end
		local knockback = stats.knockback or 0
		if knockback > 0 and mode == nil then
			local ex, ez = enemies.getPosition(id)
			if ex and ez then
				local dx, dz = ex - ctx.x, ez - ctx.z
				local length = math.sqrt(dx * dx + dz * dz)
				if length < 1e-3 then
					local angle = params.random() * 2 * math.pi
					dx, dz, length = math.cos(angle), math.sin(angle), 1
				end
				enemies.push(id, dx / length * knockback, dz / length * knockback)
			end
		end
		local slow = stats.slow
		if slow and slow > 0 and enemies.slow then
			enemies.slow(id, 1 - slow, stats.slowSeconds or 0)
		end
		local burnDamage = stats.burnDamage
		if burnDamage and (stats.burnChance >= 1 or params.random() < stats.burnChance) then
			self.afflictions:ignite(
				id,
				Afflictions.newBurn(
					weapon.ownerId,
					weapon,
					burnDamage,
					stats.burnTicks or 0,
					stats.burnInterval,
					stats.burnSpread or 0
				)
			)
		end
	end

	function ctx.hit(_, weapon: Weapon, id: number, multiplier: number?, mode: HitMode?): boolean
		local stats = weapon.stats
		local amount = stats.damage * (multiplier or 1)
		local eliteDamage = stats.eliteDamage or 0
		if eliteDamage ~= 0 and enemies.isElite and enemies.isElite(id) then
			amount *= math.max(0, 1 + eliteDamage)
		end
		local crit = params.random() < (stats.critChance or params.critChance)
		if crit then
			amount *= stats.critDamage or params.critMultiplier
		end
		local killed, dealt = enemies.damage(id, amount, weapon.ownerId, crit, false)
		local lifeSteal = stats.lifeSteal or 0
		if
			dealt > 0
			and lifeSteal > 0
			and mode ~= "Explosion"
			and params.onLifeSteal
			and params.random() < lifeSteal
		then
			params.onLifeSteal(weapon.ownerId)
		end
		weapon.damageDealt += dealt
		if killed then
			weapon.kills += 1
		end
		if dealt > 0 then
			afflict(weapon, id, killed, mode)
		end
		if params.onHit and dealt > 0 then
			params.onHit(
				weapon.ownerId,
				weapon,
				id,
				dealt,
				crit,
				killed,
				if mode == "Explosion" then "Explosion" else "Weapon"
			)
		end
		return killed
	end

	function ctx.push(_, id: number, dx: number, dz: number)
		enemies.push(id, dx, dz)
	end

	local blasted: { number } = {}
	function ctx.explode(_, weapon: Weapon, x: number, z: number, skipId: number?, multiplier: number?)
		local radius = weapon.stats.explosionRadius or Combat.explosion.baseRadius
		self:emitShared(weapon.ownerId, { kind = "Blast", x = x, z = z, radius = radius })
		local share = (weapon.stats.explosionDamage or 1) * (multiplier or 1)
		local count = enemies.queryCircle(x, z, radius, blasted)
		for i = 1, count do
			local id = blasted[i]
			if id ~= skipId then
				ctx:hit(weapon, id, share, "Explosion")
			end
		end
	end

	local bounceFound: { number } = {}
	local bounceChoices: { number } = {}
	function ctx.bounceTarget(_, x: number, z: number, skip: { [number]: boolean }): number?
		local count = enemies.queryCircle(x, z, Combat.bounce.range, bounceFound)
		local choices = 0
		for i = 1, count do
			local id = bounceFound[i]
			if not skip[id] then
				choices += 1
				bounceChoices[choices] = id
			end
		end
		if choices == 0 then
			return nil
		end
		return bounceChoices[math.min(choices, math.floor(params.random() * choices) + 1)]
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

-- Burns tick through these (B5): no crit, no life steal, the damage counts for the weapon that lit the burn.
local function makeAfflictions(self: Arsenal): Afflictions.Afflictions
	local params = self.params
	local enemies = params.enemies
	return Afflictions.new({
		isAlive = enemies.isAlive,
		position = enemies.getPosition,
		queryCircle = enemies.queryCircle,
		tick = function(burn: Afflictions.Burn, id: number)
			local killed, dealt = enemies.damage(id, burn.damage, burn.ownerId, false, true)
			local weapon = burn.weapon :: Weapon?
			if weapon then
				weapon.damageDealt += dealt
				if killed then
					weapon.kills += 1
				end
			end
			if params.onHit and dealt > 0 then
				params.onHit(burn.ownerId, weapon, id, dealt, false, killed, "Burn")
			end
		end,
		setBurning = function(id: number, on: boolean)
			if enemies.setBurning then
				enemies.setBurning(id, on)
			end
		end,
	}, Combat.burn.spreadRadius)
end

function Arsenal.new(params: Params): Arsenal
	local self = setmetatable({
		params = params,
		owners = {},
		order = {},
		effects = {},
		nextProjectileId = 0,
		nextUid = 0,
		context = nil :: any,
		afflictions = nil :: any,
		queue = {},
	}, Arsenal)
	self.context = makeContext(self)
	self.afflictions = makeAfflictions(self)
	return self
end

-- Adds an effect for the clients' visuals that belongs to no weapon (B5: "Explosion" blasts).
function Arsenal.emitShared(self: Arsenal, ownerId: number, effect: Effect, visual: string?)
	effect.weapon = visual or "Explosion"
	effect.userId = ownerId
	effect.at = self.context.now
	table.insert(self.effects, effect)
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
	self:clearCombat()
end

-- Puts out every burn and drops queued item effects (B5; the enemies are gone, e.g. at a wave end).
function Arsenal.clearCombat(self: Arsenal)
	self.afflictions:clear()
	table.clear(self.queue)
end

local function recompute(self: Arsenal, weapon: Weapon, owner: Owner)
	local evolution = if weapon.evolution then Evolutions[weapon.evolution] else nil
	weapon.stats = WeaponStats.compute(weapon.config, weapon.tier, owner.bonuses, evolution, self.params.minCooldown)
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

local function findWeapon(owner: Owner, uid: number): (Weapon?, number?)
	for index, weapon in owner.weapons do
		if weapon.uid == uid then
			return weapon, index
		end
	end
	return nil, nil
end

-- Gives the owner a weapon of `tier` (default I); it fires as soon as it has a target. Returns its uid. Reasons for
-- false: "NotParticipant", "UnknownWeapon", "NotImplemented", "BadTier", "SlotsFull".
function Arsenal.addWeapon(
	self: Arsenal,
	ownerId: number,
	weaponId: string,
	now: number,
	tier: number?
): (boolean, string?, number?)
	local owner = self.owners[ownerId]
	if not owner then
		return false, "NotParticipant", nil
	end
	local config = Weapons[weaponId]
	if not config then
		return false, "UnknownWeapon", nil
	end
	local behavior = self.params.behaviors[config.behavior]
	if not behavior then
		return false, "NotImplemented", nil
	end
	local startTier = tier or 1
	if startTier < 1 or startTier > self.params.maxTier or startTier % 1 ~= 0 then
		return false, "BadTier", nil
	end
	if #owner.weapons >= self.params.maxWeapons then
		return false, "SlotsFull", nil
	end
	self.nextUid += 1
	local weapon: Weapon = {
		uid = self.nextUid,
		id = weaponId,
		config = config,
		behaviorName = config.behavior,
		behavior = behavior,
		ownerId = ownerId,
		tier = startTier,
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
	return true, nil, weapon.uid
end

function Arsenal.removeWeapon(self: Arsenal, ownerId: number, uid: number): boolean
	local owner = self.owners[ownerId]
	if not owner then
		return false
	end
	local _, index = findWeapon(owner, uid)
	if not index then
		return false
	end
	table.remove(owner.weapons, index)
	return true
end

-- The weapon with this uid, if the owner carries it (live; do not change it).
function Arsenal.getWeapon(self: Arsenal, ownerId: number, uid: number): Weapon?
	local owner = self.owners[ownerId]
	return if owner then (findWeapon(owner, uid)) else nil
end

-- One tier up (admin). Reasons for false: "NotParticipant", "NotOwned", "MaxTier".
function Arsenal.raiseTier(self: Arsenal, ownerId: number, uid: number): (boolean, string?)
	local owner = self.owners[ownerId]
	if not owner then
		return false, "NotParticipant"
	end
	local weapon = findWeapon(owner, uid)
	if not weapon then
		return false, "NotOwned"
	end
	if weapon.tier >= self.params.maxTier then
		return false, "MaxTier"
	end
	weapon.tier += 1
	recompute(self, weapon, owner)
	return true, nil
end

-- Another copy of the weapon `uid` the two can merge with: same weapon, same tier below the max, neither evolved.
-- The first one in slot order, or nil.
function Arsenal.findMergePartner(self: Arsenal, ownerId: number, uid: number): Weapon?
	local owner = self.owners[ownerId]
	local weapon = owner and findWeapon(owner, uid)
	if not (owner and weapon) or weapon.evolution or weapon.tier >= self.params.maxTier then
		return nil
	end
	for _, other in owner.weapons do
		if other ~= weapon and other.id == weapon.id and other.tier == weapon.tier and not other.evolution then
			return other
		end
	end
	return nil
end

-- Merges the weapon `uid` with its partner (findMergePartner): it goes one tier up, the partner is gone and its damage
-- and kills count for it. Reasons for false: "NotParticipant", "NotOwned", "NoPartner".
function Arsenal.merge(self: Arsenal, ownerId: number, uid: number): (boolean, string?)
	local owner = self.owners[ownerId]
	if not owner then
		return false, "NotParticipant"
	end
	local weapon = findWeapon(owner, uid)
	if not weapon then
		return false, "NotOwned"
	end
	local partner = self:findMergePartner(ownerId, uid)
	if not partner then
		return false, "NoPartner"
	end
	self:removeWeapon(ownerId, partner.uid)
	weapon.damageDealt += partner.damageDealt
	weapon.kills += partner.kills
	weapon.tier += 1
	recompute(self, weapon, owner)
	return true, nil
end

-- Turns a max-tier weapon into its evolution (Config.Evolutions). The item it needs is checked by the caller,
-- which knows the items (chests, WP9). Reasons for false: "NotParticipant", "NotOwned", "WrongEvolution",
-- "NotMaxTier", "AlreadyEvolved", "NotImplemented".
function Arsenal.evolve(self: Arsenal, ownerId: number, uid: number, evolutionId: string): (boolean, string?)
	local owner = self.owners[ownerId]
	if not owner then
		return false, "NotParticipant"
	end
	local weapon = findWeapon(owner, uid)
	if not weapon then
		return false, "NotOwned"
	end
	local evolution = Evolutions[evolutionId]
	if not (evolution and evolution.weapon == weapon.id) then
		return false, "WrongEvolution"
	end
	if weapon.tier < self.params.maxTier then
		return false, "NotMaxTier"
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

-- B11 part 2 ("Retry wave"): a copy of the owner's weapons (slot order, tiers, evolutions, damage and kills so far
-- and the behaviors' own data) that restoreWeapons puts back.
export type SavedWeapon = {
	uid: number,
	id: string,
	tier: number,
	evolution: string?,
	addedAt: number,
	state: { [string]: any },
	damageDealt: number,
	kills: number,
}

function Arsenal.saveWeapons(self: Arsenal, ownerId: number): { SavedWeapon }
	local saved = {}
	for _, weapon in self:getWeapons(ownerId) do
		table.insert(saved, {
			uid = weapon.uid,
			id = weapon.id,
			tier = weapon.tier,
			evolution = weapon.evolution,
			addedAt = weapon.addedAt,
			state = Copy.deep(weapon.state),
			damageDealt = weapon.damageDealt,
			kills = weapon.kills,
		})
	end
	return saved
end

-- Replaces the owner's weapons with saved ones (cooldowns start ready). False if the owner is unknown.
function Arsenal.restoreWeapons(self: Arsenal, ownerId: number, saved: { SavedWeapon }): boolean
	local owner = self.owners[ownerId]
	if not owner then
		return false
	end
	local weapons: { Weapon } = {}
	for _, entry in saved do
		local config = Weapons[entry.id]
		local behavior = config and self.params.behaviors[config.behavior]
		if config and behavior then
			local weapon: Weapon = {
				uid = entry.uid,
				id = entry.id,
				config = config,
				behaviorName = config.behavior,
				behavior = behavior,
				ownerId = ownerId,
				tier = entry.tier,
				evolution = entry.evolution,
				stats = {},
				addedAt = entry.addedAt,
				cooldownLeft = 0,
				state = Copy.deep(entry.state),
				damageDealt = entry.damageDealt,
				kills = entry.kills,
			}
			recompute(self, weapon, owner)
			table.insert(weapons, weapon)
		end
	end
	owner.weapons = weapons
	return true
end

-- The owner's weapons in slot order (live; do not change them).
function Arsenal.getWeapons(self: Arsenal, ownerId: number): { Weapon }
	local owner = self.owners[ownerId]
	return if owner then owner.weapons else {}
end

-- Damage dealt and kills per weapon id the owner still has, copies added up (for the results screen, WP14).
function Arsenal.getDamageStats(self: Arsenal, ownerId: number): DamageStats
	local result: DamageStats = {}
	for _, weapon in self:getWeapons(ownerId) do
		local entry = result[weapon.id]
		if entry then
			entry.damage += weapon.damageDealt
			entry.kills += weapon.kills
		else
			result[weapon.id] = { damage = weapon.damageDealt, kills = weapon.kills }
		end
	end
	return result
end

-- Item effects (B5) --------------------------------------------------------------------------

-- Sets enemy `id` on fire for the owner at the end of this step: `ticks` ticks of (damage + sum of scaling * stat)
-- times Damage %, with the owner's Burning Speed and Spread (Brotato's burning items). Owners not in the arsenal do
-- nothing.
function Arsenal.queueBurn(
	self: Arsenal,
	ownerId: number,
	id: number,
	damage: number,
	scaling: { [string]: number }?,
	ticks: number
)
	if self.owners[ownerId] then
		table.insert(self.queue, {
			kind = "Burn",
			ownerId = ownerId,
			id = id,
			x = 0,
			z = 0,
			damage = damage,
			scaling = scaling,
			ticks = ticks,
			size = 0,
		})
	end
end

-- Blasts around (x, z) for the owner at the end of this step: (damage + sum of scaling * stat) times Damage % and
-- Explosion Damage, radius `size` times Config.Combat.explosion.baseRadius times Explosion Size; crits like a weapon
-- without its own crit values (Brotato's exploding items).
function Arsenal.queueExplosion(
	self: Arsenal,
	ownerId: number,
	x: number,
	z: number,
	damage: number,
	scaling: { [string]: number }?,
	size: number
)
	if self.owners[ownerId] then
		table.insert(self.queue, {
			kind = "Explosion",
			ownerId = ownerId,
			id = nil,
			x = x,
			z = z,
			damage = damage,
			scaling = scaling,
			ticks = 0,
			size = size,
		})
	end
end

local itemBlasted: { number } = {}

local function itemExplosion(self: Arsenal, entry: Queued, bonuses: Bonuses)
	local params = self.params
	local enemies = params.enemies
	local radius = Combat.explosion.baseRadius * entry.size * math.max(0, 1 + (bonuses.explosionSize or 0) / 100)
	local amount = WeaponStats.ownerDamage(entry.damage, entry.scaling, bonuses)
		* math.max(0, 1 + (bonuses.explosionDamage or 0) / 100)
	local critChance = StatMath.critChance(params.critChance, bonuses.critChance or 0)
	local eliteDamage = (bonuses.eliteDamage or 0) / 100
	self:emitShared(entry.ownerId, { kind = "Blast", x = entry.x, z = entry.z, radius = radius })
	local count = enemies.queryCircle(entry.x, entry.z, radius, itemBlasted)
	for i = 1, count do
		local id = itemBlasted[i]
		local hit = amount
		if eliteDamage ~= 0 and enemies.isElite and enemies.isElite(id) then
			hit *= math.max(0, 1 + eliteDamage)
		end
		local crit = params.random() < critChance
		if crit then
			hit *= params.critMultiplier
		end
		local killed, dealt = enemies.damage(id, hit, entry.ownerId, crit, false)
		if params.onHit and dealt > 0 then
			params.onHit(entry.ownerId, nil, id, dealt, crit, killed, "Explosion")
		end
	end
end

-- Item effects (B8) --------------------------------------------------------------------------

-- Hits enemy `id` for the owner at the end of this step: (damage + sum of scaling * stat) times Damage %, plus `flat`
-- (e.g. a share of the enemy's HP) untouched by stats; Damage vs Elites applies to both. No crit, life steal or
-- knockback (Brotato's Cyberball, Baby Elephant, Giant Belt; assumption). Owners not in the arsenal do nothing.
function Arsenal.queueStrike(
	self: Arsenal,
	ownerId: number,
	id: number,
	damage: number,
	scaling: { [string]: number }?,
	flat: number
)
	if self.owners[ownerId] then
		table.insert(self.queue, {
			kind = "Strike",
			ownerId = ownerId,
			id = id,
			x = 0,
			z = 0,
			damage = damage,
			scaling = scaling,
			ticks = 0,
			size = 0,
			flat = flat,
		})
	end
end

local function itemStrike(self: Arsenal, entry: Queued, bonuses: Bonuses)
	local enemies = self.params.enemies
	local id = entry.id :: number
	if not enemies.isAlive(id) then
		return
	end
	local hit = entry.flat or 0
	if entry.damage > 0 or entry.scaling then
		hit += WeaponStats.ownerDamage(entry.damage, entry.scaling, bonuses)
	end
	local eliteDamage = (bonuses.eliteDamage or 0) / 100
	if eliteDamage ~= 0 and enemies.isElite and enemies.isElite(id) then
		hit *= math.max(0, 1 + eliteDamage)
	end
	if hit <= 0 then
		return
	end
	local killed, dealt = enemies.damage(id, hit, entry.ownerId, false, false)
	if self.params.onHit and dealt > 0 then
		self.params.onHit(entry.ownerId, nil, id, dealt, false, killed, "Strike")
	end
end

-- Carries out what item effects queued; what those hits queue in turn waits for the next step.
local function runQueue(self: Arsenal)
	local queue = self.queue
	if #queue == 0 then
		return
	end
	self.queue = {}
	for _, entry in queue do
		local owner = self.owners[entry.ownerId]
		if not owner then
			continue
		end
		local bonuses = owner.bonuses
		if entry.kind == "Burn" then
			local id = entry.id :: number
			self.afflictions:ignite(
				id,
				Afflictions.newBurn(
					entry.ownerId,
					nil,
					WeaponStats.ownerDamage(entry.damage, entry.scaling, bonuses),
					entry.ticks,
					StatMath.burnInterval(bonuses.burnSpeed or 0),
					math.max(0, math.floor(bonuses.burnSpread or 0))
				)
			)
		elseif entry.kind == "Strike" then
			itemStrike(self, entry, bonuses)
		else
			itemExplosion(self, entry, bonuses)
		end
	end
end

-- Whether the enemy burns right now.
function Arsenal.isBurning(self: Arsenal, id: number): boolean
	return self.afflictions:isBurning(id)
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
	runQueue(self)
	self.afflictions:step(dt)
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
