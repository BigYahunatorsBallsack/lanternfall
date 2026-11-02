--!strict
-- Pooled, hand-built cartoon weapon models that hover beside each equipped player. WeaponRenderer calls this every frame;
-- hit detection and attack effects remain entirely in WeaponService and the existing Visuals modules.

local VisualKit = require(script.Parent.VisualKit)

local INK = Color3.fromRGB(25, 21, 29)
local IRON = Color3.fromRGB(99, 105, 110)
local STEEL = Color3.fromRGB(198, 207, 205)
local BONE = Color3.fromRGB(231, 220, 193)
local BRASS = Color3.fromRGB(182, 137, 69)
local DARK_BRASS = Color3.fromRGB(111, 78, 43)
local WOOD = Color3.fromRGB(101, 65, 48)
local AMBER = Color3.fromRGB(255, 195, 82)
local BLUE = Color3.fromRGB(94, 194, 230)
local GREEN = Color3.fromRGB(96, 165, 113)
local PURPLE = Color3.fromRGB(170, 124, 211)
local RED = Color3.fromRGB(215, 97, 82)

type Piece = { part: BasePart, offset: CFrame }
type Build = ({ Piece }) -> ()
type Model = { pieces: { Piece }, seen: number, id: string }

local HeldModels = {}

local function add(
	parts: { Piece },
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	at: Vector3,
	color: Color3,
	yaw: number?
)
	local part = VisualKit.solid(name, shape, size, color, Enum.Material.SmoothPlastic)
	table.insert(parts, { part = part, offset = CFrame.new(at) * CFrame.Angles(0, math.rad(yaw or 0), 0) })
end

local function box(parts: { Piece }, name: string, size: Vector3, at: Vector3, color: Color3, yaw: number?)
	add(parts, name, Enum.PartType.Block, size, at, color, yaw)
end

local function ball(parts: { Piece }, name: string, size: Vector3, at: Vector3, color: Color3)
	add(parts, name, Enum.PartType.Ball, size, at, color)
end

local function handle(parts: { Piece }, length: number, color: Color3?)
	add(
		parts,
		"HandleOutline",
		Enum.PartType.Cylinder,
		Vector3.new(length + 0.08, 0.35, 0.34),
		Vector3.new(0, 0, 0.28),
		INK,
		90
	)
	add(
		parts,
		"Handle",
		Enum.PartType.Cylinder,
		Vector3.new(length, 0.37, 0.24),
		Vector3.new(0, 0.04, 0.28),
		color or WOOD,
		90
	)
	ball(parts, "Pommel", Vector3.new(0.38, 0.38, 0.38), Vector3.new(0, 0.05, 0.28 + length / 2), BRASS)
end

local function blade(parts: { Piece }, length: number, width: number, color: Color3?)
	handle(parts, 0.68)
	box(parts, "GuardOutline", Vector3.new(width + 0.32, 0.3, 0.26), Vector3.new(0, 0.08, -0.23), INK)
	box(parts, "Guard", Vector3.new(width + 0.18, 0.32, 0.17), Vector3.new(0, 0.14, -0.23), BRASS)
	box(
		parts,
		"BladeOutline",
		Vector3.new(width + 0.12, 0.28, length + 0.13),
		Vector3.new(0, 0.04, -0.4 - length / 2),
		INK
	)
	box(parts, "Blade", Vector3.new(width, 0.29, length), Vector3.new(0, 0.13, -0.4 - length / 2), color or STEEL)
	box(parts, "Ridge", Vector3.new(0.09, 0.07, length * 0.85), Vector3.new(0, 0.31, -0.4 - length / 2), BONE)
	local tipOutline = VisualKit.wedge("TipOutline", Vector3.new(width + 0.12, 0.27, 0.38), INK)
	tipOutline.Material = Enum.Material.SmoothPlastic
	table.insert(parts, { part = tipOutline, offset = CFrame.new(0, 0.04, -0.56 - length) })
	local tip = VisualKit.wedge("Tip", Vector3.new(width, 0.28, 0.32), color or STEEL)
	tip.Material = Enum.Material.SmoothPlastic
	table.insert(parts, { part = tip, offset = CFrame.new(0, 0.13, -0.56 - length) })
end

