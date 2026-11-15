--!strict
-- Server-owned jump landing warnings and shadow offsets; procedural fallback, original prepared PNGs are not uploaded.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Kinds = require(Shared.Util.EnemyKinds)
local Motion = require(Shared.Util.NativeJumpMotion)
local Types = require(Shared.Net.Types)
local Net = require(Shared.Net)
local State = require(script.Parent.RunStateController)
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.WeaponRenderer.VisualKit)
local Controller = {}
local entries: { [number]: { info: Types.NativeJumpInfo, part: BasePart? } } = {}
local folder: Folder? = nil
local style = require(Shared.Config.NightmareEnemies).runtimeCompatibility.slashVisual
local pool = Kit.objectPool(function()
	local part = Instance.new("Part")
	part.Name = "LandingWarning"
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(table.unpack(Config.Sprites.enemy.flashTint))
	part.Transparency = style.warningTransparency
	return part
end, function(part)
	return { part }
end)
local function remove(id: number)
	local entry = entries[id]
	if entry and entry.part then
		pool:release(entry.part)
	end
	entries[id] = nil
end
local function clear()
	for id in entries do
		remove(id)
	end
end
local function receive(batch: Types.NativeJumpBatch)
	if batch.reset then
		clear()
	end
	if State.getView() ~= "Run" then
		return
	end
	for _, info in batch.started do
		remove(info.id)
		entries[info.id] = { info = info, part = nil }
	end
	for _, id in batch.ended do
		remove(id)
	end
end
local function render()
	if State.getView() ~= "Run" then
		clear()
		return
	end
	for id, entry in entries do
		local kind = Kinds.byTypeId(entry.info.typeId)
		local profile = kind and kind.nativeJumpPresentation
		if not profile then
			remove(id)
			continue
		end
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "LanternfallNativeJumps"
			folder.Parent = workspace
		end
		local part = entry.part or pool:acquire(folder)
		entry.part = part
		part.Size = Vector3.new(style.thickness, profile.warningWidth, profile.warningHeight)
		part.CFrame = CFrame.new(entry.info.targetX, Config.Map.arena.center.Y + style.floorLift, entry.info.targetZ)
			* CFrame.Angles(0, 0, math.pi / 2)
	end
end
function Controller.getShadow(id: number): { offsetZ: number, width: number, height: number }?
	local entry = entries[id]
	local kind = entry and Kinds.byTypeId(entry.info.typeId)
	local rule, profile = kind and kind.nativeJump, kind and kind.nativeJumpPresentation
	if not entry or not rule or not profile then
		return nil
	end
	local info = entry.info
	local age = math.max(0, workspace:GetServerTimeNow() - Config.Simulation.interpolationDelay - info.at)
	local _, _, height = Motion.sample(rule, info.startX, info.startZ, info.targetX, info.targetZ, age)
	local scale = profile.parentScale
		* (
			if age < rule.delay
				then profile.initialScale
				else profile.airScale * (1 - math.clamp(height / rule.height, 0, 1) * profile.heightShrinkShare)
		)
	return {
		offsetZ = profile.parentScale * (profile.groundOffsetZ + height),
		width = profile.shadowWidth * scale,
		height = profile.shadowHeight * scale,
	}
end
function Controller.init()
	Net.onClient("NativeJumps", receive)
	State.Changed:Connect(function()
		if State.getView() ~= "Run" then
			clear()
		end
	end)
end
function Controller.start()
	RunService.RenderStepped:Connect(render)
end
function Controller.getCount(): number
	local count = 0
	for _ in entries do
		count += 1
	end
	return count
end
return Controller
