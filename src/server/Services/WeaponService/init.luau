--!strict
-- Weapon framework on the server (DESIGN.md section 6): every participant starts a run with their class weapon,
-- the Arsenal (rules in WeaponService/Arsenal, stats in WeaponStats) steps right after every enemy simulation step
-- (EnemySim.Stepped), and loadouts (Loadout, to everyone) and weapon effects (WeaponEffects, batched per step, to
-- the participants) go to the clients, and every player gets the damage numbers of their own hits per step
-- (DamageNumbers, Net/HitNumbers). One behavior module per weapon in WeaponService/Behaviors. The shop
-- (ShopService), chests (UpgradeService) and AdminService call addWeapon, removeWeapon, merge, raiseTier and evolve
-- (weapons are named by their uid, since B3 a player may carry the same weapon several times); StatService sets the
-- owner's stats (setStats) and life steal heals through CombatService; the results screen (WP14) getDamageStats.
-- Since B4 crits and life steal roll on RandomService's Combat stream, every hit goes to the hit listener
-- (EffectService: Hit, Crit and Kill effects) and Changed fires whenever a player's weapons change. Since B5 weapons
-- slow and burn enemies (EnemySim.slow, setBurning), burn ticks show as orange damage numbers, and item effects burn
-- and blow up enemies through burnEnemy and explodeAt (EffectService). Burns go out when a wave ends.
-- B11 part 2: a RunDirector checkpoint keeps the weapons from the start of each wave for "Retry wave".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)
local HitNumbers = require(Shared.Net.HitNumbers)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local MapService = require(script.Parent.MapService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local Arsenal = require(script.Arsenal)
local CharacterRules = require(Shared.Util.CharacterRules)
local selections: { [Player]: { [string]: string } } = {}

local WeaponService = {}

-- (player: Player): the player's weapons changed (added, removed, merged, tier, evolution)
WeaponService.Changed = Signal.new()
-- B7: permanent weapon-kill gains, delivered after the simulation step.
WeaponService.KillGrowth = Signal.new()
local growth: { [number]: { [string]: number } } = {}

-- Hit listener: (ownerId, enemyId, dealt, crit, killed, source), set by EffectService. A plain callback, not a
-- Signal: it runs for every hit. `source` says what dealt it (Arsenal.HitSource: "Weapon", "Explosion", "Burn").
export type HitListener = (
	ownerId: number,
	enemyId: number,
	dealt: number,
	crit: boolean,
	killed: boolean,
	source: Arsenal.HitSource
) -> ()
local hitListener: HitListener? = nil

local function loadBehaviors(): { [string]: Arsenal.Behavior }
	local behaviors = {}
	for _, child in script.Behaviors:GetChildren() do
		if child:IsA("ModuleScript") then
			behaviors[child.Name] = require(child) :: any
		end
	end
	return behaviors
end

local floorY = Config.Map.arena.center.Y
local paused = false
local ownerStats: { [Player]: Arsenal.Bonuses } = {} -- the latest stats from StatService, kept across runs

local function playerOf(ownerId: number): Player?
	return Players:GetPlayerByUserId(ownerId)
end

-- One owner's hits of the current step for damage numbers, one entry per enemy (hits on the same enemy add up).
type HitFeed = {
	indexOf: { [number]: number }, -- enemy id -> entry
	xs: { number },
	zs: { number },
	amounts: { number },
	flags: { number }, -- HitNumbers.FLAG_*
	count: number,
}

local hitFeeds: { [number]: HitFeed } = {} -- by owner userId

local function recordHit(ownerId: number, id: number, applied: number, crit: boolean, killed: boolean, burn: boolean)
	if not Config.Feedback.damageNumbers.enabled or applied <= 0 then
		return
	end
	local feed = hitFeeds[ownerId]
	if not feed then
		feed = { indexOf = {}, xs = {}, zs = {}, amounts = {}, flags = {}, count = 0 }
		hitFeeds[ownerId] = feed
	end
	local flags = (if crit then HitNumbers.FLAG_CRIT else 0)
		+ (if killed then HitNumbers.FLAG_KILL else 0)
		+ (if burn then HitNumbers.FLAG_BURN else 0)
	local index = feed.indexOf[id]
	if index then
		feed.amounts[index] += applied
		feed.flags[index] = bit32.bor(feed.flags[index], flags)
		return
	end
	local position = EnemySim.getPosition(id)
	if not position or feed.count >= HitNumbers.MAX_HITS then
		return
	end
	local count = feed.count + 1
	feed.count = count
	feed.indexOf[id] = count
	feed.xs[count], feed.zs[count] = position.X, position.Z
	feed.amounts[count], feed.flags[count] = applied, flags
end

local function sendHitFeeds()
	for ownerId, feed in hitFeeds do
		if feed.count > 0 then
			local player = playerOf(ownerId)
			if player then
				Net.fireClient(
					"DamageNumbers",
					player,
					HitNumbers.encode(feed.xs, feed.zs, feed.amounts, feed.flags, feed.count)
				)
			end
			feed.count = 0
			table.clear(feed.indexOf)
		end
	end
end

local arsenal = Arsenal.new({
	enemies = {
		queryCircle = function(x: number, z: number, radius: number, out: { number }): number
			return EnemySim.queryRadius(Vector3.new(x, floorY, z), radius, out)
		end,
		querySegment = function(
			x0: number,
			z0: number,
			x1: number,
			z1: number,
			radius: number,
			out: { number }
		): number
			return EnemySim.querySegment(Vector3.new(x0, floorY, z0), Vector3.new(x1, floorY, z1), radius, out)
		end,
		getPosition = function(id: number): (number?, number?)
			local position = EnemySim.getPosition(id)
			if position then
				return position.X, position.Z
			end
			return nil, nil
		end,
		damage = function(id: number, amount: number, ownerId: number, crit: boolean, burn: boolean): (boolean, number)
			local killed, dealt, applied = EnemySim.damage(id, amount, playerOf(ownerId))
			recordHit(ownerId, id, applied, crit, killed, burn)
			return killed, dealt
		end,
		push = function(id: number, dx: number, dz: number)
			EnemySim.push(id, Vector3.new(dx, 0, dz))
		end,
		isAlive = EnemySim.isAlive,
		isElite = function(id: number): boolean
			local _, elite = EnemySim.getKind(id)
			return elite
		end,
		slow = EnemySim.slow,
		setBurning = EnemySim.setBurning,
	},
	behaviors = loadBehaviors(),
	maxWeapons = (function()
		local maximum = Config.Player.maxWeapons
		for id in Config.Classes do
			maximum = math.max(maximum, CharacterRules.maxWeapons(id))
		end
		return maximum
	end)(),
	maxTier = Config.Player.maxWeaponTier,
	critChance = Config.Player.critChance,
	critMultiplier = Config.Player.critMultiplier,
	minCooldown = Config.Player.minWeaponCooldown,
	onLifeSteal = function(ownerId: number)
		local player = playerOf(ownerId)
		if player then
			CombatService.lifeSteal(player)
		end
	end,
	onHit = function(
		ownerId: number,
		_weapon: Arsenal.Weapon?,
		id: number,
		dealt: number,
		crit: boolean,
		killed: boolean,
		source: Arsenal.HitSource
	)
		if killed and _weapon and _weapon.config.killGainStat then
			local state = _weapon.state
			state.waveKills = (state.waveKills or 0) + 1
			if state.waveKills >= _weapon.stats.killsPerGain then
				state.waveKills -= _weapon.stats.killsPerGain
				local stat = _weapon.config.killGainStat
				local gains = growth[ownerId] or {}
				growth[ownerId] = gains
				gains[stat] = (gains[stat] or 0) + 1
			end
		end
		local listener = hitListener
		if listener then
			listener(ownerId, id, dealt, crit, killed, source)
		end
	end,
	sweepStep = Config.Simulation.weaponSweepStep,
	random = function(): number
		return RandomService.number("Combat")
	end,
})

local function now(): number
	return workspace:GetServerTimeNow()
end

local function loadoutOf(player: Player): Types.Loadout
	local weapons: { Types.WeaponInfo } = {}
	for _, weapon in arsenal:getWeapons(player.UserId) do
		table.insert(weapons, {
			uid = weapon.uid,
			id = weapon.id,
			tier = weapon.tier,
			evolution = weapon.evolution,
			addedAt = weapon.addedAt,
			stats = table.clone(weapon.stats),
		})
	end
	return { userId = player.UserId, weapons = weapons, paused = paused }
end

local function send(player: Player)
	Net.fireAllClients("Loadout", loadoutOf(player))
	WeaponService.Changed:Fire(player)
end

local function sendAll()
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

local function onRunStarted(participants: { Player })
	arsenal:clear()
	paused = false
	for _, player in participants do
		-- StatService sends fresh stats when the run starts; before or after this, the owner gets them
		arsenal:addOwner(player.UserId, ownerStats[player] or {})
		local classId = RunDirector.getParticipantClassId(player)
		local class = classId and Config.Classes[classId]
		if class then
			local choices = selections[player]
			local chosen = (choices and choices[classId]) or class.startWeapon
			local ok, reason = arsenal:addWeapon(player.UserId, chosen, now())
			for _, extra in class.extraWeapons or {} do
				arsenal:addWeapon(player.UserId, extra, now())
			end
			if not ok then
				warn(`[Lanternfall] {player.Name} gets no start weapon {class.startWeapon}: {reason}`)
			end
		end
	end
	sendAll() -- also empties the loadouts of players who sat this run out
end

local function onStepped(dt: number, stepNow: number)
	if paused then
		return
	end
	local participants = RunDirector.getParticipants()
	for _, player in participants do
		local position = EnemySim.getPlayerPosition(player)
		if position then
			local velocity = MapService.getRootVelocity(player)
			arsenal:place(player.UserId, position.X, position.Z, velocity.X, velocity.Z)
		end
	end
	arsenal:step(dt, stepNow)
	local earned = growth
	growth = {}
	for ownerId, gains in earned do
		local player = playerOf(ownerId)
		if player then
			WeaponService.KillGrowth:Fire(player, gains)
		end
	end
	sendHitFeeds()
	local effects = arsenal:drainEffects()
	if #effects > 0 then
		for _, player in participants do
			Net.fireClient("WeaponEffects", player, effects)
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------

function WeaponService.init()
	Net.onServer("SelectStartWeapon", function(player, classId: string, weaponId: string)
		local class = Config.Classes[classId]
		if RunDirector.isOngoing() and RunDirector.getParticipantState(player) ~= nil then
			return
		end
		if RunDirector.getSelectedClassId(player) ~= classId or not class or not class.available then
			return
		end
		if not table.find(class.startWeapons, weaponId) then
			return
		end
		local choices = selections[player] or {}
		selections[player] = choices
		choices[classId] = weaponId
		Net.fireClient("StartWeaponChoice", player, classId, weaponId)
	end)
	RunDirector.SyncRequested:Connect(function(player)
		for classId, weaponId in selections[player] or {} do
			Net.fireClient("StartWeaponChoice", player, classId, weaponId)
		end
	end)
	require(script.B7Projectile).setSlowAura(function(x, z, radius, factor, seconds)
		local ids = {}
		local count = EnemySim.queryRadius(Vector3.new(x, floorY, z), radius, ids)
		for i = 1, count do
			EnemySim.slow(ids[i], factor, seconds)
		end
	end)
	RunDirector.RunStarted:Connect(onRunStarted)
	EnemySim.Stepped:Connect(onStepped)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Shop" then
			for _, player in Players:GetPlayers() do
				for _, weapon in arsenal:getWeapons(player.UserId) do
					if weapon.config.minTier then
						table.clear(weapon.state)
					end
					weapon.state.waveKills = 0
					weapon.state.shots = 0
					weapon.state.reloadLeft = 0
				end
			end
			arsenal:clearCombat() -- the enemies left fade away (EnemySim), so do their burns
		end
	end)
	-- B11 part 2: the weapons from the start of the wave for "Retry wave"
	RunDirector.addCheckpoint("Weapons", function()
		local saved = {}
		for _, player in RunDirector.getParticipants() do
			saved[player] = arsenal:saveWeapons(player.UserId)
		end
		return saved
	end, function(saved: { [Player]: { Arsenal.SavedWeapon } })
		arsenal:clearCombat()
		growth = {}
		for player, weapons in saved do
			if player.Parent and arsenal:restoreWeapons(player.UserId, weapons) then
				send(player)
			end
		end
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		for _, player in Players:GetPlayers() do
			Net.fireClient("Loadout", requester, loadoutOf(player))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		selections[player] = nil
		ownerStats[player] = nil
		hitFeeds[player.UserId] = nil
		arsenal:removeOwner(player.UserId)
		Net.fireAllClients("Loadout", { userId = player.UserId, weapons = {}, paused = paused } :: Types.Loadout)
	end)