local function gun(parts: { Piece }, length: number, width: number, color: Color3?)
	box(parts, "StockOutline", Vector3.new(width + 0.18, 0.45, length + 0.13), Vector3.new(0, 0, 0.25), INK)
	box(parts, "Stock", Vector3.new(width, 0.47, length), Vector3.new(0, 0.08, 0.25), color or WOOD)
	box(parts, "Grip", Vector3.new(width * 0.48, 0.6, 0.38), Vector3.new(0, -0.37, 0.5), INK)
	add(
		parts,
		"BarrelOutline",
		Enum.PartType.Cylinder,
		Vector3.new(length * 0.9, 0.34, width * 0.59),
		Vector3.new(0, 0.13, -0.64),
		INK,
		90
	)
	add(
		parts,
		"Barrel",
		Enum.PartType.Cylinder,
		Vector3.new(length * 0.86, 0.36, width * 0.41),
		Vector3.new(0, 0.2, -0.65),
		IRON,
		90
	)
	add(
		parts,
		"Muzzle",
		Enum.PartType.Cylinder,
		Vector3.new(0.17, 0.41, width * 0.63),
		Vector3.new(0, 0.19, -0.65 - length * 0.44),
		BRASS,
		90
	)
end

local function staff(parts: { Piece }, length: number, gem: Color3)
	handle(parts, length, DARK_BRASS)
	box(parts, "SocketOutline", Vector3.new(0.66, 0.5, 0.42), Vector3.new(0, 0.08, -0.4 - length / 2), INK)
	box(parts, "Socket", Vector3.new(0.49, 0.51, 0.31), Vector3.new(0, 0.14, -0.4 - length / 2), BRASS)
	ball(parts, "Gem", Vector3.new(0.55, 0.55, 0.55), Vector3.new(0, 0.22, -0.7 - length / 2), gem)
end

local function axe(parts: { Piece }, length: number, color: Color3)
	handle(parts, length)
	box(parts, "HeadOutline", Vector3.new(1.4, 0.35, 0.56), Vector3.new(0, 0.04, -0.4 - length / 2), INK)
	box(parts, "Head", Vector3.new(1.19, 0.37, 0.46), Vector3.new(0, 0.12, -0.4 - length / 2), color)
	box(parts, "EdgeLeft", Vector3.new(0.17, 0.4, 0.68), Vector3.new(-0.65, 0.13, -0.4 - length / 2), BONE)
	box(parts, "EdgeRight", Vector3.new(0.17, 0.4, 0.68), Vector3.new(0.65, 0.13, -0.4 - length / 2), BONE)
end

