--!strict
-- Draws the weapons (DESIGN.md section 6): one visual module per weapon behavior in WeaponRenderer/Visuals, fed with
-- the loadouts (LoadoutController) for weapons that follow their owner and with the server's WeaponEffects for
-- projectiles and blasts. Parts are pooled and moved with one workspace:BulkMoveTo per frame. Active only while the
-- local player is in a running run (RunStateController). The server decides every hit; this only shows them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local LoadoutController = require(script.Parent.LoadoutController)
local RunStateController = require(script.Parent.RunStateController)
local VisualKit = require(script.VisualKit)

local FOLDER_NAME = "LanternfallWeapons"

local WeaponRenderer = {}

local visuals: { [string]: VisualKit.Visual } = {}
for _, child in script.Visuals:GetChildren() do
	if child:IsA("ModuleScript") then
		visuals[child.Name] = require(child) :: any
	end
end

local enabled = false
local folder: Folder? = nil

-- Reused lists for workspace:BulkMoveTo.
local partList: { BasePart } = {}
local cframeList: { CFrame } = {}
local listLength = 0

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

local function rootPosition(userId: number): Vector3?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local frame: VisualKit.Frame = {
	number = 0,
	now = 0,
	dt = 0,
	floorY = Config.Map.arena.center.Y,
	folder = nil :: any,
	move = function(part: BasePart, cframe: CFrame)
		listLength += 1
		partList[listLength] = part
		cframeList[listLength] = cframe
	end,
	ownerPosition = rootPosition,
}

local function behaviorOf(weapon: Types.WeaponInfo): string?
	local evolution = weapon.evolution and Config.Evolutions[weapon.evolution]
	if evolution then
		return evolution.behavior
	end
	local config = Config.Weapons[weapon.id]
	return config and config.behavior
end

local function isAlive(userId: number): boolean
	local info = RunStateController.getPlayer(userId)
	return info ~= nil and info.participant and (info.state == nil or info.state == "Alive")
end

local function setEnabled(value: boolean)
	if value == enabled then
		return
	end
	enabled = value
	if not value then
		for _, visual in visuals do
			if visual.clear then
				visual.clear()
			end
		end
		table.clear(partList)
		table.clear(cframeList)
		listLength = 0
	end
end

local function render(dt: number)
	if not enabled then
		return
	end
	local previousLength = listLength
	listLength = 0
	frame.number += 1
	frame.now = workspace:GetServerTimeNow()
	frame.dt = dt
	frame.folder = getFolder()

	for userId, loadout in LoadoutController.getAll() do
		if not loadout.paused and #loadout.weapons > 0 and isAlive(userId) then
			local position = rootPosition(userId)
			if position then
				local owner: VisualKit.Owner = { userId = userId, position = position }
				for _, weapon in loadout.weapons do
					local behavior = behaviorOf(weapon)
					local visual = behavior and visuals[behavior]
					if visual and visual.renderWeapon then
						visual.renderWeapon(owner, weapon, frame)
					end
				end
			end
		end
	end
	for _, visual in visuals do
		if visual.render then
			visual.render(frame)
		end
	end

	for k = listLength + 1, previousLength do
		partList[k] = nil
		cframeList[k] = nil
	end
	if listLength > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function WeaponRenderer.init()
	Net.onClient("WeaponEffects", function(effects: { Types.WeaponEffect })
		if not enabled or typeof(effects) ~= "table" then
			return
		end
		for _, effect in effects do
			local visual = visuals[effect.weapon]
			if visual and visual.effect then
				visual.effect(effect)
			end
		end
	end)
	RunStateController.Changed:Connect(function()
		setEnabled(RunStateController.getView() == "Run")
	end)
end

function WeaponRenderer.start()
	setEnabled(RunStateController.getView() == "Run")
	RunService.RenderStepped:Connect(render)
end

return WeaponRenderer
