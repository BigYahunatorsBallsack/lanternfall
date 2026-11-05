--!strict
-- Draws each approved blade cutout at its matching server hit orbit position.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Orbit = require(Shared:WaitForChild("Util"):WaitForChild("Orbit"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local SpriteKit = require(script.Parent.Parent.SpriteKit)
local VisualKit = require(script.Parent.Parent.VisualKit)

type Set = { sprites: { SpriteKit.Sprite }, seen: number }

local BLADE_IMAGES = {
	"rbxassetid://82762074237036",
	"rbxassetid://111823063839810",
}

local pool = VisualKit.objectPool(function(): SpriteKit.Sprite
	return SpriteKit.create("OrbitBlades", 1, "OrbitBlades")
end, function(sprite: SpriteKit.Sprite): { BasePart }
	return { sprite.anchor }
end)

local sets: { [string]: Set } = {}
local OrbitBlades = {}

local function release(key: string, set: Set)
	for _, sprite in set.sprites do
		pool:release(sprite)
	end
	sets[key] = nil
end

function OrbitBlades.renderWeapon(owner: VisualKit.Owner, weapon: Types.WeaponInfo, frame: VisualKit.Frame)
	local key = `{owner.userId}:{weapon.uid}`
	local set = sets[key]
	if not set then
		set = { sprites = {}, seen = 0 }
		sets[key] = set
	end
	set.seen = frame.number
	local stats = weapon.stats
	local count = math.max(0, math.floor(stats.count))
	while #set.sprites < count do
		table.insert(set.sprites, pool:acquire(frame.folder))
	end
	while #set.sprites > count do
		pool:release(table.remove(set.sprites) :: SpriteKit.Sprite)
	end
	for index, sprite in set.sprites do
		local angle = Orbit.bladeAngle(stats.rotationSpeed, weapon.addedAt, frame.now, index, count)
		local gui = sprite.picture.Parent :: BillboardGui
		gui.Size = UDim2.fromScale(Config.WeaponVisuals.orbitBladeStuds, Config.WeaponVisuals.orbitBladeStuds)
		sprite.picture.Image = BLADE_IMAGES[(index - 1) % #BLADE_IMAGES + 1]
		sprite.picture.Rotation = math.deg(angle)
		local distance = stats.radius - Config.WeaponVisuals.orbitBladeStuds / 2
		frame.move(
			sprite.anchor,
			CFrame.new(
				owner.position.X + math.cos(angle) * distance,
				frame.floorY + Config.WeaponVisuals.holdHeight,
				owner.position.Z + math.sin(angle) * distance
			)
		)
	end
end

function OrbitBlades.render(frame: VisualKit.Frame)
	for key, set in sets do
		if set.seen ~= frame.number then
			release(key, set)
		end
	end
end

function OrbitBlades.clear()
	for key, set in sets do
		release(key, set)
	end
end

return OrbitBlades
