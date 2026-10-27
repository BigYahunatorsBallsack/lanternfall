--!strict
-- Team level and XP (DESIGN.md section 9): XP for level L -> L+1 = round((L + offset)^exponent * fPlayers), Brotato's
-- (L + 3)^2 since B2.
-- Pure and unit tested (tests/Experience.spec.luau); owned by ExperienceService, which passes the current player
-- factor on every call, so the next level gets cheaper as soon as a player leaves.

export type Curve = { offset: number, exponent: number }

local Progression = {}
Progression.__index = Progression

export type Progression = typeof(setmetatable({} :: { curve: Curve, level: number, xp: number }, Progression))

-- XP needed to go from `level` to `level + 1`, at least 1.
function Progression.xpForLevel(curve: Curve, level: number, playerFactor: number): number
	return math.max(1, math.round((level + curve.offset) ^ curve.exponent * playerFactor))
end

function Progression.new(curve: Curve): Progression
	return setmetatable({ curve = curve, level = 1, xp = 0 }, Progression)
end

function Progression.reset(self: Progression)
	self.level = 1
	self.xp = 0
end

-- XP needed for the next level with the current player factor.
function Progression.needed(self: Progression, playerFactor: number): number
	return Progression.xpForLevel(self.curve, self.level, playerFactor)
end

-- Adds XP and returns how many levels were gained (0 or more).
function Progression.add(self: Progression, amount: number, playerFactor: number): number
	self.xp += math.max(0, amount)
	local gained = 0
	local needed = self:needed(playerFactor)
	while self.xp >= needed do
		self.xp -= needed
		self.level += 1
		gained += 1
		needed = self:needed(playerFactor)
	end
	return gained
end

return Progression
