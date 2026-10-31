--!strict
-- Pooled one-shot sound effects (Paket 21, DESIGN.md section 14). Each cue of Config.Audio.cues gets a few Sound copies
-- in the SoundGroup "Effects" (its volume comes from the settings menu); a play restarts the next free copy with a
-- slightly varied pitch, skips plays that come faster than the cue's minInterval and fades effects with the distance
-- to the local player's character. Sounds are 2D: the top-down camera is far from the action, so Roblox's 3D falloff
-- would make everything quiet. The "Effects" group gets an equalizer and a compressor (Config.Audio.effectsBus) so the
-- mix stays soft. Used by AudioController, Widgets.button and EnemyRenderer/DeathBursts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))

local FOLDER_NAME = "LanternfallSfx"

type Pool = {
	sounds: { Sound },
	nextIndex: number,
	lastAt: number,
}

local Sfx = {}

local pools: { [string]: Pool } = {}
local played: { [string]: number } = {} -- plays per cue since the start, for tests and the debug panel
local folder: Folder? = nil
local random = Random.new()

-- The SoundGroup the settings menu controls (SettingsController finds or makes the same one).
function Sfx.group(name: string): SoundGroup
	local group = SoundService:FindFirstChild(name)
	if not (group and group:IsA("SoundGroup")) then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	return group :: SoundGroup
end

local function getFolder(): Folder
	local current = folder
	if current then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = SoundService
	folder = created
	return created
end

-- Equalizer + compressor on the effects group (Paket 21b); added once, kept if they already exist.
local function shapeBus(group: SoundGroup)
	local bus = Config.Audio.effectsBus
	if not bus.enabled or group:FindFirstChild("LanternfallEq") then
		return
	end
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "LanternfallEq"
	eq.LowGain = bus.lowGain
	eq.MidGain = bus.midGain
	eq.HighGain = bus.highGain
	eq.MidRange = NumberRange.new(bus.midRange[1], bus.midRange[2])
	eq.Priority = 2
	eq.Parent = group
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Name = "LanternfallCompressor"
	compressor.Threshold = bus.threshold
	compressor.Ratio = bus.ratio
	compressor.Attack = bus.attack
	compressor.Release = bus.release
	compressor.Priority = 1
	compressor.Parent = group
end

local function poolOf(cueId: string, cue: AudioConfig.Cue): Pool
	local pool = pools[cueId]
	if pool then
		return pool
	end
	local sounds = {}
	local group = Sfx.group("Effects")
	shapeBus(group)
	for index = 1, math.max(1, cue.voices) do
		local sound = Instance.new("Sound")
		sound.Name = `{cueId}{index}`
		sound.SoundId = cue.sound
		sound.Volume = cue.volume
		sound.Looped = false
		sound.SoundGroup = group
		sound.Parent = getFolder()
		table.insert(sounds, sound)
	end
	local created = { sounds = sounds, nextIndex = 1, lastAt = -math.huge }
	pools[cueId] = created
	return created
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- 1 near the local character, 0 out of earshot; 1 when there is no position or no character.
local function distanceFactor(position: Vector3?): number
	if not position then
		return 1
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return 1
	end
	local offset = root.Position - position
	local distance = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	local full, hear = Config.Audio.fullRadius, Config.Audio.hearRadius
	if distance <= full then
		return 1
	end
	return math.clamp(1 - (distance - full) / math.max(hear - full, 1), 0, 1)
end

-- Plays a cue of Config.Audio.cues. `position` (world) makes it quieter far away, `volumeScale` and `pitchScale`
-- change this one play. Returns whether it played (false: unknown or switched-off cue, too soon, out of earshot).
function Sfx.play(cueId: string, position: Vector3?, volumeScale: number?, pitchScale: number?): boolean
	local cue = Config.Audio.cues[cueId]
	if not cue or cue.sound == "" then
		return false
	end
	local factor = distanceFactor(position) * (volumeScale or 1)
	if factor <= 0 then
		return false
	end
	local pool = poolOf(cueId, cue)
	local at = now()
	if at - pool.lastAt < cue.minInterval then
		return false
	end
	pool.lastAt = at
	local sound = pool.sounds[pool.nextIndex]
	pool.nextIndex = pool.nextIndex % #pool.sounds + 1
	local variance = cue.pitchVariance
	sound.Volume = cue.volume * factor
	sound.PlaybackSpeed = cue.pitch * (pitchScale or 1) * (1 + random:NextNumber(-variance, variance))
	sound.TimePosition = 0
	sound:Play()
	played[cueId] = (played[cueId] or 0) + 1
	return true
end

-- How often a cue played since the client started.
function Sfx.getPlayed(cueId: string): number
	return played[cueId] or 0
end

return Sfx
