--!strict
-- Per-weapon pooled projectile visual factory for the Visuals modules: each behavior draws its own shot shape
-- (Config/ShotLooks via ShotShapes: bullets, lasers, arrows, rockets, ...) plus a short muzzle flash for guns.
-- The flight itself follows the server's projectile path; the server decides every hit.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local LOOK = require(Shared:WaitForChild("Config"):WaitForChild("WeaponVisuals"))
local SHOTS = require(Shared:WaitForChild("Config"):WaitForChild("ShotLooks"))
local SPRITES = require(Shared:WaitForChild("Config"):WaitForChild("Sprites"))

local Bursts = require(script.Parent.Parent.Parent.Vfx.Bursts)
local HeldModels = require(script.Parent.HeldModels)
local ShotShapes = require(script.Parent.ShotShapes)
local VisualKit = require(script.Parent.VisualKit)
local WorldSprite = require(Shared:WaitForChild("Util"):WaitForChild("WorldSprite"))

-- `color` is the old single tint, kept for modules that pass no behavior; `behavior` picks the look in ShotLooks.
return function(color: Color3, behavior: string?)
	local look = ShotShapes.lookOf(behavior)
	local SHOT_COLOR = if behavior and SHOTS.byBehavior[behavior] then ShotShapes.color(look.color, color) else color
	local HIT_COLOR = ShotShapes.color(look.hit, SHOT_COLOR)
	local HEIGHT = SHOTS.height -- studs above the floor
	local HIT_SPARKS = SHOTS.hitSparks
	local SPIN = look.spin or 0
	local IS_FLAME = look.shape == "flame"
	local FLICKERS = look.shape == "rocket"
	local FLASH = SHOTS.muzzleFlash
	-- Shots fly on the server's floor path, drawn as far up the screen as the held weapons (HeldModels), so they leave
	-- the visible barrel and keep a straight line instead of bending onto the path.
	local LIFT = SPRITES.heldWeapons.lift

	type ShotParts = { shot: ShotShapes.Shot, core: BasePart, trail: Trail? }

	type Bolt = {
		parts: ShotParts?,
		userId: number,
		x: number,
		z: number,
		dx: number,
		dz: number,
		speed: number,
		range: number,
		at: number, -- server time it was fired
		receivedAt: number,
		startX: number,
		startZ: number,
		stopAt: number?, -- studs; set by the "End" effect
		spinOffset: number,
	}

	type Flash = { parts: ShotShapes.Shot?, x: number, z: number, angleX: number, angleZ: number, endsAt: number }

	-- Pooled sprites stay parented and are hidden through picture.Visible: a BillboardGui that is parented again or
	-- switched back on is drawn a few frames at its old place (engine quirk), which would flash shots at the spot
	-- where the last one ended. A pooled shot is moved first and shown after.
	local freeBolts: { ShotParts } = {}
	local freeFlashes: { ShotShapes.Shot } = {}

	local function show(sprite: WorldSprite.Sprite, folder: Folder, cframe: CFrame)
		local anchor = sprite.anchor :: BasePart
		anchor.CFrame = cframe
		if anchor.Parent ~= folder then
			anchor.Parent = folder
		end
		sprite.picture.Visible = true
	end

	local function acquireBolt(folder: Folder, cframe: CFrame): ShotParts
		local parts = table.remove(freeBolts)
		if not parts then
			local shot = ShotShapes.build(behavior or "Shot", look)
			local core = shot.sprite.anchor :: BasePart
			local trail = if look.trail
				then VisualKit.trail(core, SHOT_COLOR, look.trail, look.trailSeconds or 0.12)
				else nil
			parts = { shot = shot, core = core, trail = trail }
		end
		local created = parts :: ShotParts
		show(created.shot.sprite, folder, cframe)
		if created.trail then
			created.trail:Clear()
			created.trail.Enabled = true
		end
		ShotShapes.setFade(created.shot, 0)
		return created
	end

	local function releaseBolt(parts: ShotParts)
		parts.shot.sprite.picture.Visible = false
		if parts.trail then
			parts.trail.Enabled = false
		end
		table.insert(freeBolts, parts)
	end

	local function acquireFlash(folder: Folder, cframe: CFrame): ShotShapes.Shot
		local shot = table.remove(freeFlashes) or ShotShapes.muzzleFlash()
		show(shot.sprite, folder, cframe)
		return shot
	end

	local function releaseFlash(shot: ShotShapes.Shot)
		shot.sprite.picture.Visible = false
		table.insert(freeFlashes, shot)
	end

	local bolts: { [number]: Bolt } = {} -- by projectile id
	local flashes: { Flash } = {}

	local function remove(id: number, bolt: Bolt)
		if bolt.parts then
			releaseBolt(bolt.parts)
		end
		bolts[id] = nil
	end

	local ShotVisual = {}

	function ShotVisual.effect(effect: Types.WeaponEffect)
		local id = effect.id
		if not id then
			return
		end
		if effect.kind == "Fire" then
			local startX, startZ = HeldModels.projectileOrigin(effect)
			bolts[id] = {
				parts = nil,
				userId = effect.userId,
				x = effect.x or 0,
				z = effect.z or 0,
				dx = effect.dx or 0,
				dz = effect.dz or 0,
				speed = effect.speed or 0,
				range = effect.range or 0,
				at = effect.at,
				receivedAt = workspace:GetServerTimeNow(),
				startX = startX,
				startZ = startZ,
				stopAt = nil,
				spinOffset = (id * 47) % 360,
			}
			if look.muzzle then
				table.insert(flashes, {
					parts = nil,
					x = startX,
					z = startZ,
					angleX = effect.dx or 0,
					angleZ = effect.dz or 0,
					endsAt = workspace:GetServerTimeNow() + FLASH.seconds,
				})
			end
		elseif effect.kind == "End" then
			local bolt = bolts[id]
			if bolt then
				bolt.stopAt = effect.distance
			end
		end
	end

	local function renderFlashes(frame: VisualKit.Frame)
		for index = #flashes, 1, -1 do
			local flash = flashes[index]
			if frame.now >= flash.endsAt then
				if flash.parts then
					releaseFlash(flash.parts)
				end
				table.remove(flashes, index)
				continue
			end
			local grow = 1 - (flash.endsAt - frame.now) / FLASH.seconds
			local reach = FLASH.studs * 0.4
			local position =
				Vector3.new(flash.x + flash.angleX * reach, frame.floorY + HEIGHT, flash.z + flash.angleZ * reach)
			local parts = flash.parts
			if not parts then
				parts = acquireFlash(frame.folder, CFrame.new(position))
				flash.parts = parts
			end
			local shot = parts :: ShotShapes.Shot
			WorldSprite.pose(
				shot.sprite,
				0.8 + 0.4 * grow,
				0.8 + 0.4 * grow,
				WorldSprite.screenAngle(flash.angleX, flash.angleZ)
			)
			ShotShapes.setFade(shot, grow * 0.6)
			frame.move(shot.sprite.anchor :: BasePart, CFrame.new(position))
		end
	end

	function ShotVisual.render(frame: VisualKit.Frame)
		renderFlashes(frame)
		for id, bolt in bolts do
			local blend = math.clamp((frame.now - bolt.receivedAt) / LOOK.projectileCatchupSeconds, 0, 1)
			local lag = math.max(0, bolt.receivedAt - bolt.at)
			local distance = math.max(0, bolt.speed * (frame.now - bolt.at - lag * (1 - blend)))
			local stop = math.min(bolt.range, bolt.stopAt or math.huge)
			if distance >= stop then
				if bolt.stopAt and bolt.parts then
					local share = if bolt.range > 0 and bolt.range < math.huge then stop / bolt.range else 0
					local at = Vector3.new(
						bolt.x + bolt.dx * stop + (bolt.startX - bolt.x) * (1 - share),
						frame.floorY + HEIGHT,
						bolt.z - LIFT + bolt.dz * stop + (bolt.startZ - (bolt.z - LIFT)) * (1 - share)
					)
					Bursts.emit("spark", HIT_COLOR, at, HIT_SPARKS)
				end
				remove(id, bolt)
				continue
			end
			-- One straight line from the barrel on screen to the server path's end at full range: the gap between the
			-- two starts shrinks in step with the distance flown, so the shot never bends (it used to blend over
			-- projectileCatchupSeconds, which curved whenever barrel and server start differed).
			local offsetX, offsetZ = bolt.startX - bolt.x, bolt.startZ - (bolt.z - LIFT)
			local fade = if bolt.range > 0 and bolt.range < math.huge then 1 / bolt.range else 0
			local lineX, lineZ = bolt.dx - offsetX * fade, bolt.dz - offsetZ * fade
			local position =
				Vector3.new(bolt.startX + lineX * distance, frame.floorY + HEIGHT, bolt.startZ + lineZ * distance)
			local cframe = CFrame.lookAt(position, position + Vector3.new(lineX, 0, lineZ))
			local parts = bolt.parts
			if not parts then
				parts = acquireBolt(frame.folder, cframe)
				bolt.parts = parts
			end
			local current = parts :: ShotParts
			local rotation = if SPIN ~= 0
				then (bolt.spinOffset + SPIN * (frame.now - bolt.at)) % 360
				else WorldSprite.screenAngle(lineX, lineZ)
			local scale = 1
			if IS_FLAME then
				local progress = if stop > 0 and stop < math.huge then math.clamp(distance / stop, 0, 1) else 0
				scale = SHOTS.flameStart + (SHOTS.flameEnd - SHOTS.flameStart) * progress
				local from = SHOTS.flameFadeFrom
				ShotShapes.setFade(current.shot, math.clamp((progress - from) / (1 - from), 0, 1))
			elseif FLICKERS then
				ShotShapes.flicker(current.shot, (math.sin((frame.now + id) * 40) + 1) / 2)
			end
			WorldSprite.pose(current.shot.sprite, scale, scale, rotation)
			frame.move(current.core, cframe)
		end
	end

	function ShotVisual.clear()
		for id, bolt in bolts do
			remove(id, bolt)
		end
		for _, flash in flashes do
			if flash.parts then
				releaseFlash(flash.parts)
			end
		end
		table.clear(flashes)
	end

	return ShotVisual
end
