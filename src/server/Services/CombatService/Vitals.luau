--!strict
-- Pure HP, armor, hit protection and dash cooldown rules for one player (DESIGN.md section 4).
-- No Roblox objects, so it is unit tested. Used by CombatService, which passes server times as `now`.

export type Settings = {
	armor: number, -- flat reduction per hit
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
		invulnerableUntil: number, -- dash, hit protection, later level-up choice
		dashReadyAt: number,
	},
	Vitals
))

function Vitals.new(maxHp: number, settings: Settings): Vitals
	return setmetatable({
		settings = settings,
		hp = maxHp,
		maxHp = maxHp,
		invulnerableUntil = 0,
		dashReadyAt = 0,
	}, Vitals)
end

-- Full HP with a new maximum, no protection, dash ready (run start, back in the lobby).
function Vitals.reset(self: Vitals, maxHp: number)
	self.maxHp = maxHp
	self.hp = maxHp
	self.invulnerableUntil = 0
	self.dashReadyAt = 0
end

function Vitals.isDown(self: Vitals): boolean
	return self.hp <= 0
end

function Vitals.isInvulnerable(self: Vitals, now: number): boolean
	return now < self.invulnerableUntil
end

function Vitals.protect(self: Vitals, now: number, seconds: number)
	self.invulnerableUntil = math.max(self.invulnerableUntil, now + seconds)
end

-- Applies one hit. Returns the HP actually lost (0 while protected or already down).
function Vitals.hit(self: Vitals, damage: number, now: number): number
	if damage <= 0 or self:isDown() or self:isInvulnerable(now) then
		return 0
	end
	local settings = self.settings
	local taken = math.max(settings.minDamagePerHit, damage - settings.armor)
	taken = math.min(taken, self.hp)
	self.hp -= taken
	self:protect(now, settings.hitInvulnerability)
	return taken
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
