--!strict
-- Down and revive on screen (DESIGN.md section 8, WP11; ReviveState from ReviveService): a ring on the floor around
-- every downed player that shows where a teammate has to stand, a label above them with the seconds left and the
-- revive bar, a line for the local player ("You are down", "Reviving Mia") and, while the local player is out, the
-- camera watching a teammate who is still alive (CameraController.follow). The server decides every revive; this
-- only animates between updates with Util/ReviveRules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local ReviveRules = require(Shared:WaitForChild("Util"):WaitForChild("ReviveRules"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local CameraController = require(script.Parent.CameraController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local Coop = Config.Run.coop
local SETTINGS: ReviveRules.Settings = {
	downTimerSeconds = Coop.downTimerSeconds,
	reviveSeconds = Coop.reviveSeconds,
	reviveDecaySeconds = Coop.reviveDecaySeconds,
	downTimerPausesWhileReviving = Coop.downTimerPausesWhileReviving,
}
local FOLDER_NAME = "LanternfallRevive"
local RING_COLOR = Color3.fromRGB(236, 96, 96)
local REVIVE_COLOR = Color3.fromRGB(126, 214, 136)
local RING_HEIGHT = 0.12 -- studs
local RING_TRANSPARENCY = 0.6
local LABEL_OFFSET = Vector3.new(0, 4.5, 0) -- studs above the root part
local LABEL_SIZE = UDim2.fromOffset(150, 46)
local HINT_Y = 0.72 -- share of the screen height

type Marker = { billboard: BillboardGui, text: TextLabel, fill: Frame, ring: BasePart }

local ReviveController = {}

local infos: { [number]: Types.ReviveInfo } = {}
local markers: { [number]: Marker } = {}
local folder: Folder? = nil
local hintScreen: ScreenGui? = nil
local hintLabel: TextLabel? = nil
local floorY = Config.Map.arena.center.Y

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

local function nameOf(userId: number): string
	local info = RunStateController.getPlayer(userId)
	return if info then info.name else "a teammate"
end

local function rootOf(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Seconds left and revive progress of a downed player right now.
local function current(info: Types.ReviveInfo): ReviveRules.Entry
	local entry = { timeLeft = info.timeLeft, progress = info.progress }
	return ReviveRules.project(entry, workspace:GetServerTimeNow() - info.sentAt, info.reviverUserId ~= nil, SETTINGS)
end

local function buildMarker(userId: number): Marker
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local billboard = Widgets.create("BillboardGui", {
		Name = `Revive{userId}`,
		Size = LABEL_SIZE,
		StudsOffset = LABEL_OFFSET,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local text = Widgets.label({
		Name = "ReviveText",
		Font = Theme.fontBold,
		TextSize = 16,
		TextStrokeTransparency = 0.4,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = billboard,
	})
	local back = Widgets.create("Frame", {
		Name = "Back",
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 10),
		Parent = billboard,
	}, { Widgets.corner(UDim.new(0, 5)) })
	local fill = Widgets.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = REVIVE_COLOR,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = back,
	}, { Widgets.corner(UDim.new(0, 5)) })
	local diameter = Coop.reviveRadius * 2
	local ring = VisualKit.halo(
		"ReviveRing",
		Enum.PartType.Cylinder,
		Vector3.new(RING_HEIGHT, diameter, diameter),
		RING_COLOR,
		RING_TRANSPARENCY
	)
	ring.Parent = getFolder()
	return { billboard = billboard, text = text, fill = fill, ring = ring }
end

local function removeMarker(userId: number)
	local marker = markers[userId]
	if marker then
		marker.billboard:Destroy()
		marker.ring:Destroy()
		markers[userId] = nil
	end
end

local function buildHint()
	local gui = Widgets.screen("Revive", 2)
	hintLabel = Widgets.label({
		Name = "ReviveHint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, HINT_Y),
		Size = UDim2.new(1, -32, 0, 32),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.fontBold,
		TextSize = 20,
		TextStrokeTransparency = 0.3,
		Parent = gui,
	})
	hintScreen = gui
end

-- The local player's line: down, out, being revived, or reviving a teammate. Empty when none applies.
local function hintText(): string
	local me = Players.LocalPlayer.UserId
	local mine = infos[me]
	if mine and mine.state == "Out" then
		local watched = CameraController.getFollowed()
		local suffix = if watched then ` – watching {nameOf(watched.UserId)}` else ""
		return `You are out until the wave ends{suffix}`
	elseif mine then
		if mine.reviverUserId then
			return `{nameOf(mine.reviverUserId)} is reviving you…`
		end
		return `You are down! A teammate can revive you: {math.ceil(current(mine).timeLeft)} s`
	end
	for userId, info in infos do
		if info.reviverUserId == me then
			return `Reviving {nameOf(userId)}…`
		end
	end
	return ""
end

-- While the local player is out: watch the closest teammate who is still alive (or the first one found).
local function updateFollow()
	local mine = infos[Players.LocalPlayer.UserId]
	if not (mine and mine.state == "Out") then
		if CameraController.getFollowed() then
			CameraController.follow(nil)
		end
		return
	end
	local watched = CameraController.getFollowed()
	if watched and watched.Parent and not infos[watched.UserId] and rootOf(watched.UserId) then
		return
	end
	local choice: Player? = nil
	local state = RunStateController.get()
	if state then
		for _, info in state.players do
			if info.participant and info.userId ~= Players.LocalPlayer.UserId and not infos[info.userId] then
				local player = Players:GetPlayerByUserId(info.userId)
				if player and rootOf(info.userId) then
					choice = player
					break
				end
			end
		end
	end
	CameraController.follow(choice)
end

local function render()
	local inRun = RunStateController.getView() == "Run"
	for userId, info in infos do
		local root = rootOf(userId)
		local marker = markers[userId]
		if not (inRun and root) then
			if marker then
				removeMarker(userId)
			end
			continue
		end
		if not marker then
			marker = buildMarker(userId)
			markers[userId] = marker
		end
		marker.billboard.Adornee = root
		if info.state == "Out" then
			marker.text.Text = "OUT"
			marker.text.TextColor3 = Theme.textDim
			marker.fill.Size = UDim2.fromScale(0, 1)
			marker.ring.Transparency = 1
		else
			local entry = current(info)
			marker.text.Text = `DOWN {math.ceil(entry.timeLeft)} s`
			marker.text.TextColor3 = if info.reviverUserId then REVIVE_COLOR else Theme.danger
			marker.fill.Size = UDim2.fromScale(entry.progress, 1)
			marker.ring.Color = if info.reviverUserId then REVIVE_COLOR else RING_COLOR
			marker.ring.Transparency = RING_TRANSPARENCY
			local position = root.Position
			marker.ring.CFrame = CFrame.new(position.X, floorY + RING_HEIGHT, position.Z)
				* CFrame.Angles(0, 0, math.pi / 2)
		end
	end
	updateFollow()
	local gui, label = hintScreen, hintLabel
	if gui and label then
		local text = if inRun then hintText() else ""
		if label.Text ~= text then
			label.Text = text
		end
		gui.Enabled = text ~= ""
	end
end

local function onState(state: Types.ReviveState)
	table.clear(infos)
	for _, info in state.players do
		infos[info.userId] = info
	end
	for userId in markers do
		if not infos[userId] then
			removeMarker(userId)
		end
	end
end

function ReviveController.init()
	Net.onClient("ReviveState", onState)
end

function ReviveController.start()
	buildHint()
	RunService.RenderStepped:Connect(render)
end

-- Tests: the local player's line and the label above a downed player ("" when there is none).
function ReviveController.getHint(): string
	return if hintLabel then hintLabel.Text else ""
end

function ReviveController.getLabel(userId: number): string
	local marker = markers[userId]
	return if marker then marker.text.Text else ""
end

function ReviveController.getProgress(userId: number): number
	local marker = markers[userId]
	return if marker then marker.fill.Size.X.Scale else 0
end

return ReviveController
