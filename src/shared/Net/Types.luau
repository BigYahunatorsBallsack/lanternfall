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
	uid: number, -- names this copy (a player may carry the same weapon several times since B3)
	id: string, -- key in Config.Weapons
	tier: number, -- 1..Config.Player.maxWeaponTier (Brotato's tiers I-IV since B3)
	evolution: string?, -- key in Config.Evolutions once evolved (WP8)
	addedAt: number, -- server time; spinning weapons count their angle from here (Util/Orbit)
	stats: { [string]: number }, -- effective stats: tier, evolution and the owner's bonuses applied
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
	angle: number?, -- B7 Strike: sweep arc in degrees; zero is a thrust
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

-- What a chest gave one player (DESIGN.md section 8): an evolution if they may take one, else an item (since B2),
-- else a reward ("Heal").
export type ChestReward = {
	kind: "Evolution" | "Item" | "Reward",
	itemId: string, -- key in Config.Evolutions or Config.Items, or the reward id
	level: number, -- items: how many the player owns now; 0 for evolutions and rewards
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

-- One level-up card (UpgradeService -> LevelUpController): a stat upgrade of one rarity tier (Brotato direction
-- since B2). Texts come from Util/UpgradeText on the client.
export type UpgradeCard = {
	id: string, -- what the client sends back with ChooseUpgrade, e.g. "Stat:damage:2"
	stat: string, -- key in Config.Stats
	tier: number, -- 1..4 (Config.Items.tiers)
	amount: number, -- added to the stat
}

-- The local player's level-up choice, sent when it opens, changes (reroll) or closes.
export type LevelUpOffer = {
	open: boolean,
	level: number, -- team level this choice belongs to
	cards: { UpgradeCard },
	expiresAt: number, -- server time; the first card is picked automatically then
	rerollPrice: number, -- Shards for new cards
	pending: number, -- further choices waiting after this one (closed: choices waiting for the end of the wave)
}

-- One thing for sale in the shop: a weapon of a tier or an item (DESIGN.md section 3).
export type ShopOffer = {
	id: string, -- what the client sends back with BuyShopOffer and LockShopOffer, e.g. "1:Item:Focus"
	kind: "Weapon" | "Item",
	itemId: string, -- key in Config.Weapons or Config.Items
	tier: number, -- rarity 1..4 (Config.Items.tiers); weapons: their tier I-IV
	count: number, -- items: how many the player owns after buying; weapons: copies of it the player carries now
	isNew: boolean, -- the player has none of it
	price: number, -- Shards, with the player's Item Prices factor (since B4)
	priceWave: number, -- the wave the price is based on; a locked offer keeps the wave it was rolled in
	sold: boolean, -- bought in this shop; the slot stays empty
	locked: boolean, -- stays through rerolls and into the next shop
	merges: boolean, -- weapons: every slot is full, buying merges it into an owned copy of the same tier
	blocked: boolean, -- cannot be bought right now (weapon slots full without a copy to merge with)
}

-- One weapon of the local player as the shop shows it (sell and merge buttons).
export type ShopWeapon = {
	uid: number,
	id: string, -- key in Config.Weapons
	tier: number,
	evolution: string?,
	sellPrice: number, -- Shards for selling it now
	canMerge: boolean, -- another copy of the same tier is there to merge with
}

-- The local player's Shards and shop (ShopService -> ShopController, HUD), sent on every change.
export type ShopState = {
	shards: number,
	open: boolean, -- shop phase between two waves
	wave: number, -- the wave that just ended (prices are based on it)
	offers: { ShopOffer },
	rerollPrice: number, -- 0 while a free reroll is waiting
	freeRerolls: number, -- free rerolls earned by purchases (Config.Shop.freeRerollAfterBuys)
	weapons: { ShopWeapon }, -- in slot order
	maxWeapons: number,
}

export type ItemInfo = {
	id: string, -- key in Config.Items
	count: number,
}

-- The items of one player (StatService -> ProgressController), to everyone on change. Empty outside a run.
export type ItemLoadout = {
	userId: number,
	items: { ItemInfo },
}

-- The local player's stats (StatService -> StatsController), stat id -> value in Config.Stats units.
export type StatSheet = { [string]: number }

-- An item effect paid out (EffectService -> ProcTextController, since B4), to its player: floating text over the
-- character during a wave, a toast in the shop. Texts come from Util/EffectText.
export type EffectProc = {
	itemId: string?, -- the item; nil for what a stat does on its own (Orb Healing)
	kind: "Heal" | "Shards" | "Stats" | "Blocked" | "Weapon",
	amount: number?, -- Heal: HP, Shards: Shards
	stats: { [string]: number }?, -- Stats: what was gained
	weaponId: string?, -- Weapon: the weapon that went one tier up
	tier: number?, -- Weapon: its new tier
}

-- A bonus from an item effect that is active right now (EffectService -> HUD, since B4), to its player.
export type ActiveBonus = {
	itemId: string,
	kind: string, -- "Still", "Moving", "Wave" (until the wave ends), "Timed", "NextWave" (bought for this wave)
	stats: { [string]: number },
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

-- Fruits and crates on the floor (LootService -> PickupRenderer, B6), batched per simulation step, to participants.
export type PickupEvents = {
	reset: boolean?, -- drop every pickup first (run start and end, full sync)
	dropped: { number }, -- flat: id, x, z, kind (1 = fruit, 2 = crate, 3 = legendary crate since WP10) per new pickup
	collected: { number }, -- flat: id, userId for every pickup a player took (userId 0: it vanished)
}

-- The local player's crate choice (UpgradeService -> LevelUpController, B6): crates found in a wave open one by one at
-- its end, before the level-up cards. Sent when it opens, closes or the number waiting changes.
export type CrateOffer = {
	open: boolean,
	itemId: string, -- key in Config.Items; "" while closed
	tier: number, -- rarity 1..4
	count: number, -- how many of it the player owns after taking it
	sellPrice: number, -- Shards for selling it instead
	expiresAt: number, -- server time; taken automatically then
	pending: number, -- further crates after this one (closed: crates waiting for the end of the wave)
}

-- Where a spawn group will appear (SpawnDirector -> SpawnMarkerRenderer, B9): red crosses on the floor until the
-- enemies come.
export type SpawnMarkers = {
	points: { number }, -- flat: x, z of every enemy of the group
	spawnsAt: number, -- server time
}

-- The bosses alive right now (BossService -> BossController, WP10), to participants every few tenths of a second
-- while one is alive and once more when the last one is gone (empty list).
export type BossInfo = {
	id: number, -- enemy id in the snapshots
	bossId: string, -- key in Config.Enemies.bosses
	hpFraction: number,
	phase: number,
	phaseCount: number,
	orbitStartedAt: number?, -- server time; set while the phase has projectiles circling it (Config orbit)
}

export type BossState = {
	bosses: { BossInfo },
}

-- A boss attack's warning on the floor (BossService -> BossController, WP10): it shows from startsAt and strikes at
-- hitsAt (server times). "Circle": x/z centre and radius. "Line": from x/z along the unit dx/dz for `length` studs,
-- `radius` half its width.
export type BossTelegraph = {
	shape: string,
	x: number,
	z: number,
	radius: number,
	dx: number?,
	dz: number?,
	length: number?,
	startsAt: number,
	hitsAt: number,
}

return {}
