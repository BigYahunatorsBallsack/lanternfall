--!strict
-- Run in Studio's Edit-mode command bar to inspect the four authored enemies; run again to remove the preview.
-- This developer tool is outside the Rojo src tree and is never shipped as a game script.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before opening the art preview")
local folderName = "LanternfallArtPreview"
local existing = workspace:FindFirstChild(folderName)
local camera = workspace.CurrentCamera
assert(camera)
if existing then
	assert(existing:GetAttribute("CodexEnemyArt"), "A different object owns the preview name")
	local originalCamera = existing:GetAttribute("OriginalCamera")
	local originalFov = existing:GetAttribute("OriginalFov")
	if typeof(originalCamera) == "CFrame" then
		camera.CFrame = originalCamera
	end
	if typeof(originalFov) == "number" then
		camera.FieldOfView = originalFov
	end
	existing:Destroy()
	return
end

local root = Instance.new("Folder")
root.Name = folderName
root:SetAttribute("CodexEnemyArt", true)
root:SetAttribute("OriginalCamera", camera.CFrame)
root:SetAttribute("OriginalFov", camera.FieldOfView)
root.Parent = workspace
local source = game.StarterPlayer.StarterPlayerScripts.Client.Controllers.EnemyRenderer
local scripts = Instance.new("Folder")
scripts.Name = "PreviewSources"
scripts.Parent = root
source.MeshCatalog:Clone().Parent = scripts
local module = source.Models:Clone()
module.Parent = scripts
local Models = require(module)
local Config = require(game.ReplicatedStorage.Shared.Config)
local origin = Vector3.new(2000, 12, 0)
local floor = Instance.new("Part")
floor.Name = "PreviewFloor"
floor.Anchored = true
floor.CanCollide = false
floor.CanTouch = false
floor.CanQuery = false
floor.Size = Vector3.new(24, 0.4, 22)
floor.Position = origin - Vector3.new(0, 0.22, 0)
floor.Material = Enum.Material.SmoothPlastic
floor.Color = Color3.fromRGB(110, 102, 112)
floor.Parent = root
local positions = { Vector3.new(5, 0, 4), Vector3.new(-5, 0, 4), Vector3.new(5, 0, -4), Vector3.new(-5, 0, -4) }
for i, id in { "Shadeling", "Brute", "Spitter", "Charger" } do
	local base = origin + positions[i]
	local visual = Models.build(Config.Enemies.types[id].typeId)
	visual.model.Parent = root
	local parts, frames = {}, {}
	Models.pose(visual, CFrame.new(base), 0.65, 0.5, 0, 0, parts, frames, 0)
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	local anchor = Instance.new("Part")
	anchor.Name = id .. "LabelAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = base + Vector3.new(0, 0.1, -2.8)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = root
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 30)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 19
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.35
	text.Text = id
	text.Parent = gui
end
camera.FieldOfView = 42
camera.CFrame = CFrame.lookAt(origin + Vector3.new(0, 18, -20), origin + Vector3.new(0, 1.6, 0))