end

-- Commands --------------------------------------------------------------------------
-- Each returns false plus a reason from Arsenal ("NotParticipant", "NotImplemented", "SlotsFull", ...) if the
-- change is not possible, and sends the new loadout to everyone otherwise.

-- Adds a weapon of `tier` (default I); returns its uid.
function WeaponService.addWeapon(player: Player, weaponId: string, tier: number?): (boolean, string?, number?)
	if not CharacterRules.weaponAllowed(RunDirector.getParticipantClassId(player), weaponId) then
		return false, "CharacterRestriction", nil
	end
	if
		not CharacterRules.hasSlot(
			RunDirector.getParticipantClassId(player),
			weaponId,
			WeaponService.getWeapons(player)
		)
	then
		return false, "SlotsFull", nil
	end
	local config = Config.Weapons[weaponId]
	local requestedTier = tier or (config and config.minTier) or 1
	if config and requestedTier < (config.minTier or 1) then
		return false, "BadTier", nil
	end
	local ok, reason, uid = arsenal:addWeapon(player.UserId, weaponId, now(), requestedTier)
	if ok then
		send(player)
	end
	return ok, reason, uid
end

function WeaponService.removeWeapon(player: Player, uid: number): boolean
	local ok = arsenal:removeWeapon(player.UserId, uid)
	if ok then
		send(player)
	end
	return ok
