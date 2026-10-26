--!strict
-- Draws the XP orbs (DESIGN.md section 8) from the server's XpOrbs events (ExperienceService): pooled glowing balls
-- on the floor, sized and colored by how much XP they hold, that fly into the player who picked them up. Lying orbs
-- are placed once; only flying ones move each frame, together in one workspace:BulkMoveTo. The server decides every
-- pickup; this only shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)

local FOLDER_NAME = "LanternfallXpOrbs"
local FLY_SECONDS = 0.25
local HOVER = 0.4 -- studs between the floor and the bottom of an orb
-- Looks by XP value: the last tier with minValue <= value applies.
local TIERS = {
	{ minValue = 0, size = 0.8, color = Color3.fromRGB(96, 170, 255) },
	{ minValue = 4, size = 1.1, color = Color3.fromRGB(110, 230, 140) },
	{ minValue = 20, size = 1.6, color = Color3.fromRGB(255, 120, 110) },
}

type Orb = { part: BasePart, x: number, z: number }
type Flight = { part: BasePart, from: Vector3, userId: number, startedAt: number }

local XpOrbRenderer = {}

local floorY = Config.Map.arena.center.Y
local folder: Folder? = nil
local pool = VisualKit.pool(function(): BasePart
	return VisualKit.part("XpOrb", Enum.PartType.Ball, Vector3.one, TIERS[1].color)
end)
local orbs: { [number]: Orb } = {}
local flights: { Flight } = {}

-- Reused lists for workspace:BulkMoveTo.
local partList: { BasePart } = {}
local cframeList: { CFrame } = {}

local function getFolder(): Folder
	local current = folder
	if current then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = workspace
	folder = created
	return created
end

local function tierOf(value: number)
	local chosen = TIERS[1]
	for _, tier in TIERS do
		if value >= tier.minValue then
			chosen = tier
		end
	end
	return chosen
end

local function rootPosition(userId: number): Vector3?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function clear()
	for _, orb in orbs do
		pool:release(orb.part)
	end
	for _, flight in flights do
		pool:release(flight.part)
	end
	table.clear(orbs)
	table.clear(flights)
end

local function flushMoves()
	if #partList > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(partList)
		table.clear(cframeList)
	end
end

local function onEvents(events: Types.XpOrbEvents)
	if typeof(events) ~= "table" then
		return
	end
	if events.reset then
		clear()
	end
	local list = events.orbs
	for i = 1, #list - 3, 4 do
		local id, x, z, value = list[i], list[i + 1], list[i + 2], list[i + 3]
		local orb = orbs[id]
		if not orb then
			orb = { part = pool:acquire(getFolder()), x = x, z = z }
			orbs[id] = orb
		end
		local tier = tierOf(value)
		orb.part.Size = Vector3.one * tier.size
		orb.part.Color = tier.color
		table.insert(partList, orb.part)
		table.insert(cframeList, CFrame.new(x, floorY + HOVER + tier.size / 2, z))
	end
	flushMoves()
	local now = workspace:GetServerTimeNow()
	local collected = events.collected
	for i = 1, #collected - 1, 2 do
		local id, userId = collected[i], collected[i + 1]
		local orb = orbs[id]
		if orb then
			orbs[id] = nil
			table.insert(flights, { part = orb.part, from = orb.part.Position, userId = userId, startedAt = now })
		end
	end
end

local function render()
	if #flights == 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	for i = #flights, 1, -1 do
		local flight = flights[i]
		local t = (now - flight.startedAt) / FLY_SECONDS
		local target = rootPosition(flight.userId)
		if t >= 1 or not target then
			pool:release(flight.part)
			table.remove(flights, i)
		else
			table.insert(partList, flight.part)
			table.insert(cframeList, CFrame.new(flight.from + (target - flight.from) * (t * t)))
		end
	end
	flushMoves()
end

-- Lifecycle -------------------------------------------------------------------------

function XpOrbRenderer.init()
	Net.onClient("XpOrbs", onEvents)
end

function XpOrbRenderer.start()
	RunService.RenderStepped:Connect(render)
end

-- Orbs lying on the floor and orbs flying to a player (smoke test).
function XpOrbRenderer.getCounts(): (number, number)
	local lying = 0
	for _ in orbs do
		lying += 1
	end
	return lying, #flights
end

return XpOrbRenderer
