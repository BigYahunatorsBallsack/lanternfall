--!strict
-- Animates every player's 2D character sprite from real movement, attacks, hits and down state, on every client the
-- same way; loaded by the client controller loader. WeaponRenderer calls attack(), Visibility owns the sprites.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Look = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sprites")).character
local RunStateController = require(script.Parent.RunStateController)
local Visibility = require(script.Parent.Parent.CharacterArt.Visibility)
local WorldSprite = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("WorldSprite")
)

type Motion = {
	x: number,
	z: number,
	seen: boolean,
	phase: number,
	idle: number,
	blend: number,
	attackAt: number,
	hitAt: number,
	health: number,
	tint: string,
}

local WHITE = Color3.new(1, 1, 1)
local DOWN_TINT = Color3.fromRGB(table.unpack(Look.downTint))
local OUT_TINT = Color3.fromRGB(table.unpack(Look.outTint))
local motions: { [Player]: Motion } = {}
local CharacterAnimationController = {}

local function motionOf(player: Player): Motion
	local motion = motions[player]
	if not motion then
		motion = {
			x = 0,
			z = 0,
			seen = false,
			phase = 0,
			idle = player.UserId % 7,
			blend = 0,
			attackAt = -math.huge,
			hitAt = -math.huge,
			health = math.huge,
			tint = "",
		}
		motions[player] = motion
	end
	return motion
end

-- The short squeeze of the character whose weapon just fired (server effects, so every client shows it).
function CharacterAnimationController.attack(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		motionOf(player).attackAt = os.clock()
	end
end

function CharacterAnimationController.update(dt: number)
	Visibility.update()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local entry = Visibility.get(player)
		if not (entry and entry.ready) then
			continue
		end
		Visibility.placeShadow(entry)
		local motion = motionOf(player)
		local position = entry.root.Position
		local dx, dz = position.X - motion.x, position.Z - motion.z
		motion.x, motion.z = position.X, position.Z
		local step = if motion.seen then math.sqrt(dx * dx + dz * dz) else 0
		motion.seen = true
		local speed = if dt > 0 then step / dt else 0

		local info = RunStateController.getPlayer(player.UserId)
		local state = info and info.state
		local down = state == "Down" or state == "Out"
		local walking = speed > Look.movingThreshold and not down
		local target = if walking then 1 else 0
		motion.blend += (target - motion.blend) * (1 - math.exp(-Look.blendSharpness * dt))
		if walking then
			motion.phase = (motion.phase + dt / Look.walkCycleSeconds * 2 * math.pi) % (2 * math.pi)
		end
		motion.idle += dt * Look.idleSpeed

		-- Faces the way it walks; standing or walking straight up and down keeps the last side.
		if walking and math.abs(dx) > math.abs(dz) * 0.25 and dx ~= 0 then
			WorldSprite.setFlip(entry.sprite, dx < 0)
		end

		local humanoid = entry.humanoid
		if humanoid then
			if humanoid.Health < motion.health - 0.01 and motion.health ~= math.huge then
				motion.hitAt = now
			end
			motion.health = humanoid.Health
		end

		Visibility.poseFeet(entry, motion.phase, motion.blend, not down)
		local scaleX, scaleY, rotation, lift = 1, 1, 0, 0
		if down then
			rotation = if entry.sprite.flipped then -Look.downRotationDegrees else Look.downRotationDegrees
		else
			-- Tipped to a side the body sits flat, upright between two steps it stretches and lifts off.
			local wave = math.sin(motion.phase)
			local upright = math.cos(2 * motion.phase)
			local breath = math.sin(motion.idle) * Look.idleSquash * (1 - motion.blend)
			local stretch = upright * Look.walkSquash * motion.blend
			scaleY = 1 + breath + stretch
			scaleX = 1 - breath - stretch * 0.8
			rotation = wave * Look.walkTiltDegrees * motion.blend
			lift = (upright + 1) / 2 * Look.walkHopStuds * motion.blend
			local attack = (now - motion.attackAt) / Look.attackSeconds
			if attack < 1 then
				local squeeze = math.sin(attack * math.pi) * Look.attackScale
				scaleX += squeeze
				scaleY -= squeeze * 0.7
			end
		end
		WorldSprite.pose(entry.sprite, scaleX, scaleY, rotation, lift)

		local hit = (now - motion.hitAt) < Look.hitSeconds
		local tint = if hit then "hit" elseif state == "Out" then "out" elseif down then "down" else "plain"
		if tint ~= motion.tint then
			motion.tint = tint
			if tint == "hit" then
				WorldSprite.setTint(entry.sprite, WHITE, Look.hitBrightness)
			elseif tint == "out" then
				WorldSprite.setTint(entry.sprite, OUT_TINT)
			elseif tint == "down" then
				WorldSprite.setTint(entry.sprite, DOWN_TINT)
			else
				WorldSprite.setTint(entry.sprite, WHITE)
			end
		end
	end
end

function CharacterAnimationController.start()
	RunService.RenderStepped:Connect(CharacterAnimationController.update)
	Players.PlayerRemoving:Connect(function(player)
		motions[player] = nil
		Visibility.forget(player)
	end)
end

return CharacterAnimationController
