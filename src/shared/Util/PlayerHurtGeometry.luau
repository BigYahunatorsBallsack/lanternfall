--!strict
-- Native player hurt-circle translation, independent of body collision and aiming roots; EnemySim and native projectile services use it.
local Source = require(script.Parent.Parent.Config.PlayerColliders)
local pixel = require(script.Parent.Parent.Config.Stats).range.studsPerPoint
local offsetX, offsetZ = Source.hurt.totalPoints[1] * pixel, Source.hurt.totalPoints[2] * pixel
local Geometry = { radius = Source.hurt.radiusPoints * pixel }
function Geometry.center(x: number, z: number): (number, number)
	return x + offsetX, z + offsetZ
end
return table.freeze(Geometry)
