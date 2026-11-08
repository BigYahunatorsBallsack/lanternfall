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
local RING = Config.Sprites.heldWeapons

type Attack = {
	at: number,
	duration: number,
	dx: number,
	dz: number,
	kind: string,
	angle: number,
	distance: number,
	x: number,
	z: number,
}
type Model = { sprite: SpriteKit.Sprite, id: string, seen: number, x: number, z: number }

local pools: { [string]: VisualKit.ObjectPool<SpriteKit.Sprite> } = {}
local active: { [string]: Model } = {}
local attacks: { [string]: Attack } = {}
local flights: { [string]: number } = {}
local nearestByOwner: { [number]: { frame: number, x: number, z: number, found: boolean } } = {}

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

local function nearestEnemy(owner: VisualKit.Owner, frameNumber: number): (number?, number?)
	local cached = nearestByOwner[owner.userId]
	if cached and cached.frame == frameNumber then
		return if cached.found then cached.x else nil, if cached.found then cached.z else nil
	end
	local bestX, bestZ = 0, 0
	local bestSquared = math.huge
	local folder = workspace:FindFirstChild("LanternfallEnemies")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				local body = child:FindFirstChild("Body", true)
				if body and body:IsA("BasePart") then
					local position = body.Position
					local dx, dz = position.X - owner.position.X, position.Z - owner.position.Z
					local squared = dx * dx + dz * dz
					if squared < bestSquared then
						bestSquared = squared
						bestX, bestZ = position.X, position.Z
					end
				end
			end
		end
	end
	nearestByOwner[owner.userId] = { frame = frameNumber, x = bestX, z = bestZ, found = bestSquared < math.huge }
	return if bestSquared < math.huge then bestX else nil, if bestSquared < math.huge then bestZ else nil
end

-- Where a held weapon floats: evenly spaced around the figure's middle, far enough for its picture to stay off the
-- body. Slot and count follow the server's loadout order, so shots leave from the weapon on screen.
local function floatingAt(owner: VisualKit.Owner, slot: number, total: number, id: string): (number, number)
	local dx, dz = WeaponPose.direction(slot, total)
	local radius = RING.clearance + (LOOK.spriteStuds[id] or 4) * 0.5
	return owner.position.X + dx * radius, owner.position.Z - RING.lift + dz * radius
end

function HeldModels.effect(effect: Types.WeaponEffect)
	local uid = effect.uid
	if not uid then
		return
	end
	local key = keyOf(effect.userId, uid)
	if effect.kind == "End" then
		return
	end
	local dx, dz = aimOf(effect)
	local duration = if effect.kind == "Strike" then effect.duration or LOOK.attackSeconds else LOOK.attackSeconds
	attacks[key] = {
		at = workspace:GetServerTimeNow(),
		duration = duration,
		dx = dx,
		dz = dz,
		kind = effect.kind,
		angle = effect.angle or 0,
		distance = effect.targetDistance or 0,
		x = effect.x or 0,
		z = effect.z or 0,
	}
end

function HeldModels.has(id: string): boolean
	return Images[id] ~= nil
end

function HeldModels.renderWeapon(
	owner: VisualKit.Owner,
	weapon: { uid: number, id: string },
	slot: number,
	total: number,
	frame: VisualKit.Frame
)
	-- Orbit blades are drawn at their actual server hit positions by Visuals/OrbitBlades.
	if not Images[weapon.id] then
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
		model = { sprite = poolOf(weapon.id):acquire(frame.folder), id = weapon.id, seen = 0, x = 0, z = 0 }
		active[key] = model
	end
	model.seen = frame.number

	local radialX, radialZ = WeaponPose.direction(slot, total)
	local x, z = floatingAt(owner, slot, total, weapon.id)
	local dx, dz = radialX, radialZ
	local targetX, targetZ = nearestEnemy(owner, frame.number)
	if targetX and targetZ then
		local tx, tz = targetX - owner.position.X, targetZ - owner.position.Z
		local distance = math.sqrt(tx * tx + tz * tz)
		if distance > 1e-6 then
			dx, dz = tx / distance, tz / distance
		end
	end
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
				local reach = math.max(0, attack.distance - LOOK.spriteStuds[weapon.id] * LOOK.strikeTipFraction)
				local centerX = owner.position.X + dx * reach
				local centerZ = owner.position.Z + dz * reach
				local movement = math.sin(math.pi * t)
				if attack.angle ~= 0 then
					local turn = math.rad(attack.angle * (t - 0.5))
					local c, s = math.cos(turn), math.sin(turn)
					dx, dz = dx * c - dz * s, dx * s + dz * c
					local side = math.sin(2 * math.pi * t) * WeaponPose.radius(weapon.id) * 0.5
					centerX += -attack.dz * side
					centerZ += attack.dx * side
				end
				x += (centerX - x) * movement
				z += (centerZ - z) * movement
			elseif attack.kind == "Fire" then
				local recoil = math.sin(math.pi * t) * LOOK.recoilDistance
				x -= dx * recoil
				z -= dz * recoil
			elseif attack.kind == "Pulse" then
				local movement = math.sin(math.pi * t)
				local tip = LOOK.spriteStuds[weapon.id] * LOOK.strikeTipFraction
				local centerX = attack.x - dx * tip
				local centerZ = attack.z - dz * tip
				x += (centerX - x) * movement
				z += (centerZ - z) * movement
			end
		end
	end
	local bob = math.sin(frame.now * LOOK.idleBobSpeed + weapon.uid) * LOOK.idleBob
	local sprite = model.sprite
	model.x, model.z = x, z
	sprite.picture.Visible = (flights[key] or 0) == 0
	sprite.picture.Rotation = SpriteKit.rotationToward(weapon.id, dx, dz)
	-- bobbing goes up the screen, the camera looks straight down
	frame.move(sprite.anchor, CFrame.new(x, frame.floorY + LOOK.projectileHeight, z - bob))
end

-- The client projectile starts at the barrel currently on screen, then rejoins the server path.
function HeldModels.projectileOrigin(effect: Types.WeaponEffect): (number, number)
	local x, z = effect.x or 0, effect.z or 0
	local uid = effect.uid
	if not uid then
		return x, z
	end
	local model = active[keyOf(effect.userId, uid)]
	if not model or model.seen == 0 then
		return x, z
	end
	local fraction = LOOK.muzzleFractionById[model.id] or LOOK.muzzleFraction
	local muzzle = (LOOK.spriteStuds[model.id] or 4) * fraction
	return model.x + (effect.dx or 0) * muzzle, model.z + (effect.dz or 0) * muzzle
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
	table.clear(nearestByOwner)
end

return HeldModels
