--!strict
-- Animates every replicated R15 character skin from real movement and down state; loaded by the client controller loader.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Art = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CharacterArt"))
local RunStateController = require(script.Parent.RunStateController)
local Visibility = require(script.Parent.Parent.CharacterArt.Visibility)
local Motion = Art.animation

type Entry = { skin: Model, root: BasePart, bones: { [string]: Bone }, phase: number, blend: number }
local entries: { [Player]: Entry } = {}
local CharacterAnimationController = {}

local function discover(player: Player): Entry?
	local view = Visibility.get(player)
	if not (view and view.ready) then
		return nil
	end
	local character = player.Character
	local skin = character and character:FindFirstChild(Art.folderName)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (skin and skin:IsA("Model") and root and root:IsA("BasePart")) then
		return nil
	end
	local current = entries[player]
	if
		current
		and current.skin == skin
		and current.bones.Head
		and current.bones.LeftFoot
		and current.bones.RightFoot
	then
		return current
	end
	local bones: { [string]: Bone } = {}
	for _, instance in skin:GetDescendants() do
		if instance:IsA("Bone") then
			bones[instance.Name] = instance
		end
	end
	local entry = { skin = skin, root = root, bones = bones, phase = 0, blend = 0 }
	entries[player] = entry
	return entry
end

local function pose(entry: Entry, name: string, transform: CFrame)
	local bone = entry.bones[name]
	if bone then
		bone.Transform = transform
	end
end

function CharacterAnimationController.update(dt: number)
	Visibility.update()
	for _, player in Players:GetPlayers() do
		local entry = discover(player)
		if not entry then
			entries[player] = nil
			continue
		end
		local velocity = entry.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local info = RunStateController.getPlayer(player.UserId)
		local down = info ~= nil and (info.state == "Down" or info.state == "Out")
		local walking = speed > Motion.movingThreshold and not down
		local target = if walking then 1 else 0
		entry.blend += (target - entry.blend) * (1 - math.exp(-Motion.blendSharpness * dt))
		entry.phase += dt * math.pi * 2 * (if walking then speed / Motion.strideStuds else 1 / Motion.idlePeriodSeconds)
		local wave = math.sin(entry.phase)
		-- Run after the native Animator and own the skin pose without changing the gameplay rig.
		for _, bone in entry.bones do
			bone.Transform = CFrame.identity
		end
		local bob = Motion.idleBob + (Motion.walkBob - Motion.idleBob) * entry.blend
		pose(entry, "LowerTorso", CFrame.new(0, bob * (1 - math.cos(entry.phase * 2)), 0))
		pose(
			entry,
			"Head",
			CFrame.Angles(if down then math.rad(Motion.downTiltDegrees) else 0, Motion.headYaw * wave, 0)
		)
		local arm = Motion.idleArmSwing + (Motion.walkArmSwing - Motion.idleArmSwing) * entry.blend
		for _, side in { "Left", "Right" } do
			local sign = if side == "Left" then 1 else -1
			pose(entry, side .. "UpperArm", CFrame.Angles(sign * arm * wave, 0, 0))
			pose(entry, side .. "UpperLeg", CFrame.Angles(-sign * Motion.walkLegSwing * entry.blend * wave, 0, 0))
		end
	end
end

function CharacterAnimationController.start()
	RunService.PreSimulation:Connect(CharacterAnimationController.update)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
		Visibility.forget(player)
	end)
end

return CharacterAnimationController
