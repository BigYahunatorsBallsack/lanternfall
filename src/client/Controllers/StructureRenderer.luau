--!strict
-- B12 cosmetic pooled structures and attack rays. Never decides hits, healing or movement.
local Shared = game:GetService("ReplicatedStorage").Shared
local RunService = game:GetService("RunService")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Kit = require(script.Parent.WeaponRenderer.VisualKit)
local Renderer = {}
local folder: Folder
local live = {}
local flashes = {}
local pool = Kit.objectPool(function()
	return {
		Kit.part("Plinth", Enum.PartType.Cylinder, Vector3.new(0.6, 3, 3), Color3.fromRGB(86, 73, 57)),
		Kit.part("Lantern", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), Color3.new(1, 1, 1)),
	}
end, function(parts)
	return parts
end)
local beamPool = Kit.objectPool(function()
	return { Kit.part("StructureRay", Enum.PartType.Block, Vector3.new(0.12, 0.12, 1), Color3.new(1, 1, 1)) }
end, function(parts)
	return parts
end)
function Renderer.init()
	folder = Instance.new("Folder")
	folder.Name = "LanternfallStructures"
	folder.Parent = workspace
	Net.onClient("Structures", function(rows)
		local seen = {}
		for _, row in rows do
			local def = Config.Structures.kinds[row.kind]
			if not def then
				continue
			end
			seen[row.id] = true
			local parts = live[row.id]
			if not parts then
				parts = pool:acquire(folder)
				live[row.id] = parts
			end
			local y = Config.Map.arena.center.Y
			parts[1].CFrame = CFrame.new(row.x, y + 0.4, row.z) * CFrame.Angles(0, 0, math.pi / 2)
			parts[2].CFrame = CFrame.new(row.x, y + 1.5, row.z)
			parts[2].Color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
			parts[2].Shape = if def.mode == "Mine" or def.mode == "Garden"
				then Enum.PartType.Block
				else Enum.PartType.Ball
		end
		for id, parts in live do
			if not seen[id] then
				pool:release(parts)
				live[id] = nil
			end
		end
	end)
	Net.onClient("StructureBeams", function(rows)
		for _, row in rows do
			if #flashes >= Config.Structures.maxActive * 2 then
				break
			end
			local def = Config.Structures.kinds[row.kind]
			if not def then
				continue
			end
			local a = Vector3.new(row.x, Config.Map.arena.center.Y + 1.5, row.z)
			local b = Vector3.new(row.tx, a.Y, row.tz)
			if (b - a).Magnitude <= 0 then
				continue
			end
			local parts = beamPool:acquire(folder)
			parts[1].Size = Vector3.new(0.12, 0.12, (b - a).Magnitude)
			parts[1].CFrame = CFrame.lookAt((a + b) / 2, b)
			parts[1].Color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
			table.insert(flashes, { parts = parts, left = Config.Structures.beamSeconds })
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		for i = #flashes, 1, -1 do
			flashes[i].left -= dt
			if flashes[i].left <= 0 then
				beamPool:release(flashes[i].parts)
				table.remove(flashes, i)
			end
		end
	end)
end
return Renderer