end

-- One tier up without a partner (admin).
function WeaponService.raiseTier(player: Player, uid: number): (boolean, string?)
	local ok, reason = arsenal:raiseTier(player.UserId, uid)
	if ok then
		send(player)
	end
	return ok, reason
end

-- Merges the weapon with another copy of the same tier into the next tier (Arsenal.merge).
function WeaponService.merge(player: Player, uid: number): (boolean, string?)
	local ok, reason = arsenal:merge(player.UserId, uid)
	if ok then
		send(player)
	end
	return ok, reason
end

-- The item an evolution needs is checked by the caller (chests, WP9).
function WeaponService.evolve(player: Player, uid: number, evolutionId: string): (boolean, string?)
	local ok, reason = arsenal:evolve(player.UserId, uid, evolutionId)
	if ok then
		send(player)
	end
	return ok, reason
end

-- The player's stats by id (StatService; WeaponStats uses the damage stats, Attack Speed, Crit Chance, Range and
-- Life Steal). Recomputes the player's weapons and sends the new loadout.
function WeaponService.setStats(player: Player, stats: Arsenal.Bonuses)
	ownerStats[player] = stats
	if arsenal:hasOwner(player.UserId) then
		arsenal:setBonuses(player.UserId, stats)
		send(player)
	end
end

