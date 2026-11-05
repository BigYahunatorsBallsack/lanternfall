--!strict
-- Finalize a selected imported Lanternfall R15 model; called from Studio's Command Bar.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select exactly one imported character Model.")
local model = selected[1] :: Model
local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
assert(humanoid and humanoid.RigType == Enum.HumanoidRigType.R15, "Import the FBX with Rig Type = R15 first.")

local expected = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}
local parts: { [string]: BasePart } = {}
for _, instance in model:GetDescendants() do
	if instance:IsA("BasePart") then
		local name = string.gsub(instance.Name, "_Geo$", "")
		if table.find(expected, name) then
			assert(not parts[name], "Duplicate body part: " .. name)
			parts[name] = instance
		end
	end
end
for _, name in expected do
	assert(parts[name], "Missing R15 body part: " .. name)
end
local root = model:FindFirstChild("HumanoidRootPart", true)
assert(root and root:IsA("BasePart"), "The importer did not create HumanoidRootPart. Check Rig Type = R15.")
local rootPart = root :: BasePart
local scale = parts.Head.Size.Y / 4
assert(scale > 0, "Invalid character scale.")

for name, part in parts do
	part.Name = name
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	-- The original silhouette is carried by the egg, hands and feet.
	-- Tiny standard R15 segments are deliberately internal and transparent.
	part.Transparency = if part.Size.Magnitude < scale * 0.16 then 1 else 0
end
rootPart.Anchored = false
rootPart.Transparency = 1
rootPart.Massless = false
rootPart.CanCollide = true
rootPart.Size = Vector3.new(0.9, 1, 0.75) * scale
model.PrimaryPart = rootPart
humanoid.AutoScalingEnabled = false
local floorY = math.min(
	parts.LeftFoot.Position.Y - parts.LeftFoot.Size.Y * 0.5,
	parts.RightFoot.Position.Y - parts.RightFoot.Size.Y * 0.5
)
humanoid.HipHeight = math.max(0, rootPart.Position.Y - floorY - rootPart.Size.Y * 0.5)
if not humanoid:FindFirstChildOfClass("Animator") then
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
end
model:SetAttribute("LanternfallImportFinalized", true)
print("Lanternfall R15 ready for Animation Editor:", model:GetFullName(), "Scale:", scale)
