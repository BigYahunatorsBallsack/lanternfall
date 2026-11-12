--!strict
-- Draws server-selected shared Nightmare fog below the HUD, using existing actor positions and source-backed light masks; native shader acceptance remains open.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.NativeFog)
local Types = require(Shared.Net.Types)
local Net = require(Shared.Net)
local Raster = require(Shared.Util.NativeFogRaster)
local Rules = require(Shared.Util.NativeFogRules)
local State = require(script.Parent.RunStateController)
local Structures = require(script.Parent.StructureRenderer)
local Enemies = require(script.Parent.EnemyRenderer)
local Sources = require(script.Sources)
local Surface = require(script.Surface)
local Controller = {}
local state: Types.NativeFogState = { wave = 0, at = 0, players = {} }
local gui: ScreenGui? = nil
local surface: any = nil
local aspect = 0
local elapsed = 0
local structures: { [string]: { x: number, z: number, kind: string, at: number, stopped: number? } } = {}
local function hide()
	if gui then
		gui.Enabled = false
	end
	Sources.setEnabled(false)
	table.clear(structures)
end
local function receive(value: Types.NativeFogState)
	if value.wave ~= state.wave or value.at ~= state.at then
		Sources.setEnabled(false)
		table.clear(structures)
	end
	state = value
	Sources.setEnabled(value.wave ~= 0)
	if value.wave == 0 then
		hide()
	end
end
local function render(dt: number)
	local run = State.get()
	local active = state.wave ~= 0
		and State.getView() == "Run"
		and run
		and run.phase == "Running"
		and run.wave == state.wave
	if not active then
		if gui then
			gui.Enabled = false
		end
		return
	end
	local camera = workspace.CurrentCamera
	if not camera or camera.ViewportSize.Y <= 0 then
		return
	end
	elapsed += dt
	if elapsed < 1 / C.runtimeCompatibility.updatesPerSecond then
		return
	end
	elapsed = 0
	local ratio = camera.ViewportSize.X / camera.ViewportSize.Y
	if not gui then
		local created = Instance.new("ScreenGui")
		created.Name = "NativeFog"
		created.DisplayOrder = C.runtimeCompatibility.displayOrder
		created.IgnoreGuiInset = true
		created.ResetOnSpawn = false
		created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		gui = created
	end
	if not surface or math.abs(ratio - aspect) > 1 / C.runtimeCompatibility.renderHeight then
		if surface then
			surface.destroy()
		end
		surface = Surface.new(gui :: ScreenGui, ratio)
		aspect = ratio
	end
	local lights: { Raster.Light } = {}
	local now = workspace:GetServerTimeNow()
	local function emit(x: number, z: number, kind: string, age: number, fade: number, visibility: number?)
		local point = camera:WorldToViewportPoint(Vector3.new(x, Config.Map.arena.center.Y, z))
		if point.Z <= 0 then
			return
		end
		table.insert(lights, {
			x = point.X / camera.ViewportSize.X * surface.width,
			y = point.Y / camera.ViewportSize.Y * surface.height,
			kind = kind,
			age = age,
			fade = fade,
			visibility = visibility or 0,
		})
	end
	for _, info in state.players do
		if not info.alive then
			continue
		end
		local player = Players:GetPlayerByUserId(info.userId)
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			emit(root.Position.X, root.Position.Z, "player", now - state.at, 1, info.visibility)
		end
	end
	local seen = {}
	local function capture(id: string, x: number, z: number, kind: string)
		seen[id] = true
		local light = structures[id] or { x = x, z = z, kind = kind, at = now, stopped = nil }
		light.x, light.z, light.stopped = x, z, nil
		structures[id] = light
	end
	Structures.visitPositions(function(id, x, z)
		capture("structure:" .. id, x, z, "structure")
	end)
	Enemies.visitFogSources(function(id, x, z, kind)
		capture(kind .. ":enemy:" .. id, x, z, kind)
	end)
	for id, light in structures do
		local fade = 1
		if not seen[id] then
			light.stopped = light.stopped or now
			fade = Rules.transientFade(now - (light.stopped :: number), 0)
		end
		if fade <= 0 then
			structures[id] = nil
		else
			emit(light.x, light.z, light.kind, now - light.at, fade)
		end
	end
	Sources.visit(now, function(x, z, kind, age, fade)
		emit(x, z, kind, age, fade)
	end)
	surface.write(Raster.draw(surface.width, surface.height, state.wave, lights))
	local visibleGui = gui :: ScreenGui
	visibleGui.Enabled = true
end
function Controller.init()
	Net.onClient("NativeFog", receive)
	State.Changed:Connect(function()
		if State.getView() ~= "Run" then
			hide()
		end
	end)
end
function Controller.start()
	RunService.RenderStepped:Connect(render)
end
function Controller.isVisible(): boolean
	return gui ~= nil and (gui :: ScreenGui).Enabled
end
return Controller
