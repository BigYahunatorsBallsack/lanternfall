--!strict
-- Sounds and music (Paket 21, DESIGN.md section 14). Read by Audio/Sfx (pooled one-shot effects), AudioController
-- (which game event plays which effect) and MusicController (one looping track per game state, crossfaded).
-- Effects play in the SoundGroup "Effects", music in "Music"; the settings menu sets both volumes (Paket 14).
--
-- How to swap a sound: replace `sound` with "rbxassetid://<id>" (Creator Hub or Studio Toolbox -> Audio, right click ->
-- Copy Asset ID). "" switches a sound or track off. The effects start with sounds that ship with every Roblox client
-- ("rbxasset://sounds/..."), so they work without uploads; music starts empty because Roblox ships no music.
--   volume  0..1 before the Effects/Music group volume
--   pitch   playback speed (1 = as recorded; 2 = an octave higher and twice as short)
--   pitchVariance  each play picks a speed up to this share above or below `pitch` (so repeats do not sound robotic)
--   minInterval  seconds; plays closer together than this are skipped (hits and deaths come in crowds)
--   voices  copies that may sound at once; the oldest restarts when all are busy

export type Cue = {
	sound: string,
	volume: number,
	pitch: number,
	pitchVariance: number,
	minInterval: number,
	voices: number,
}

export type Track = {
	sound: string,
	volume: number,
	looped: boolean,
}

local PING = "rbxasset://sounds/electronicpingshort.wav"
local SLASH = "rbxasset://sounds/swordslash.wav"
local LUNGE = "rbxasset://sounds/swordlunge.wav"
local UNSHEATH = "rbxasset://sounds/unsheath.wav"
local BOOM = "rbxasset://sounds/collide.wav"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local CLICK = "rbxasset://sounds/clickfast.wav"

local function cue(sound: string, volume: number, pitch: number, minInterval: number, voices: number): Cue
	return table.freeze({
		sound = sound,
		volume = volume,
		pitch = pitch,
		pitchVariance = 0.08,
		minInterval = minInterval,
		voices = voices,
	})
end

return table.freeze({
	-- Effects heard at a world position get quieter with the distance to the local player's character: full volume
	-- up to `fullRadius` studs, silent from `hearRadius` on (the 50 degree camera shows roughly 80 studs around).
	fullRadius = 30,
	hearRadius = 110,
	otherPlayersVolume = 0.45, -- weapons of team mates play this much quieter than the own ones

	cues = table.freeze({
		-- interface
		uiClick = cue(CLICK, 0.35, 1, 0.04, 2),
		-- the own and team mates' weapons, by WeaponEffect kind (see weaponKinds below)
		shoot = cue(PING, 0.12, 2.2, 0.06, 4),
		slash = cue(SLASH, 0.3, 1.15, 0.07, 3),
		pulse = cue(THUD, 0.45, 0.6, 0.12, 2),
		zap = cue(PING, 0.18, 0.7, 0.08, 3),
		blast = cue(BOOM, 0.35, 1.1, 0.1, 3),
		drop = cue(THUD, 0.3, 1.4, 0.1, 2),
		-- the own hits (DamageNumbers) and kills (EnemyRenderer)
		hit = cue(THUD, 0.25, 1.9, 0.08, 3),
		crit = cue(SLASH, 0.22, 1.7, 0.1, 2),
		enemyDeath = cue(THUD, 0.3, 1.2, 0.05, 4),
		eliteDeath = cue(BOOM, 0.6, 0.7, 0.2, 2),
		-- loot
		orb = cue(PING, 0.16, 1.35, 0.045, 3),
		fruit = cue(PING, 0.3, 1, 0.1, 2),
		crate = cue(UNSHEATH, 0.4, 1.1, 0.15, 2),
		chest = cue(UNSHEATH, 0.5, 0.8, 0.2, 1),
		-- the local player
		hurt = cue(LUNGE, 0.4, 0.55, 0.15, 2),
		down = cue(BOOM, 0.6, 0.5, 0.5, 1),
		dash = cue(LUNGE, 0.35, 1.1, 0.1, 2),
		levelUp = cue(PING, 0.45, 0.8, 0.3, 1),
		-- run flow
		waveStart = cue(UNSHEATH, 0.5, 0.6, 1, 1),
		waveEnd = cue(PING, 0.4, 0.55, 1, 1),
		bossRoar = cue(BOOM, 0.8, 0.35, 1, 1),
		telegraph = cue(PING, 0.25, 0.4, 0.3, 2),
	}) :: { [string]: Cue },

	-- WeaponEffect.kind (WeaponService) -> cue. Kinds not listed (End, Burn) make no sound.
	weaponKinds = table.freeze({
		Fire = "shoot",
		Strike = "slash",
		Pulse = "pulse",
		Chain = "zap",
		Blast = "blast",
		Explosion = "blast",
		Drop = "drop",
	}) :: { [string]: string },

	-- XP orbs picked up in quick succession climb in pitch, like a combo; it resets after `resetSeconds` without one.
	orbCombo = table.freeze({
		step = 0.03, -- pitch added per orb
		maxSteps = 15,
		resetSeconds = 0.6,
	}),

	-- One looping track per state (MusicController): lobby, a fighting wave, the shop, the boss wave (wave 20 and
	-- endless boss waves) and the results screen; `victory`/`defeat` play once when a run ends, over the results
	-- track. All "" until the owner picks music in the Creator Store (see the comment at the top).
	music = table.freeze({
		lobby = table.freeze({ sound = "", volume = 0.5, looped = true }),
		run = table.freeze({ sound = "", volume = 0.5, looped = true }),
		shop = table.freeze({ sound = "", volume = 0.45, looped = true }),
		boss = table.freeze({ sound = "", volume = 0.6, looped = true }),
		results = table.freeze({ sound = "", volume = 0.4, looped = true }),
		victory = table.freeze({ sound = "", volume = 0.7, looped = false }),
		defeat = table.freeze({ sound = "", volume = 0.7, looped = false }),
	}) :: { [string]: Track },
	fadeSeconds = 1.5, -- crossfade between two tracks
	stingerDuck = 0.3, -- the results track plays at this share while a victory/defeat stinger sounds
})
