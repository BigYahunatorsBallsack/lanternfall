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
local TARGETING = Config.Combat.originalWeapons
local RING = Config.Sprites.heldWeapons
local TAU = 2 * math.pi

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
-- Where a weapon points on screen: it turns toward its kept enemy at LOOK.aimTurnDegreesPerSecond.
type Aim = { angle: number?, target: Instance? }

local pools: { [string]: VisualKit.ObjectPool<SpriteKit.Sprite> } = {}
local active: { [string]: Model } = {}
local attacks: { [string]: Attack } = {}
local flights: { [string]: number } = {}
local aims: { [string]: Aim } = {}
-- Enemy positions of the current frame, collected once for all weapons.
local enemyFrame = -1
local enemyCount = 0
local enemyModels: { Instance } = {}
local enemyX: { number } = {}
local enemyZ: { number } = {}

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

local function collectEnemies(frameNumber: number)
	if enemyFrame == frameNumber then
		return
	end
	enemyFrame = frameNumber
	enemyCount = 0
	local folder = workspace:FindFirstChild("LanternfallEnemies")
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		-- pooled enemy models stay in the folder while hidden (EnemyRenderer/SpriteModels)
		if child:IsA("Model") and child:GetAttribute("Hidden") ~= true then
			local body = child:FindFirstChild("Body", true)
			if body and body:IsA("BasePart") then
				enemyCount += 1
				enemyModels[enemyCount] = child
				enemyX[enemyCount] = body.Position.X
				enemyZ[enemyCount] = body.Position.Z
			end
		end
	end
end

-- The enemy this weapon aims at, chosen like the server (WeaponService/WeaponTarget): nearest to the owner within the
-- weapon's range, but the kept one stays while no other is under targetSwitchRatio of its distance.
local function aimTarget(aim: Aim, ownerX: number, ownerZ: number, range: number): (number?, number?)
	local best, bestSquared = 0, math.huge
	local kept, keptSquared = 0, math.huge
	local rangeSquared = range * range
	for index = 1, enemyCount do
		local dx, dz = enemyX[index] - ownerX, enemyZ[index] - ownerZ
		local squared = dx * dx + dz * dz
		if squared <= rangeSquared then
			if squared < bestSquared then
				best, bestSquared = index, squared
			end
			if enemyModels[index] == aim.target then
				kept, keptSquared = index, squared
			end
		end
	end
	if kept > 0 and bestSquared >= keptSquared * TARGETING.targetSwitchRatio ^ 2 then
		best = kept
	end
	if best == 0 then
		aim.target = nil
		return nil, nil
	end
	aim.target = enemyModels[best]
	return enemyX[best], enemyZ[best]
end

-- Turns the weapon from its current angle toward (dx, dz), at most LOOK.aimTurnDegreesPerSecond.
local function turnToward(aim: Aim, dx: number, dz: number, dt: number): (number, number)
	local wanted = math.atan2(dz, dx)
	local current = aim.angle or wanted
	local delta = (wanted - current + math.pi) % TAU - math.pi
	local step = math.rad(LOOK.aimTurnDegreesPerSecond) * dt
	current += math.clamp(delta, -step, step)
	aim.angle = current
	return math.cos(current), math.sin(current)
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
	weapon: { uid: number, id: string, stats: { [string]: number }? },
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

	-- on the floor, far enough out for the picture to stay off the body (the server's anchor is a little closer)
	local radialX, radialZ = WeaponPose.direction(slot, total)
	local radius = RING.clearance + (LOOK.spriteStuds[weapon.id] or 4) * 0.5
	local x, z = owner.position.X + radialX * radius, owner.position.Z + radialZ * radius
	-- Idle weapons point away from the figure; with an enemy in range they turn toward it from where they float.
	local dx, dz = radialX, radialZ
	local aim = aims[key]
	if not aim then
		aim = { angle = nil, target = nil }
		aims[key] = aim
	end
	collectEnemies(frame.number)
	local stats = weapon.stats
	local range = if stats and stats.range then stats.range else math.huge
	local targetX, targetZ = aimTarget(aim, owner.position.X, owner.position.Z, range)
	if targetX and targetZ then
		-- aimed on the floor like the server (from the anchor to the enemy's feet)
		local tx, tz = targetX - x, targetZ - z
		local distance = math.sqrt(tx * tx + tz * tz)
		if distance > 1e-6 then
			dx, dz = tx / distance, tz / distance
		end
	end
	dx, dz = turnToward(aim, dx, dz, frame.dt)
	z -= RING.lift -- drawn at the figure's middle on the screen
	local attack = attacks[key]
	if attack then
		local t = (frame.now - attack.at) / attack.duration
		if t >= 1 then
			attacks[key] = nil
		elseif t >= 0 then
			if attack.dx ~= 0 or attack.dz ~= 0 then
				-- the server's shot direction wins; the weapon turns on from there afterwards, no snap back
				dx, dz = attack.dx, attack.dz
				aim.angle = math.atan2(dz, dx)
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
			aims[key] = nil
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
	table.clear(aims)
	table.clear(enemyModels)
	enemyCount, enemyFrame = 0, -1
end

return HeldModels
