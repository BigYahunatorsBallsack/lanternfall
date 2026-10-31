-- Unit tests for the movement plausibility rules (src/server/Services/MapService/MovementRules.luau, Paket 23): the
-- distance budget, dashes, slowdowns, lag bursts, the arena box, the ruin pillars and the believable velocity.

local MovementRules = require(game:GetService("ServerScriptService").Server.Services.MapService.MovementRules)

local SETTINGS = {
	speedTolerance = 1.25,
	burstSeconds = 2.5,
	slackStuds = 6,
	dashCredit = 1.25,
	dashSeconds = 0.6,
	speedGraceSeconds = 1,
	arenaMargin = 2,
	pillarCore = 1,
}
local SPEED = 16
local CAPACITY = SPEED * 1.25 * 2.5 + 6 -- 56 studs

local AREA = {
	minX = -100,
	maxX = 100,
	minZ = -100,
	maxZ = 100,
	pillars = { { x = 30, z = 0, radius = 4 } },
}

-- Walks from (x, 0, 0) along +x at `speed` for `seconds` in steps of `dt`; returns how many steps were refused.
local function walk(entry, speed: number, seconds: number, start: number, dt: number?): number
	local step = dt or 1 / 30
	local refused = 0
	local t = start
	local x = entry.x
	for _ = 1, math.floor(seconds / step + 0.5) do
		t += step
		x += speed * step
		local ok = MovementRules.tryMove(entry, x, 0, 0, t, SETTINGS)
		if not ok then
			refused += 1
			x = entry.x -- moved back
		end
	end
	return refused
end

describe("MovementRules", function()
	it("starts with a full budget of burstSeconds of walking plus the slack", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		expect(entry.budget).toBeNear(CAPACITY)
		expect(MovementRules.capacity(0, SETTINGS)).toBe(6)
	end)

	it("accepts walking at the walk speed for a long time", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		expect(walk(entry, SPEED, 20, 0)).toBe(0)
		expect(entry.x).toBeNear(SPEED * 20, 0.01)
	end)

	it("accepts a little more than the walk speed (tolerance), but not a speed hack", function()
		local fair = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		expect(walk(fair, SPEED * 1.2, 20, 0)).toBe(0)
		local cheat = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		expect(walk(cheat, SPEED * 2, 10, 0) > 0).toBe(true)
		-- what the cheat gained over 10 s is at most the budget, not double the distance
		expect(cheat.x <= SPEED * 1.25 * 10 + CAPACITY + 1).toBe(true)
	end)

	it("refuses a teleport longer than the budget and keeps the old position", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		local ok, distance = MovementRules.tryMove(entry, 80, 3, 0, 0.1, SETTINGS)
		expect(ok).toBe(false)
		expect(distance).toBeNear(80)
		expect(entry.x).toBe(0)
	end)

	it("lets moves that arrive late in one burst through (lag spike)", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		walk(entry, SPEED, 5, 0) -- the budget is back to full after walking on at the walk speed
		local x = entry.x
		-- nothing arrives for 2 s, then all of it at once
		local ok = MovementRules.tryMove(entry, x + SPEED * 2, 3, 0, 7, SETTINGS)
		expect(ok).toBe(true)
	end)

	it("pays a granted dash on top of the walk", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		MovementRules.tryMove(entry, 50, 3, 0, 0, SETTINGS) -- budget almost used up
		expect(MovementRules.tryMove(entry, 62, 3, 0, 0.15, SETTINGS)).toBe(false)
		MovementRules.addDash(entry, 12, 0.15, SETTINGS)
		expect(MovementRules.tryMove(entry, 62, 3, 0, 0.15, SETTINGS)).toBe(true)
	end)

	it("keeps the old speed for speedGraceSeconds after a slowdown, then only the slack", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		MovementRules.setSpeed(entry, 0, 0, SETTINGS)
		expect(MovementRules.speedAt(entry, 0.5, SETTINGS)).toBe(SPEED)
		expect(MovementRules.speedAt(entry, 1.5, SETTINGS)).toBe(0)
		-- standing still for a while: the budget stays, but no longer refills
		MovementRules.tryMove(entry, 50, 3, 0, 1, SETTINGS)
		local left = entry.budget
		expect(MovementRules.tryMove(entry, 50, 3, 0, 10, SETTINGS)).toBe(true)
		expect(entry.budget).toBeNear(left + SPEED * 1.25 * 0, 0.01)
	end)

	it("speeding up counts the new speed only from the change on", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		MovementRules.setSpeed(entry, 32, 0, SETTINGS)
		expect(MovementRules.capacity(32, SETTINGS)).toBe(106)
		expect(walk(entry, 32, 10, 0)).toBe(0)
	end)

	it("refuses broken numbers", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		expect(MovementRules.tryMove(entry, 0 / 0, 3, 0, 1, SETTINGS)).toBe(false)
		expect(MovementRules.tryMove(entry, 1, math.huge, 0, 1, SETTINGS)).toBe(false)
		expect(entry.x).toBe(0)
	end)

	it("knows the arena box and the ruin pillars", function()
		expect(MovementRules.blocked(AREA, 0, 0, SETTINGS)).toBe(nil)
		expect(MovementRules.blocked(AREA, 101.5, 0, SETTINGS)).toBe(nil) -- within the margin
		expect(MovementRules.blocked(AREA, 103, 0, SETTINGS)).toBe("Outside")
		expect(MovementRules.blocked(AREA, 0, -103, SETTINGS)).toBe("Outside")
		expect(MovementRules.blocked(AREA, 30, 0, SETTINGS)).toBe("Pillar")
		expect(MovementRules.blocked(AREA, 32.5, 0, SETTINGS)).toBe("Pillar")
		expect(MovementRules.blocked(AREA, 33.5, 0, SETTINGS)).toBe(nil) -- touching the pillar's side is fine
		expect(MovementRules.blocked(AREA, 0 / 0, 0, SETTINGS)).toBe("Outside")
		expect(MovementRules.blocked(AREA, 0, -math.huge, SETTINGS)).toBe("Outside")
	end)

	it("believes walk speed, and dash speed only right after a granted dash", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		expect(MovementRules.maxSpeed(entry, 80, 0, SETTINGS)).toBe(20)
		MovementRules.addDash(entry, 12, 1, SETTINGS)
		expect(MovementRules.maxSpeed(entry, 80, 1.2, SETTINGS)).toBe(100)
		expect(MovementRules.maxSpeed(entry, 80, 2, SETTINGS)).toBe(20)
	end)

	it("rebase moves the accepted spot without paying and refills the budget", function()
		local entry = MovementRules.new(0, 3, 0, SPEED, 0, SETTINGS)
		MovementRules.tryMove(entry, 50, 3, 0, 0, SETTINGS)
		MovementRules.rebase(entry, 500, 3, 500, 0, SETTINGS)
		expect(entry.x).toBe(500)
		expect(entry.budget).toBeNear(CAPACITY)
	end)
end)
