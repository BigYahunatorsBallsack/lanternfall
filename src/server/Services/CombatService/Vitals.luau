--!strict
-- Pure HP, armor, dodge, hit protection and dash cooldown rules for one player (DESIGN.md section 4).
-- No Roblox objects, so it is unit tested. Used by CombatService, which passes server times as `now`, the defense
-- from the player's stats (Util/StatMath: armor factor and dodge chance) and a random roll per hit.

export type Settings = {
	minDamagePerHit: number,
	hitInvulnerability: number, -- seconds of protection after a hit
	dashCooldown: number,
	dashInvulnerability: number,
	dashCooldownTolerance: number, -- the server accepts a dash this many seconds early (ping)
}

local Vitals = {}
Vitals.__index = Vitals

export type Vitals = typeof(setmetatable(
	{} :: {
		settings: Settings,
		hp: number,
		maxHp: number,
		damageFactor: number, -- share of a hit's damage taken (Armor stat)
		dodgeChance: number, -- 0..1 (Dodge stat)
		invulnerableUntil: number, -- dash and hit protection
		shielded: boolean, -- invulnerable until switched off (level-up choice)
		hitShields: number, -- hits nullified completely (item effects, since B4)
		dashReadyAt: number,
	},
	Vitals
))

function Vitals.new(maxHp: number, settings: Settings): Vitals
	return setmetatable({
		settings = settings,
		hp = maxHp,
		maxHp = maxHp,
		damageFactor = 1,
		dodgeChance = 0,
		invulnerableUntil = 0,
		shielded = false,
		hitShields = 0,
		dashReadyAt = 0,
	}, Vitals)
end

-- Full HP with a new maximum, no protection, dash ready (run start, back in the lobby). Defense stays as set.
function Vitals.reset(self: Vitals, maxHp: number)
	self.maxHp = maxHp
	self.hp = maxHp
	self.invulnerableUntil = 0
	self.shielded = false
	self.hitShields = 0
	self.dashReadyAt = 0
end

-- A new maximum during the run (Max HP stat): a higher maximum adds the difference to the current HP,
-- a lower one only caps it. A player who is down stays at 0.
function Vitals.setMaxHp(self: Vitals, maxHp: number)
	if not self:isDown() then
		self.hp = math.clamp(self.hp + math.max(0, maxHp - self.maxHp), 1, maxHp)
	end
	self.maxHp = maxHp
end

-- Defense from the stats: the share of damage taken (StatMath.armorFactor) and the dodge chance (0..1).
function Vitals.setDefense(self: Vitals, damageFactor: number, dodgeChance: number)
	self.damageFactor = damageFactor
	self.dodgeChance = dodgeChance
end

function Vitals.isDown(self: Vitals): boolean
	return self.hp <= 0
end

function Vitals.isInvulnerable(self: Vitals, now: number): boolean
	return self.shielded or now < self.invulnerableUntil
end

function Vitals.protect(self: Vitals, now: number, seconds: number)
	self.invulnerableUntil = math.max(self.invulnerableUntil, now + seconds)
end

-- Switches the open-ended protection on or off; switching it off leaves `afterSeconds` of protection.
function Vitals.setShielded(self: Vitals, shielded: boolean, now: number, afterSeconds: number)
	if self.shielded and not shielded then
		self:protect(now, afterSeconds)
	end
	self.shielded = shielded
end

-- Sets how many hits are nullified from now on (Brotato's Tardigrade: one per wave and copy).
function Vitals.setHitShields(self: Vitals, count: number)
	self.hitShields = math.max(0, count)
end

-- Applies one hit; `roll` (0 <= roll < 1) below the dodge chance dodges it (no damage, no protection afterwards),
-- else a hit shield takes it (no damage, no protection afterwards). Returns the HP actually lost (0 while protected,
-- already down, dodged or blocked), whether it was dodged and whether a hit shield blocked it.
function Vitals.hit(self: Vitals, damage: number, now: number, roll: number?): (number, boolean, boolean)
	if damage <= 0 or self:isDown() or self:isInvulnerable(now) then
		return 0, false, false
	end
	if (roll or 1) < self.dodgeChance then
		return 0, true, false
	end
	if self.hitShields > 0 then
		self.hitShields -= 1
		return 0, false, true
	end
	local settings = self.settings
	local taken = math.max(settings.minDamagePerHit, math.round(damage * self.damageFactor)) -- whole HP like Brotato
	taken = math.min(taken, self.hp)
	self.hp -= taken
	self:protect(now, settings.hitInvulnerability)
	return taken, false, false
end

-- Heals up to the maximum. Returns the HP actually gained (0 while down: only a revive helps then).
function Vitals.heal(self: Vitals, amount: number): number
	if amount <= 0 or self:isDown() then
		return 0
	end
	local gained = math.min(amount, self.maxHp - self.hp)
	self.hp += gained
	return gained
end

-- Loses up to `amount` HP straight away, ignoring armor, dodge, shields and hit protection and giving none, but never
-- below 1 HP (item effects since B8: Brotato's "you take 1 damage per second"; not lethal is an assumption). Returns
-- the HP lost.
function Vitals.drain(self: Vitals, amount: number): number
	if amount <= 0 or self:isDown() then
		return 0
	end
	local lost = math.max(0, math.min(amount, self.hp - 1))
	self.hp -= lost
	return lost
end

-- Sets HP to a fraction of the maximum, at least 1 (revive).
function Vitals.setFraction(self: Vitals, fraction: number)
	self.hp = math.clamp(math.ceil(self.maxHp * fraction), 1, self.maxHp)
end

function Vitals.knockDown(self: Vitals)
	self.hp = 0
end

-- Starts a dash if the cooldown allows it. Returns false plus a reason otherwise.
function Vitals.dash(self: Vitals, now: number): (boolean, string?)
	if self:isDown() then
		return false, "Down"
	end
	local settings = self.settings
	if now < self.dashReadyAt - settings.dashCooldownTolerance then
		return false, "Cooldown"
	end
	self.dashReadyAt = now + settings.dashCooldown
	self:protect(now, settings.dashInvulnerability)
	return true, nil
end

return Vitals
