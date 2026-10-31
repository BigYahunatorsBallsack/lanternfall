--!strict
-- Where enemies die (DESIGN.md section 14, hit feedback), used by EnemyRenderer when an enemy drops out of the
-- snapshots: a burst of sparks in the color of its eyes and a few soft soul wisps that rise from the body; elites
-- burst much bigger and throw out embers. Particles come from Vfx/Bursts; counts from Config.Feedback.deathBursts
-- (fewer at Low graphics, GraphicsController). Since Paket 21 each death also plays a sound (Audio/Sfx); since Paket 22
-- deaths off the screen only play the sound.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Bursts = require(script.Parent.Parent.Parent.Vfx.Bursts)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local GraphicsController = require(script.Parent.Parent.GraphicsController)

local HEIGHT = 1.5 -- studs above the floor
local SOULS_PER_SPARKS = 1 / 3 -- soul wisps per spark
local ELITE_SCALE = 2
local EMBER_COLOR = Color3.fromRGB(255, 206, 92)

local DeathBursts = {}

-- A burst of `color` at floor point (x, y, z); `big` for elites. `onScreen` false (off the screen) skips the particles.
function DeathBursts.burst(x: number, y: number, z: number, color: Color3, big: boolean, onScreen: boolean?)
	local position = Vector3.new(x, y + HEIGHT, z)
	Sfx.play(if big then "eliteDeath" else "enemyDeath", position) -- Paket 21
	local settings = Config.Feedback.deathBursts
	if not settings.enabled or onScreen == false then
		return
	end
	local low = GraphicsController.isLow()
	local count = if big then settings.eliteParticles elseif low then settings.particlesTouch else settings.particles
	local scale = if big then ELITE_SCALE else 1
	Bursts.emit("spark", color, position, count, scale)
	Bursts.emit("soul", color, position, math.max(1, math.floor(count * SOULS_PER_SPARKS)), scale)
	if big then
		Bursts.emit("ember", EMBER_COLOR, position, count, scale)
	end
end

return DeathBursts