-- Sets the function every weapon hit that took HP is reported to (EffectService), or nil.
function WeaponService.setHitListener(listener: HitListener?)
	hitListener = listener
end

-- Item effects (B5, EffectService): sets an enemy on fire for the player at the end of this step, `ticks` ticks of
-- (damage + sum of scaling * stat) times Damage %, with the player's Burning Speed and Spread.
function WeaponService.burnEnemy(
	player: Player,
	enemyId: number,
	damage: number,
	scaling: { [string]: number }?,
	ticks: number
)
	arsenal:queueBurn(player.UserId, enemyId, damage, scaling, ticks)
end

-- Item effects (B5, EffectService): an explosion of the player's at `position` at the end of this step, (damage +
-- sum of scaling * stat) times Damage % and Explosion Damage, `size` times the base radius times Explosion Size.
function WeaponService.explodeAt(
	player: Player,
	position: Vector3,
	damage: number,
	scaling: { [string]: number }?,
	size: number
)
	arsenal:queueExplosion(player.UserId, position.X, position.Z, damage, scaling, size)
end

-- Item effects (B8, EffectService): hits enemy `enemyId` for the player at the end of this step, (damage + sum of
-- scaling * stat) times Damage % plus `flat` (not scaled), without crit, life steal or knockback.
function WeaponService.strikeEnemy(
	player: Player,
	enemyId: number,
	damage: number,
	scaling: { [string]: number }?,
	flat: number
)
	arsenal:queueStrike(player.UserId, enemyId, damage, scaling, flat)
