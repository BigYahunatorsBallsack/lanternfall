--!strict
-- Shows approved weapon artwork beside each player and animates the exact copy named by server attack effects.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local WeaponPose = require(Shared:WaitForChild("Util"):WaitForChild("WeaponPose"))

local Images = require(script.Parent.Parent.Parent.UI.WeaponImages)
local SpriteKit = require(script.Parent.SpriteKit)
local VisualKit = require(script.Parent.VisualKit)

local LOOK = Config.WeaponVisuals

type Attack = { at: number, duration: number, dx: number, dz: number, kind: string, angle: number }
type Model = { sprite: SpriteKit.Sprite, id: string, seen: number }

local pools: { [string]: VisualKit.ObjectPool<SpriteKit.Sprite> } = {}
local active: { [string]: Model } = {}
local attacks: { [string]: Attack } = {}
local flights: { [string]: number } = {}

local HeldModels = {}

local function keyOf(userId: number, uid: number): string
	return `{userId}:{uid}`
end

local function poolOf(id: string): VisualKit.ObjectPool<SpriteKit.Sprite>
	local pool = pools[id]
	if pool then
		return pool
	end
	local created = VisualKit.objectPool(function(): SpriteKit.Sprite
		return SpriteKit.create(id, LOOK.spriteStuds[id], `Held{id}`)
	end, function(sprite: SpriteKit.Sprite): { BasePart }
		return { sprite.anchor }
	end)
	pools[id] = created
	return created
end

local function aimOf(effect: Types.WeaponEffect): (number, number)
	if effect.dx and effect.dz then
		return effect.dx, effect.dz
	end
	local points = effect.points
	if points and #points >= 4 then
		local dx, dz = points[3] - points[1], points[4] - points[2]
		local length = math.sqrt(dx * dx + dz * dz)
		if length > 0 then
			return dx / length, dz / length
		end
	end
	return 0, 0
end

function HeldModels.effect(effect: Types.WeaponEffect)
	local uid = effect.uid
	if not uid then
		return
	end
	local key = keyOf(effect.userId, uid)
	if effect.weapon == "BoomerangAxe" then
		if effect.kind == "Fire" then
			flights[key] = (flights[key] or 0) + 1
		elseif effect.kind == "End" then
			flights[key] = math.max(0, (flights[key] or 0) - 1)
		end
	end
	if effect.kind == "End" then
		return
	end
	local dx, dz = aimOf(effect)
	local duration = if effect.kind == "Strike" then effect.duration or LOOK.attackSeconds else LOOK.attackSeconds
	attacks[key] = {
		at = math.max(effect.at, workspace:GetServerTimeNow() - duration * 0.25),
		duration = duration,
		dx = dx,
		dz = dz,
		kind = effect.kind,
		angle = effect.angle or 0,
	}
end

function HeldModels.has(id: string): boolean
	return Images[id] ~= nil
end

function HeldModels.renderWeapon(
	owner: VisualKit.Owner,
	weapon: { uid: number, id: string },
	_slot: number,
	_total: number,
	frame: VisualKit.Frame
)
	-- Orbit blades are drawn at their actual server hit positions by Visuals/OrbitBlades.
	if weapon.id == "OrbitBlades" or not Images[weapon.id] then
		return
	end
	local key = keyOf(owner.userId, weapon.uid)
	local model = active[key]
	if model and model.id ~= weapon.id then
		poolOf(model.id):release(model.sprite)
		active[key] = nil
		model = nil
	end
	if not model then
		model = { sprite = poolOf(weapon.id):acquire(frame.folder), id = weapon.id, seen = 0 }
		active[key] = model
	end
	model.seen = frame.number

	local radialX, radialZ = WeaponPose.direction(weapon.uid)
	local x, z = WeaponPose.anchor(owner.position.X, owner.position.Z, weapon.uid, weapon.id)
	local dx, dz = radialX, radialZ
	local attack = attacks[key]
	if attack then
		local t = (frame.now - attack.at) / attack.duration
		if t >= 1 then
			attacks[key] = nil
		elseif t >= 0 then
			if attack.dx ~= 0 or attack.dz ~= 0 then
				dx, dz = attack.dx, attack.dz
			end
			if attack.kind == "Strike" then
				if attack.angle == 0 then
					local extension = math.sin(math.pi * t) * LOOK.thrustDistance
					x += dx * extension
					z += dz * extension
				else
					local turn = math.rad(attack.angle * (t - 0.5))
					local c, s = math.cos(turn), math.sin(turn)
					dx, dz = dx * c - dz * s, dx * s + dz * c
					local radius = WeaponPose.radius(weapon.id)
					x = owner.position.X + dx * radius
					z = owner.position.Z + dz * radius
				end
			elseif attack.kind == "Fire" then
				local recoil = math.sin(math.pi * t) * LOOK.recoilDistance
				x -= dx * recoil
				z -= dz * recoil
			elseif attack.kind == "Pulse" then
				local slam = math.sin(math.pi * t) * LOOK.recoilDistance
				x += dx * slam
				z += dz * slam
			end
		end
	end
	local bob = math.sin(frame.now * LOOK.idleBobSpeed + weapon.uid) * LOOK.idleBob
	local sprite = model.sprite
	sprite.picture.Visible = (flights[key] or 0) == 0
	sprite.picture.Rotation = SpriteKit.rotationToward(weapon.id, dx, dz)
	frame.move(sprite.anchor, CFrame.new(x, frame.floorY + LOOK.projectileHeight + bob, z))
end

function HeldModels.finish(frame: VisualKit.Frame)
	for key, model in active do
		if model.seen ~= frame.number then
			poolOf(model.id):release(model.sprite)
			active[key] = nil
			attacks[key] = nil
			flights[key] = nil
		end
	end
end

function HeldModels.clear()
	for key, model in active do
		poolOf(model.id):release(model.sprite)
		active[key] = nil
	end
	table.clear(attacks)
	table.clear(flights)
end

return HeldModels
