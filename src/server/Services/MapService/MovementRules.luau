--!strict
-- Rules of the movement plausibility check (Paket 23): a distance budget per checked character that refills with the
-- walk speed CombatService set and pays for every accepted move, extra budget for dashes the server granted, the arena
-- box and the ruin pillars, and the fastest believable velocity. Pure (no Roblox calls); MapService/MovementGuard
-- keeps one Entry per character, tests/MovementRules.spec checks the rules.

export type Settings = {
	speedTolerance: number,
	burstSeconds: number,
	slackStuds: number,
	dashCredit: number,
	dashSeconds: number,
	speedGraceSeconds: number,
	arenaMargin: number,
	pillarCore: number,
}

-- The arena as the check sees it: the floor box in world x/z and the ruin pillars as circles.
export type Area = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	pillars: { { x: number, z: number, radius: number } },
}

export type Entry = {
	x: number, -- last accepted position
	y: number,
	z: number,
	budget: number, -- studs the character may still move right now
	checkedAt: number, -- time of the last refill
	speed: number, -- walk speed in studs/s (0 while it may not walk)
	oldSpeed: number, -- the walk speed before the last slowdown
	slowedAt: number, -- when that slowdown happened
	dashUntil: number, -- until then the velocity may reach the dash speed
}

export type Block = "Outside" | "Pillar"

local MovementRules = {}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- Most studs the budget refills to: burstSeconds of walking plus the slack.
function MovementRules.capacity(speed: number, settings: Settings): number
	return speed * settings.speedTolerance * settings.burstSeconds + settings.slackStuds
end

-- A fresh entry at a position the server chose (full budget).
function MovementRules.new(x: number, y: number, z: number, speed: number, now: number, settings: Settings): Entry
	return {
		x = x,
		y = y,
		z = z,
		budget = MovementRules.capacity(speed, settings),
		checkedAt = now,
		speed = speed,
		oldSpeed = speed,
		slowedAt = -math.huge,
		dashUntil = -math.huge,
	}
end

-- Moves the accepted position without a check (the server placed the character) and fills the budget.
function MovementRules.rebase(entry: Entry, x: number, y: number, z: number, now: number, settings: Settings)
	entry.x, entry.y, entry.z = x, y, z
	entry.checkedAt = now
	entry.budget = math.max(entry.budget, MovementRules.capacity(MovementRules.speedAt(entry, now, settings), settings))
end

-- The walk speed that counts at `now`: a slowdown counts only after speedGraceSeconds (the character still slides,
-- and the moves of the last moment arrive late).
function MovementRules.speedAt(entry: Entry, now: number, settings: Settings): number
	if now - entry.slowedAt < settings.speedGraceSeconds then
		return math.max(entry.speed, entry.oldSpeed)
	end
	return entry.speed
end

-- Adds what the walk speed earned since the last refill, up to the capacity (more only stays from a dash).
function MovementRules.refill(entry: Entry, now: number, settings: Settings)
	local dt = now - entry.checkedAt
	if dt <= 0 then
		return
	end
	entry.checkedAt = now
	local speed = MovementRules.speedAt(entry, now, settings)
	local cap = MovementRules.capacity(speed, settings)
	entry.budget = math.min(entry.budget + speed * settings.speedTolerance * dt, math.max(entry.budget, cap))
end

-- A new walk speed from CombatService. The time before it is paid with the old speed.
function MovementRules.setSpeed(entry: Entry, speed: number, now: number, settings: Settings)
	if speed == entry.speed then
		return
	end
	MovementRules.refill(entry, now, settings)
	if speed < entry.speed then
		entry.oldSpeed = MovementRules.speedAt(entry, now, settings)
		entry.slowedAt = now
	end
	entry.speed = speed
end

-- The server granted a dash of `distance` studs.
function MovementRules.addDash(entry: Entry, distance: number, now: number, settings: Settings)
	MovementRules.refill(entry, now, settings)
	entry.budget += distance * settings.dashCredit
	entry.dashUntil = now + settings.dashSeconds
end

-- Whether (x, z) is somewhere a real character can not stand: beyond the arena walls (or no real number) or inside a
-- ruin pillar.
function MovementRules.blocked(area: Area, x: number, z: number, settings: Settings): Block?
	local margin = settings.arenaMargin
	if not (finite(x) and finite(z)) then
		return "Outside"
	elseif x < area.minX - margin or x > area.maxX + margin or z < area.minZ - margin or z > area.maxZ + margin then
		return "Outside"
	end
	for _, pillar in area.pillars do
		local core = pillar.radius - settings.pillarCore
		if core > 0 then
			local dx, dz = x - pillar.x, z - pillar.z
			if dx * dx + dz * dz < core * core then
				return "Pillar"
			end
		end
	end
	return nil
end

-- Pays for the move to (x, y, z) and makes it the accepted position if it fits the budget. Returns whether it was
-- accepted and how far it went over the floor (math.huge for broken numbers).
function MovementRules.tryMove(
	entry: Entry,
	x: number,
	y: number,
	z: number,
	now: number,
	settings: Settings
): (boolean, number)
	if not (finite(x) and finite(y) and finite(z)) then
		return false, math.huge
	end
	MovementRules.refill(entry, now, settings)
	local dx, dz = x - entry.x, z - entry.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance > entry.budget then
		return false, distance
	end
	entry.budget -= distance
	entry.x, entry.y, entry.z = x, y, z
	return true, distance
end

-- Fastest believable speed over the floor right now (studs/s): the walk speed with tolerance, the dash speed while a
-- granted dash runs.
function MovementRules.maxSpeed(entry: Entry, dashSpeed: number, now: number, settings: Settings): number
	local walk = MovementRules.speedAt(entry, now, settings) * settings.speedTolerance
	if now < entry.dashUntil then
		return math.max(walk, dashSpeed * settings.speedTolerance)
	end
	return walk
end

return MovementRules
