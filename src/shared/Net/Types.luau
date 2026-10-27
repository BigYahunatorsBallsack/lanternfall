--!strict
-- Shared payload types for server-to-client state. Produced by RunDirector (RunFlow snapshot),
-- read by the client controllers. Times are server times from workspace:GetServerTimeNow().

export type Phase = "Lobby" | "Countdown" | "Running" | "Shop" | "Boss" | "Ended"
export type ParticipantState = "Alive" | "Down" | "Out"
export type Outcome = "Victory" | "Defeat" | "Abandoned"

-- One entry per player in the server.
export type PlayerInfo = {
	userId: number,
	name: string,
	classId: string,
	ready: boolean, -- wants to join the next run
	participant: boolean, -- part of the current run
	state: ParticipantState?, -- only for participants
	shopReady: boolean?, -- only for participants: pressed Ready in the current shop
}

export type ResultEntry = {
	userId: number,
	name: string,
	classId: string,
	state: ParticipantState,
}

export type Results = {
	outcome: Outcome,
	survivedSeconds: number,
	difficulty: string,
	players: { ResultEntry },
}

export type RunState = {
	version: number,
	phase: Phase,
	difficulty: string,
	phaseEndsAt: number?, -- Countdown, Shop and Ended
	runStartedAt: number?, -- Running, Shop, Boss and Ended
	runEndedAt: number?, -- Ended
	wave: number, -- current wave (the one that just ended while in the Shop), 0 outside a run
	pausedSeconds: number, -- shop time so far; fighting time = (pausedAt or runEndedAt or now) - runStartedAt - this
	pausedAt: number?, -- Shop: when the clock stopped
	players: { PlayerInfo },
	results: Results?, -- Ended
}

-- HP and dash state of one player (CombatService -> PlayerStateController), sent to everyone on change.
export type PlayerVitals = {
	userId: number,
	hp: number,
	maxHp: number,
	dashReadyAt: number, -- server time when the next dash is allowed
	invulnerableUntil: number, -- server time
	choosing: boolean, -- picking a level-up card (frozen and invulnerable only with Run.levelUp.freezeWhileChoosing)
}

-- One weapon of a player's loadout (WeaponService -> LoadoutController).
export type WeaponInfo = {
	id: string, -- key in Config.Weapons
	level: number,
	evolution: string?, -- key in Config.Evolutions once evolved (WP8)
	addedAt: number, -- server time; spinning weapons count their angle from here (Util/Orbit)
	stats: { [string]: number }, -- effective stats: level, evolution and the owner's bonuses applied
}

-- The weapons of one player, sent to everyone on change. Empty outside a run.
export type Loadout = {
	userId: number,
	weapons: { WeaponInfo },
	paused: boolean, -- weapons switched off with the debug button
}

-- One weapon event for the visuals (WeaponService -> WeaponRenderer), batched per simulation step and sent to
-- the run's participants. Which optional fields are set depends on the weapon's behavior.
export type WeaponEffect = {
	weapon: string, -- behavior name; picks the visual in WeaponRenderer/Visuals
	userId: number, -- owner
	kind: string, -- e.g. "Fire", "End", "Pulse", "Chain", "Drop", "Blast"
	at: number, -- server time of the simulation step
	id: number?, -- projectile id, unique within the run
	x: number?, -- world position on the floor
	z: number?,
	dx: number?, -- unit direction
	dz: number?,
	speed: number?, -- studs/s
	range: number?, -- studs
	radius: number?, -- studs
	distance: number?, -- studs a projectile flew before it ended
	duration: number?, -- seconds something stays on the floor
	points: { number }?, -- floor positions as x1, z1, x2, z2, ... (e.g. the enemies a chain jumped over)
}

-- One enemy projectile (EnemySim -> EnemyShotRenderer). It flies straight from x/z at `speed` from server time `at`
-- and fades at `range`, unless an "ended" entry stops it earlier.
export type EnemyShot = {
	id: number, -- unique within the run
	x: number,
	z: number,
	dx: number, -- unit direction
	dz: number,
	speed: number, -- studs/s
	range: number, -- studs
	at: number, -- server time it was fired
}

-- Enemy projectile changes since the last snapshot, sent to the participants.
export type EnemyShotEvents = {
	reset: boolean?, -- drop every shot first (run start and end)
	fired: { EnemyShot },
	ended: { number }, -- flat: id, distance flown, for shots that hit a player or an obstacle
}

