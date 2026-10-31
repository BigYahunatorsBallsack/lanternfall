--!strict
-- Background music (Paket 21, DESIGN.md section 14): one looping track per game state (lobby, fighting wave, shop,
-- boss wave, results), crossfaded when the state changes, plus a one-shot victory or defeat stinger when a run ends
-- (the results track ducks under it). Tracks come from Config.Audio.music and play in the SoundGroup "Music", whose
-- volume the settings menu sets. A track with an empty sound stays silent. Follows RunStateController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local RunStateController = require(script.Parent.RunStateController)

local FOLDER_NAME = "LanternfallMusic"

export type TrackName = "lobby" | "run" | "shop" | "boss" | "results"

local MusicController = {}

local sounds: { [string]: Sound } = {}
local current: string? = nil
local stingerFor: number? = nil -- run start time whose stinger already played
local folder: Folder? = nil

local function getFolder(): Folder
	local existing = folder
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = SoundService
	folder = created
	return created
end

-- The Sound of a track, made on first use; nil when the track has no sound.
local function soundOf(name: string): Sound?
	local track = Config.Audio.music[name]
	if not track or track.sound == "" then
		return nil
	end
	local existing = sounds[name]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = track.sound
	sound.Looped = track.looped
	sound.Volume = 0
	sound.SoundGroup = Sfx.group("Music")
	sound.Parent = getFolder()
	sounds[name] = sound
	return sound
end

local function fade(sound: Sound, volume: number, seconds: number)
	TweenService:Create(sound, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Volume = volume,
	}):Play()
end

-- Which looping track the local player should hear now.
function MusicController.wanted(): TrackName
	local view = RunStateController.getView()
	local state = RunStateController.get()
	if view == "Run" and state then
		if state.phase == "Shop" then
			return "shop"
		elseif state.phase == "Boss" then
			return "boss"
		end
		return "run"
	elseif view == "Results" then
		return "results"
	end
	return "lobby"
end

-- The track playing (or fading in) now; nil before the first state arrives.
function MusicController.getCurrent(): string?
	return current
end

local function switchTo(name: string)
	if name == current then
		return
	end
	local seconds = Config.Audio.fadeSeconds
	local old = current and sounds[current]
	if old then
		local fading = old
		fade(fading, 0, seconds)
		task.delay(seconds, function()
			if current ~= fading.Name then
				fading:Stop()
			end
		end)
	end
	current = name
	local sound = soundOf(name)
	if sound then
		if not sound.IsPlaying then
			sound.TimePosition = 0
			sound:Play()
		end
		fade(sound, Config.Audio.music[name].volume, seconds)
	end
end

-- Victory or defeat once per run, the results track ducked under it for the stinger's length.
local function playStinger(state: Types.RunState)
	local results = state.results
	if not (results and state.runStartedAt) or stingerFor == state.runStartedAt then
		return
	end
	stingerFor = state.runStartedAt
	local name = if results.outcome == "Victory" then "victory" elseif results.outcome == "Defeat" then "defeat" else nil
	local stinger = name and soundOf(name)
	if not (name and stinger) then
		return
	end
	stinger.Volume = Config.Audio.music[name].volume
	stinger.TimePosition = 0
	stinger:Play()
	local background = current and sounds[current]
	if background then
		local trackName = current :: string
		background.Volume = Config.Audio.music[trackName].volume * Config.Audio.stingerDuck
		local length = if stinger.TimeLength > 0 then stinger.TimeLength else Config.Audio.fadeSeconds * 2
		task.delay(length, function()
			if current == trackName then
				fade(background, Config.Audio.music[trackName].volume, Config.Audio.fadeSeconds)
			end
		end)
	end
end

local function refresh()
	switchTo(MusicController.wanted())
	local state = RunStateController.get()
	if state and state.phase == "Ended" and RunStateController.getView() == "Results" then
		playStinger(state)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function MusicController.init()
	Sfx.group("Music")
	RunStateController.Changed:Connect(refresh)
end

return MusicController
