--!strict
-- Prepares trusted uploaded skin copies and binds them to an existing R15 root; called by CharacterAppearanceService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Art = require(ReplicatedStorage.Shared.Config.CharacterArt)

local Skin = {}

function Skin.prepare(container: Model, classId: string): Model
	local colorAtlas = Art.colorAtlases[classId]
	assert(colorAtlas, "Character asset has no color atlas")
	local root = container:FindFirstChild(Art.rootName, true)
	assert(root and root:IsA("BasePart"), "Character asset has no rig root")
	local model = container
	if root.Parent ~= container and root.Parent and root.Parent:IsA("Model") then
		model = root.Parent :: Model
		model.Parent = nil
		container:Destroy()
	end
	model.PrimaryPart = root
	model:PivotTo(CFrame.identity)
	model:ScaleTo(Art.displayScale)
	local visible = 0
	for _, instance in model:GetDescendants() do
		if
			instance:IsA("LuaSourceContainer")
			or instance:IsA("PackageLink")
			or instance:IsA("JointInstance")
			or instance:IsA("Constraint")
			or instance:IsA("AnimationController")
			or instance:IsA("Humanoid")
			or (instance:IsA("Folder") and instance.Name == Art.poseFolderName)
		then
			instance:Destroy()
		elseif instance:IsA("BasePart") then
			instance.Anchored = false
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
			instance.Massless = true
			if instance ~= root and instance.Size.Magnitude < Art.internalPartSize * Art.displayScale then
				instance.Transparency = 1
			elseif instance ~= root then
				visible += 1
				instance.Transparency = 0
			end
			if instance:IsA("MeshPart") then
				-- The imported PBR composites can remain unavailable after the color atlas
				-- is approved. Use the original color atlas directly so the face always loads.
				local appearance = instance:FindFirstChildWhichIsA("SurfaceAppearance")
				if appearance then
					appearance:Destroy()
				end
				instance.TextureID = colorAtlas
				instance.Color = Color3.new(1, 1, 1)
				instance.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	assert(visible >= 4, "Character asset is missing visible body parts")
	root.Transparency = 1
	for _, instance in model:GetDescendants() do
		if instance:IsA("BasePart") and instance ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = instance
			weld.Parent = instance
		end
	end
	return model
end

function Skin.floor(model: Model): number
	local root = model.PrimaryPart
	assert(root, "Character skin has no primary part")
	local lowest = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root and part.Transparency < 1 then
			local half = part.Size * 0.5
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local point = part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
						lowest = math.min(lowest, root.CFrame:PointToObjectSpace(point).Y)
					end
				end
			end
		end
	end
	assert(lowest < math.huge, "Character skin has no visible geometry")
	return lowest
end

function Skin.attach(template: Model, character: Model, root: BasePart, humanoid: Humanoid, classId: string): Model
	local sourceFloor = Skin.floor(template)
	local model = template:Clone()
	model.Name = Art.folderName
	model:SetAttribute("ClassId", classId)
	local skinRoot = model.PrimaryPart
	assert(skinRoot, "Character skin has no primary part")
	local nativeFloor = -humanoid.HipHeight - root.Size.Y * 0.5
	local offset = nativeFloor - sourceFloor
	model:PivotTo(root.CFrame * CFrame.new(0, offset, 0) * CFrame.Angles(0, math.rad(Art.yawDegrees), 0))
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CharacterSkinRoot"
	weld.Part0 = root
	weld.Part1 = skinRoot
	weld.Parent = skinRoot
	local previous = character:FindFirstChild(Art.folderName)
	if previous then
		previous:Destroy()
	end
	model.Parent = character
	return model
end

return Skin