local BUILDERS: { [string]: Build } = {
	OrbitBlades = function(p)
		blade(p, 1.08, 0.35)
		ball(p, "OrbitCore", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0, 0.35, -0.28), AMBER)
	end,
	SparkBolt = function(p)
		gun(p, 1.02, 0.53, DARK_BRASS)
		ball(p, "SparkCell", Vector3.new(0.43, 0.4, 0.43), Vector3.new(0, 0.38, 0.18), BLUE)
	end,
	Shockwave = function(p)
		handle(p, 1.05)
		box(p, "HammerOutline", Vector3.new(1.42, 0.77, 0.75), Vector3.new(0, 0, -0.8), INK)
		box(p, "Hammer", Vector3.new(1.22, 0.77, 0.62), Vector3.new(0, 0.1, -0.8), BRASS)
		ball(p, "Stamp", Vector3.new(0.4, 0.18, 0.4), Vector3.new(0, 0.56, -0.8), AMBER)
	end,
	ChainLightning = function(p)
		staff(p, 1.35, BLUE)
		box(p, "ForkLeft", Vector3.new(0.16, 0.29, 0.8), Vector3.new(-0.38, 0.12, -1.23), IRON, -22)
		box(p, "ForkRight", Vector3.new(0.16, 0.29, 0.8), Vector3.new(0.38, 0.12, -1.23), IRON, 22)
	end,
	ThornTrail = function(p)
		staff(p, 1.45, GREEN)
		box(p, "ThornLeft", Vector3.new(0.23, 0.34, 0.7), Vector3.new(-0.42, 0.14, -0.63), GREEN, -35)
		box(p, "ThornRight", Vector3.new(0.23, 0.34, 0.7), Vector3.new(0.42, 0.14, -0.25), GREEN, 35)
	end,
	BoomerangAxe = function(p)
		axe(p, 1.12, IRON)
		box(p, "GoldBind", Vector3.new(0.38, 0.42, 0.33), Vector3.new(0, 0.3, -0.88), BRASS)
	end,
	BrassKnuckles = function(p)
		box(p, "FistOutline", Vector3.new(1.15, 0.55, 0.76), Vector3.new(0, 0, 0), INK)
		box(p, "Fist", Vector3.new(0.98, 0.56, 0.59), Vector3.new(0, 0.11, 0), BRASS)
		for x = -1, 1 do
			ball(p, "Knuckle", Vector3.new(0.33, 0.34, 0.3), Vector3.new(x * 0.31, 0.23, -0.38), BONE)
		end
	end,
	RitualDirk = function(p)
		blade(p, 0.86, 0.49, IRON)
		ball(p, "RitualEye", Vector3.new(0.38, 0.18, 0.38), Vector3.new(0, 0.35, -0.87), RED)
	end,
	LamplighterPike = function(p)
		staff(p, 1.76, AMBER)
		box(p, "PikeTip", Vector3.new(0.24, 0.32, 0.79), Vector3.new(0, 0.14, -1.75), STEEL)
	end,
	DuskSabre = function(p)
		blade(p, 1.61, 0.45, IRON)
		box(p, "CurvedEdge", Vector3.new(0.13, 0.23, 0.73), Vector3.new(0.3, 0.2, -1.65), PURPLE, -16)
	end,
	Gravestone = function(p)
		blade(p, 1.35, 0.96, IRON)
		box(p, "StoneMark", Vector3.new(0.16, 0.09, 0.68), Vector3.new(0, 0.37, -1.1), PURPLE)
	end,
	TithePalm = function(p)
		box(p, "PalmOutline", Vector3.new(0.98, 0.41, 0.94), Vector3.new(0, 0, -0.2), INK)
		ball(p, "Palm", Vector3.new(0.79, 0.45, 0.8), Vector3.new(0, 0.13, -0.2), BONE)
		ball(p, "Seal", Vector3.new(0.35, 0.18, 0.35), Vector3.new(0, 0.45, -0.24), PURPLE)
		for x = -1, 1 do
			box(p, "Finger", Vector3.new(0.21, 0.25, 0.55), Vector3.new(x * 0.32, 0.1, -0.77), BONE)
		end
	end,
	WraithHatchet = function(p)
		axe(p, 0.78, PURPLE)
		ball(p, "GhostGem", Vector3.new(0.38, 0.22, 0.38), Vector3.new(0, 0.32, -0.74), BONE)
	end,
	SpiritFlint = function(p)
		gun(p, 0.79, 0.49, IRON)
		ball(p, "SpiritCore", Vector3.new(0.44, 0.4, 0.44), Vector3.new(0, 0.38, -0.27), PURPLE)
	end,
	WatchmanPistol = function(p)
		gun(p, 0.83, 0.58, WOOD)
		box(p, "Sight", Vector3.new(0.17, 0.22, 0.23), Vector3.new(0, 0.42, -0.42), BONE)
	end,
	RattleRepeater = function(p)
		gun(p, 1.37, 0.66, DARK_BRASS)
		box(p, "Drum", Vector3.new(0.83, 0.58, 0.6), Vector3.new(0, 0.32, -0.17), BRASS)
		ball(p, "DrumPin", Vector3.new(0.23, 0.16, 0.23), Vector3.new(0, 0.68, -0.17), BONE)
	end,
	ScatterBell = function(p)
		gun(p, 0.92, 0.71, DARK_BRASS)
		box(p, "BellMouth", Vector3.new(1.06, 0.63, 0.55), Vector3.new(0, 0.17, -1.22), BRASS)
	end,
	ShrapnelOrgan = function(p)
		gun(p, 1.13, 0.84, IRON)
		for x = -1, 1 do
			box(p, "OrganPipe", Vector3.new(0.21, 0.32, 1.34), Vector3.new(x * 0.4, 0.42, -0.71), BRASS)
		end
	end,
	CinderBreath = function(p)
		gun(p, 1.31, 0.73, IRON)
		ball(p, "Furnace", Vector3.new(0.66, 0.48, 0.67), Vector3.new(0, 0.39, 0.16), RED)
		box(p, "Vent", Vector3.new(0.77, 0.18, 0.26), Vector3.new(0, 0.37, -1.36), BRASS)
	end,
	GalvanicFork = function(p)
		staff(p, 1.31, BLUE)
		for x = -1, 1 do
			box(p, "LongTine", Vector3.new(0.2, 0.29, 1.05), Vector3.new(x * 0.42, 0.11, -1.41), BRASS)
		end
	end,
	LeechCarbine = function(p)
		gun(p, 1.33, 0.56, WOOD)
		ball(p, "LeechVial", Vector3.new(0.34, 0.48, 0.75), Vector3.new(0, 0.46, 0), GREEN)
	end,
	CathedralEngine = function(p)
		gun(p, 1.58, 0.96, DARK_BRASS)
		box(p, "Spire", Vector3.new(0.25, 0.37, 1.26), Vector3.new(0, 0.53, -0.36), BONE)
		ball(p, "RoseWindow", Vector3.new(0.43, 0.2, 0.43), Vector3.new(0, 0.75, 0.29), AMBER)
	end,
	MortarLantern = function(p)
		gun(p, 1.07, 0.88, DARK_BRASS)
		box(p, "LanternCage", Vector3.new(0.69, 0.64, 0.7), Vector3.new(0, 0.48, -0.09), INK)
		ball(p, "LanternFire", Vector3.new(0.48, 0.43, 0.49), Vector3.new(0, 0.61, -0.09), AMBER)
	end,
	WinterNeedle = function(p)
		gun(p, 1.36, 0.43, BONE)
		box(p, "IceNeedle", Vector3.new(0.16, 0.32, 0.68), Vector3.new(0, 0.18, -1.5), BLUE)
	end,
	FoundryKey = function(p)
		handle(p, 1.25, BRASS)
		ball(p, "KeyRingOutline", Vector3.new(0.9, 0.33, 0.9), Vector3.new(0, 0, -0.94), INK)
		ball(p, "KeyRing", Vector3.new(0.67, 0.35, 0.67), Vector3.new(0, 0.12, -0.94), AMBER)
		box(p, "Tooth", Vector3.new(0.55, 0.31, 0.19), Vector3.new(0.22, 0.12, -1.46), BRASS)
	end,
	RuneAwl = function(p)
		blade(p, 0.76, 0.24, BRASS)
		ball(p, "Rune", Vector3.new(0.31, 0.17, 0.31), Vector3.new(0, 0.35, -0.59), BLUE)
	end,
}

