--!strict
-- Sounds and music (Paket 21, DESIGN.md section 14). Read by Audio/Sfx (pooled one-shot effects), AudioController
-- (which game event plays which effect) and MusicController (one looping track per game state, crossfaded).
-- Effects play in the SoundGroup "Effects", music in "Music"; the settings menu sets both volumes (Paket 14).
--
-- Effects: Lanternfall's own soft sounds (made by tools/sfx/generate.py, files in assets/sfx/lf_XX_<name>.ogg). After
-- uploading a file (Creator Hub -> Creations -> Audio, or Studio -> Asset Manager -> Bulk Import) paste its asset id
-- into OWN below; while an id is "" the cue plays a quiet, filtered placeholder that ships with every Roblox client.
-- Music: replace `sound` with "rbxassetid://<id>" (Studio Toolbox -> Audio, right click -> Copy Asset ID); "" = off.
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

-- Asset ids of the own sounds (Paket 21b), as text (big numbers). "" = not uploaded yet: the cue uses its placeholder.
local OWN = {
	blip = "127049480197579", -- lf_01_blip.ogg   XP orbs, fruit
	thock = "123702132059569", -- lf_02_thock.ogg  own hits
	puff = "88819708804506", -- lf_03_puff.ogg   enemy deaths
	pop = "133423609966718", -- lf_04_pop.ogg    ranged shots
	swish = "97672176200337", -- lf_05_swish.ogg  melee swings, dash
	tick = "112460234084175", -- lf_06_tick.ogg   button clicks
	arp = "111686985480244", -- lf_07_arp.ogg    level up
	chime = "112879666967930", -- lf_08_chime.ogg  crate, chest, wave cleared
	oof = "122760404822682", -- lf_09_oof.ogg    the local player hurt
	gong = "79497413641030", -- lf_10_gong.ogg   wave start, boss wave, downed
	thump = "83133602178751", -- lf_11_thump.ogg  pulse, drop
	boom = "78482803081590", -- lf_12_boom.ogg   explosions, elite deaths
	zap = "92202941641501", -- lf_13_zap.ogg    chain lightning
	tink = "123392096949001", -- lf_14_tink.ogg   crits
	warn = "85746059022075", -- lf_15_warn.ogg   boss attack warnings
}

-- Placeholders: only the soft built-in sounds (the metal sword and crash sounds were too harsh), kept low.
local PING = "rbxasset://sounds/electronicpingshort.wav"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local AIR = "rbxasset://sounds/action_jump.mp3"
local CLICK = "rbxasset://sounds/clickfast.wav"

type Spec = { sound: string, volume: number, pitch: number }

local function own(name: string, volume: number, pitch: number): Spec
	local id = (OWN :: { [string]: string })[name]
	return { sound = if id and id ~= "" then `rbxassetid://{id}` else "", volume = volume, pitch = pitch }
end

local function placeholder(sound: string, volume: number, pitch: number): Spec
	return { sound = sound, volume = volume, pitch = pitch }
end

-- The own sound once it has an id, the placeholder until then.
local function cue(main: Spec, fallback: Spec, minInterval: number, voices: number, pitchVariance: number?): Cue
	local spec = if main.sound ~= "" then main else fallback
	return table.freeze({
		sound = spec.sound,
		volume = spec.volume,
		pitch = spec.pitch,
		pitchVariance = pitchVariance or 0.06,
		minInterval = minInterval,
		voices = voices,
	})
end

return table.freeze({
	-- Paket 24: the upload state of the own sounds for the launch check (Util/LaunchRules); "" = not uploaded
	ownSounds = table.freeze(table.clone(OWN)) :: { [string]: string },
	-- Effects heard at a world position get quieter with the distance to the local player's character: full volume
	-- up to `fullRadius` studs, silent from `hearRadius` on (the 50 degree camera shows roughly 80 studs around).
	fullRadius = 30,
	hearRadius = 110,
	otherPlayersVolume = 0.4, -- weapons of team mates play this much quieter than the own ones

	-- Tone shaping on the SoundGroup "Effects" (Audio/Sfx): an equalizer takes the edge off the highs and a compressor
	-- keeps crowds of hits and deaths from stacking up into a wall of noise. Gains in dB; `enabled = false` = raw.
	effectsBus = table.freeze({
		enabled = true,
		lowGain = 0,
		midGain = -2,
		highGain = -9,
		threshold = -20, -- dB where the compressor starts
		ratio = 3,
		attack = 0.005,
		release = 0.15,
	}),

	cues = table.freeze({
		-- interface
		uiClick = cue(own("tick", 0.3, 1), placeholder(CLICK, 0.18, 0.9), 0.04, 2),
		-- the own and team mates' weapons, by WeaponEffect kind (see weaponKinds below)
		shoot = cue(own("pop", 0.16, 1), placeholder(THUD, 0.1, 2.4), 0.06, 4, 0.1),
		slash = cue(own("swish", 0.2, 1.05), placeholder(AIR, 0.12, 1.4), 0.07, 3, 0.1),
		pulse = cue(own("thump", 0.3, 1), placeholder(THUD, 0.22, 0.7), 0.12, 2),
		zap = cue(own("zap", 0.14, 1), placeholder(PING, 0.05, 0.6), 0.08, 3),
		blast = cue(own("boom", 0.28, 1), placeholder(THUD, 0.25, 0.5), 0.1, 3),
		drop = cue(own("thump", 0.22, 1.3), placeholder(THUD, 0.16, 1.2), 0.1, 2),
		-- the own hits (DamageNumbers) and kills (EnemyRenderer)
		hit = cue(own("thock", 0.16, 1), placeholder(THUD, 0.1, 1.8), 0.08, 3, 0.1),
		crit = cue(own("tink", 0.18, 1), placeholder(PING, 0.05, 1.1), 0.1, 2),
		enemyDeath = cue(own("puff", 0.18, 1), placeholder(THUD, 0.12, 1.3), 0.05, 4, 0.12),
		eliteDeath = cue(own("boom", 0.4, 0.8), placeholder(THUD, 0.3, 0.6), 0.2, 2),
		-- loot
		orb = cue(own("blip", 0.12, 1), placeholder(PING, 0.05, 1), 0.045, 3, 0.02),
		fruit = cue(own("blip", 0.2, 0.75), placeholder(PING, 0.08, 0.8), 0.1, 2),
		crate = cue(own("chime", 0.22, 1.2), placeholder(PING, 0.1, 0.7), 0.15, 2),
		chest = cue(own("chime", 0.3, 1), placeholder(PING, 0.12, 0.6), 0.2, 1),
		-- the local player
		hurt = cue(own("oof", 0.3, 1), placeholder(THUD, 0.25, 0.8), 0.15, 2),
		down = cue(own("gong", 0.35, 0.75), placeholder(THUD, 0.35, 0.45), 0.5, 1),
		dash = cue(own("swish", 0.2, 1.35), placeholder(AIR, 0.15, 1.1), 0.1, 2),
		levelUp = cue(own("arp", 0.28, 1), placeholder(PING, 0.12, 0.8), 0.3, 1, 0),
		-- run flow
		waveStart = cue(own("gong", 0.3, 1), placeholder(THUD, 0.3, 0.55), 1, 1, 0),
		waveEnd = cue(own("chime", 0.3, 0.8), placeholder(PING, 0.12, 0.55), 1, 1, 0),
		bossRoar = cue(own("gong", 0.45, 0.5), placeholder(THUD, 0.45, 0.35), 1, 1, 0),
		telegraph = cue(own("warn", 0.18, 1), placeholder(PING, 0.06, 0.45), 0.3, 2),
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
