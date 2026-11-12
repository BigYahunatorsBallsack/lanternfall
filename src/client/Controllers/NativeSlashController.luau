--!strict
-- Draws source slash hitbox motion from authoritative fire/end batches; this procedural fallback does not claim original sprite acceptance.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local C = require(Shared.Config.NightmareEnemies)
local Charm = require(Shared.Config.Charm)
local Geometry = require(Shared.Util.NativeSlashGeometry)
local Types = require(Shared.Net.Types)
local Net = require(Shared.Net)
local RunService = game:GetService("RunService")
local State = require(script.Parent.RunStateController)
local Kit = require(script.Parent.WeaponRenderer.VisualKit)
local PIXEL = Config.Player.moveSpeed / C.runtimeCompatibility.referencePlayerSpeedPixels
local Visual = C.runtimeCompatibility.slashVisual
local Controller = {}
local shots: { [number]: { info: Types.NativeSlashInfo, part: BasePart? } } = {}
local folder: Folder? = nil
local pool = Kit.objectPool(function()
	local part = Instance.new("Part")
	part.Name = "NativeSlash"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	return part
end, function(part)
	return { part }
end)
local function remove(id: number)
	local shot = shots[id]
	if shot and shot.part then
		pool:release(shot.part)
	end
	shots[id] = nil
end
local function clear()
	for id in shots do
		remove(id)
	end
end
local function getFolder(): Folder
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "LanternfallNativeSlashes"
		created.Parent = workspace
		folder = created
	end
	return folder :: Folder
end
local function receive(batch: Types.NativeSlashBatch)
	if batch.reset then
		clear()
	end
	if State.getView() ~= "Run" then
		return
	end
	for _, info in batch.fired do
		shots[info.id] = { info = info, part = nil }
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
	local now = workspace:GetServerTimeNow()
	for id, shot in shots do
		local age = math.max(0, now - shot.info.at)
		if age >= C.slash.stopAt then
			remove(id)
			continue
		end
		local x, z, hx, hz = Geometry.rectangle(shot.info, age, PIXEL)
		local part = shot.part or pool:acquire(getFolder())
		shot.part = part
		part.Size = Vector3.new(hx * 2, Visual.thickness, hz * 2)
		part.Color =
			Color3.fromRGB(table.unpack(if shot.info.ownerId then Charm.color else Config.Sprites.enemy.flashTint))
		part.Transparency = if Geometry.active(age) then Visual.activeTransparency else Visual.warningTransparency
		part.CFrame = CFrame.new(x, Config.Map.arena.center.Y + Visual.floorLift, z)
			* CFrame.Angles(0, -math.atan2(shot.info.dz, shot.info.dx), 0)
	end
end
function Controller.init()
	Net.onClient("NativeSlashes", receive)
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
	for _ in shots do
		count += 1
	end
	return count
end
return Controller