end

-- Debug: switches every player's weapons off (no hits, no visuals) or back on. Resets at run start.
function WeaponService.setPaused(value: boolean)
	paused = value
	sendAll()
end

-- Queries ---------------------------------------------------------------------------

function WeaponService.isPaused(): boolean
	return paused
end

-- The player's weapons as sent to clients (copies).
function WeaponService.getWeapons(player: Player): { Types.WeaponInfo }
	return loadoutOf(player).weapons
end

-- The uid of another copy the weapon `uid` can merge with (same weapon and tier, below the max tier), or nil.
function WeaponService.findMergePartner(player: Player, uid: number): number?
	local partner = arsenal:findMergePartner(player.UserId, uid)
	return if partner then partner.uid else nil
end

-- True if the player takes part in the current run and can carry weapons.
function WeaponService.isArmed(player: Player): boolean
	return arsenal:hasOwner(player.UserId)
end

-- Ids of the weapons that can be given out (config record plus behavior module), sorted.
function WeaponService.getImplemented(): { string }
	return arsenal:getImplemented()
end

-- Whether an enemy burns right now (B5; smoke test).
function WeaponService.isBurning(enemyId: number): boolean
	return arsenal:isBurning(enemyId)
end

-- Damage dealt and kills per weapon in the current (or last) run.
function WeaponService.getDamageStats(player: Player): Arsenal.DamageStats
	return arsenal:getDamageStats(player.UserId)
end

function WeaponService.getMaxWeapons(player: Player): number
	return CharacterRules.maxWeapons(RunDirector.getParticipantClassId(player))
end

-- B12: already scaled structure damage, no primary weapon scaling or life steal.
function WeaponService.structureHit(player: Player, enemyId: number, amount: number, source: Arsenal.HitSource?)
	local killed, dealt, applied = EnemySim.damage(enemyId, amount, player)
	recordHit(player.UserId, enemyId, applied, false, killed, false)
	if hitListener and dealt > 0 then
		hitListener(player.UserId, enemyId, dealt, false, killed, source or "Weapon")
	end
end
-- B12 shares the existing burn registry: strongest burn wins, timers survive refreshes, secondary stats apply.
function WeaponService.structureBurn(
	player: Player,
	enemyId: number,
	damage: number,
	ticks: number,
	sheet: { [string]: number }
)
	arsenal.afflictions:ignite(
		enemyId,
		require(script.Afflictions).newBurn(
			player.UserId,
			nil,
			damage,
			ticks,
			require(Shared.Util.StatMath).burnInterval(sheet.burnSpeed or 0),
			math.max(0, math.floor(sheet.burnSpread or 0))
		)
	)
end
return WeaponService