local pools: { [string]: VisualKit.ObjectPool<{ Piece }> } = {}
local active: { [string]: Model } = {}

local function getPool(id: string): VisualKit.ObjectPool<{ Piece }>?
	local pool = pools[id]
	if pool then
		return pool
	end
	local build = BUILDERS[id]
	if not build then
		return nil
	end
	pool = VisualKit.objectPool(function(): { Piece }
		local parts = {}
		build(parts)
		return parts
	end, function(parts: { Piece }): { BasePart }
		local list = {}
		for _, piece in parts do
			table.insert(list, piece.part)
		end
		return list
	end)
	pools[id] = pool
	return pool
end

function HeldModels.has(id: string): boolean
	return BUILDERS[id] ~= nil
end

function HeldModels.renderWeapon(
	owner: VisualKit.Owner,
	weapon: { uid: number, id: string },
	slot: number,
	total: number,
	frame: VisualKit.Frame
)
	local key = `{owner.userId}:{weapon.uid}`
	local current = active[key]
	if not current then
		local pool = getPool(weapon.id)
		if not pool then
			return
		end
		current = { pieces = pool:acquire(frame.folder), seen = 0, id = weapon.id }
		active[key] = current
	end
	current.seen = frame.number

	local angle = -math.pi / 2 + 2 * math.pi * (slot - 1) / total
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local bob = math.sin(frame.now * 2.5 + slot * 1.7) * 0.13
	local position = owner.position + direction * 2.7 + Vector3.new(0, 0.95 + bob, 0)
	local facing = CFrame.lookAt(position, position + direction)
	for _, piece in current.pieces do
		frame.move(piece.part, facing * piece.offset)
	end
end

function HeldModels.finish(frame: VisualKit.Frame)
	for key, model in active do
		if model.seen ~= frame.number then
			(pools[model.id] :: VisualKit.ObjectPool<{ Piece }>):release(model.pieces)
			active[key] = nil
		end
	end
end

function HeldModels.clear()
	for key, model in active do
		(pools[model.id] :: VisualKit.ObjectPool<{ Piece }>):release(model.pieces)
		active[key] = nil
	end
end

return HeldModels