-- An elite chest on the floor (LootService -> ChestController).
export type ChestInfo = {
	id: number,
	x: number,
	z: number,
}

-- What a chest gave one player (DESIGN.md section 8): an evolution if they may take one, else one more level of an
-- owned weapon or passive, else a reward ("Heal").
export type ChestReward = {
	kind: "Evolution" | "Weapon" | "Passive" | "Reward",
	itemId: string, -- key in Config.Evolutions, Config.Weapons or Config.Passives, or the reward id
	level: number, -- item level after the chest (0 for evolutions and rewards)
}

-- A chest was opened, sent to the participants.
export type ChestOpened = {
	id: number,
	x: number,
	z: number,
	rewards: { { userId: number, reward: ChestReward } }, -- every living participant close enough
}

-- Team level and XP towards the next level (ExperienceService -> ProgressController), to everyone on change.
export type TeamProgress = {
	level: number,
	xp: number,
	needed: number, -- XP for the next level with the current player count
}

-- XP orb changes (ExperienceService -> XpOrbRenderer), batched per simulation step and sent to the participants.
export type XpOrbEvents = {
	reset: boolean?, -- drop every orb first (run start and end, full sync)
	orbs: { number }, -- flat: id, x, z, value for every orb that appeared or grew
	collected: { number }, -- flat: id, userId for every orb a player picked up
}

-- One level-up card (UpgradeService -> LevelUpController). Texts come from Util/UpgradeText on the client.
export type UpgradeCard = {
	id: string, -- what the client sends back with ChooseUpgrade, e.g. "Weapon:SparkBolt"
	kind: "Weapon" | "Passive" | "Reward",
	itemId: string, -- key in Config.Weapons or Config.Passives; "Heal" or "Embers" for rewards
	level: number, -- item level after picking the card (1 = new)
	isNew: boolean,
}

-- The local player's level-up choice, sent when it opens, changes (reroll) or closes.
export type LevelUpOffer = {
	open: boolean,
	level: number, -- team level this choice belongs to
	cards: { UpgradeCard },
	expiresAt: number, -- server time; the first card is picked automatically then
	rerolls: number, -- free rerolls left in this run
	pending: number, -- further choices waiting after this one (closed: choices waiting for the end of the wave)
}

-- One thing for sale in the shop: a new weapon or passive, or one more level of an owned one.
export type ShopOffer = {
	id: string, -- what the client sends back with BuyShopOffer, e.g. "1:Weapon:SparkBolt"
	kind: "Weapon" | "Passive",
	itemId: string, -- key in Config.Weapons or Config.Passives
	level: number, -- item level after buying (1 = new)
	isNew: boolean,
	price: number, -- Shards
	sold: boolean, -- bought in this shop; the slot stays empty
}

-- The local player's Shards and shop (ShopService -> ShopController, HUD), sent on every change.
export type ShopState = {
	shards: number,
	open: boolean, -- shop phase between two waves
	wave: number, -- the wave that just ended (prices are based on it)
	offers: { ShopOffer },
	rerollPrice: number,
}

export type PassiveInfo = {
	id: string, -- key in Config.Passives
	level: number,
}

-- The passives of one player (UpgradeService -> ProgressController), to everyone on change. Empty outside a run.
export type PassiveLoadout = {
	userId: number,
	passives: { PassiveInfo },
}

-- One player's line on the results screen (RunStatsService -> ResultsController).
export type RunSummaryPlayer = {
	userId: number,
	kills: number, -- by the player's weapons
	damageDealt: number, -- by the player's weapons
	damageTaken: number,
	downs: number,
}

-- Run statistics, sent to the participants right after the run ended.
export type RunSummary = {
	teamLevel: number,
	kills: number, -- every enemy the team killed
	players: { RunSummaryPlayer },
}

-- Server measurements for the admin stats panel (AdminService -> DebugController).
export type DebugStats = {
	enemies: number, -- alive right now
	cap: number, -- alive cap for the current player count
	spawnRate: number, -- enemies per second at the current minute
	spawning: boolean, -- false outside a run, in the boss phase or when paused by the debug button
	paused: boolean,
	stepMilliseconds: number, -- average server time per simulation step over the last second
	stepMaxMilliseconds: number, -- slowest step in the last second
	stepsPerSecond: number,
	sentKilobytesPerSecond: number, -- enemy snapshots sent to each player
	shots: number, -- enemy projectiles in flight
}

return {}
