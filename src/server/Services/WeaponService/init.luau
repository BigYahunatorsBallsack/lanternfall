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
local WeaponFx = require(Shared.Net.WeaponFx)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local MapService = require(script.Parent.MapService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ExperienceService = require(script.Parent.ExperienceService)
local CharacterExplosion = require(script.CharacterExplosion)
local CharacterExplosions = require(Shared.Config.CharacterExplosions)
local Arsenal = require(script.Arsenal)
local Afflictions = require(script.Afflictions)
local StatMath = require(Shared.Util.StatMath)
local CharacterRules = require(Shared.Util.CharacterRules)
local BrotatoCombat = require(script.BrotatoCombat)
local BrotatoRuntime = require(script.BrotatoRuntime)
local FirePuddles = require(script.FirePuddles)
local Carbon = require(script.CarbonArrows)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local CharacterMovement = require(script.Parent.CharacterService.Movement)
local waveBonuses: { [Player]: { [string]: number } } = {}
local selections: { [Player]: { [string]: string } } = {}

local WeaponService = {}

-- (player: Player): the player's weapons changed (added, removed, merged, tier, evolution)
WeaponService.Changed = Signal.new()
-- B7: permanent weapon-kill gains, delivered after the simulation step.
WeaponService.KillGrowth = Signal.new()
-- (player, kills): one distinct completed explosion, never a sum across attacks.
WeaponService.ExplosionResolved = Signal.new()
WeaponService.NativeMineRequested = Signal.new()
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
type CharacterHit = { player: Player, enemyId: number, amount: number }
local characterHits: { CharacterHit } = {}
type ConsumableExplosion = {
	player: Player,
	definition: CharacterExplosions.Definition,
	position: Vector3,
	sheet: StatMath.Sheet,
}
local consumableExplosions: { ConsumableExplosion } = {}
type ItemExplosion = { player: Player, position: Vector3, damage: number, scaling: { [string]: number }?, size: number }
local characterItemExplosions: { ItemExplosion } = {}

local function characterCanAttack(weapon: Arsenal.Weapon): boolean
	local player = Players:GetPlayerByUserId(weapon.ownerId)
	local classId = player and RunDirector.getParticipantClassId(player)
	local class = classId and Config.Classes[classId]
	return not (player and class and class.canAttackWhileMoving == false and CharacterMovement.isMoving(player))
end

local function loadBehaviors(): { [string]: Arsenal.Behavior }
	local behaviors = {}
	for _, child in script.Behaviors:GetChildren() do
		if child:IsA("ModuleScript") then
			local behavior = table.clone(require(child)) :: Arsenal.Behavior
			local fire = behavior.fire
			if fire then
				behavior.fire = function(weapon, context)
					if not characterCanAttack(weapon) then
						weapon.cooldownLeft = math.max(0, weapon.cooldownLeft)
						return false
					end
					return fire(weapon, context)
				end
			end
			local step = behavior.step
			if step then
				behavior.step = function(weapon, context, dt)
					local active = context.active
					-- Catch-up attacks also run in step; inactive still simulates existing projectiles.
					if active and not characterCanAttack(weapon) then
						context.active = false
						weapon.cooldownLeft = math.max(0, weapon.cooldownLeft)
					end
					step(weapon, context, dt)
					context.active = active
				end
			end
			behaviors[child.Name] = behavior
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

local arsenal: Arsenal.Arsenal
local function burningTargetBonus(ownerId: number, id: number, elemental: boolean?): number
	local player = playerOf(ownerId)
	local bonus = player and ownerStats[player] and ownerStats[player].nativeBurningTargetBonus or 0
	if elemental == false and bonus > 0 and arsenal:isBurning(id) then
		return bonus
	end
	return 0
end

arsenal = Arsenal.new({
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
			if not burn then
				amount = BrotatoCombat.roundHit(ownerId, amount)
			end
			local bonus = if burn
				then 0
				else burningTargetBonus(ownerId, id, BrotatoCombat.elementalHit(ownerId)) + BrotatoCombat.targetBonus(
					ownerId,
					id
				)
			local killed, dealt, applied = EnemySim.damage(
				id,
				amount,
				playerOf(ownerId),
				bonus,
				not burn and BrotatoCombat.elementalHit(ownerId) ~= nil
			)
			recordHit(ownerId, id, applied, crit, killed, burn)
			return killed, dealt
		end,
		push = function(id: number, dx: number, dz: number)
			EnemySim.push(id, Vector3.new(dx, 0, dz))
		end,
		knock = EnemySim.knock,
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
			maximum = math.max(maximum, Config.Classes[id].maxWeaponSlots or CharacterRules.maxWeapons(id))
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
		if not killed and dealt > 0 and _weapon and source == "Weapon" then
			EnemySim.retaliate(id, _weapon.config.kind)
		end
		if killed and _weapon and _weapon.config.killGainStat then
			local state = _weapon.state
			state.waveKills = (state.waveKills or 0) + 1
			if state.waveKills >= _weapon.stats.killsPerGain then
				state.waveKills -= _weapon.stats.killsPerGain
				local stat = _weapon.config.killGainStat
				local gains = growth[ownerId] or {}
				growth[ownerId] = gains
				gains[stat] = (gains[stat] or 0) + (if stat == "maxHp" then Config.Stats.hpScale else 1)
			end
		end
		if killed and crit and _weapon and source == "Weapon" and _weapon.stats.critMaterialChance then
			if RandomService.number("Combat") < _weapon.stats.critMaterialChance then
				local player = playerOf(ownerId)
				if player then
					require(script.Parent.ShopService).addShards(player, 1)
				end
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

local firePuddles = FirePuddles.new({
	query = function(x, z, radius, out)
		return EnemySim.queryRadius(Vector3.new(x, floorY, z), radius, out)
	end,
	ignite = function(weapon, id, stats)
		arsenal.afflictions:ignite(
			id,
			Afflictions.newBurn(
				weapon.ownerId,
				weapon,
				stats.burnDamage,
				stats.burnTicks,
				stats.burnInterval,
				stats.burnSpread
			)
		)
	end,
	emit = function(weapon, effect)
		arsenal:emitShared(weapon.ownerId, effect, "FirePuddle")
	end,
})
require(script.BrotatoProjectile).setFirePuddle(function(weapon, x, z)
	firePuddles:spawn(weapon, x, z, weapon.stats)
end)

local function now(): number
	return workspace:GetServerTimeNow()
end
function WeaponService.getStructureStats(player: Player): { [string]: number }
	return table.clone(ownerStats[player] or {})
end
function WeaponService.nextEffectId(): number
	return arsenal.context:nextId()
end
function WeaponService.emitStructureEffect(player: Player, effect: { [string]: any })
	if effect.kind == "Fire" then
		effect.kind = "StructureFire"
	end
	arsenal:emitShared(player.UserId, effect, "StructureShot")
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
	for _, weapon in arsenal:getWeapons(player.UserId) do
		Carbon.initialise(weapon, function()
			return RandomService.number("Combat", player)
		end)
	end
	BrotatoRuntime.recompute(arsenal:getWeapons(player.UserId), ownerStats[player] or {})
	Net.fireAllClients("Loadout", loadoutOf(player))
	WeaponService.Changed:Fire(player)
end

local function sendAll()
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

local function onRunStarted(participants: { Player })
	firePuddles:clear()
	table.clear(characterHits)
	table.clear(consumableExplosions)
	table.clear(characterItemExplosions)
	arsenal:clear()
	table.clear(waveBonuses)
	paused = false
	for _, player in participants do
		-- StatService sends fresh stats when the run starts; before or after this, the owner gets them
		arsenal:addOwner(player.UserId, ownerStats[player] or {})
		local classId = RunDirector.getParticipantClassId(player)
		local class = classId and Config.Classes[classId]
		if class and class.maxWeapons ~= 0 then
			local choices = selections[player]
			local chosen = (choices and choices[classId]) or class.startWeapon
			if class.nativeStartSelection and not PlayerDataService.isUnlocked(player, "weapons", chosen) then
				for _, alternative in class.startWeapons do
					if PlayerDataService.isUnlocked(player, "weapons", alternative) then
						chosen = alternative
						break
					end
				end
			end
			local tier = (class.startWeaponTiers and class.startWeaponTiers[chosen]) or Config.Weapons[chosen].minTier
			local ok, reason = arsenal:addWeapon(player.UserId, chosen, now(), tier)
			for _, extra in class.extraWeapons or {} do
				arsenal:addWeapon(player.UserId, extra, now(), class.extraWeaponTiers and class.extraWeaponTiers[extra])
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
		table.clear(characterHits)
		table.clear(consumableExplosions)
		table.clear(characterItemExplosions)
		return
	end
	local participants = RunDirector.getParticipants()
	for _, player in participants do
		local position = EnemySim.getPlayerPosition(player)
		if position then
			local velocity = MapService.getRootVelocity(player)
			arsenal:place(player.UserId, position.X, position.Z, velocity.X, velocity.Z)
			local weapons = arsenal:getWeapons(player.UserId)
			local hp, maxHp = CombatService.getHp(player)
			local bonus = BrotatoRuntime.step(
				weapons,
				dt,
				velocity.Magnitude > Config.WeaponVisuals.movingThreshold,
				hp,
				maxHp,
				function(amount)
					if RunDirector.getParticipantState(player) ~= "Alive" then
						return
					end
					CombatService.drainPlayer(player, amount)
				end
			)
			local previous = waveBonuses[player] or {}
			local changed = false
			for stat, amount in bonus do
				if amount ~= (previous[stat] or 0) then
					changed = true
				end
			end
			for stat, amount in previous do
				if amount ~= (bonus[stat] or 0) then
					changed = true
				end
			end
			waveBonuses[player] = bonus
			if changed then
				send(player)
			end
			if BrotatoRuntime.recompute(weapons, ownerStats[player] or {}) then
				Net.fireAllClients("Loadout", loadoutOf(player))
			end
		end
	end
	BrotatoCombat.resetHitContext()
	-- Existing patches of fire enter the shared burn registry before its next tick.
	if RunDirector.isActive() then
		firePuddles:step(dt)
	end
	arsenal:step(dt, stepNow)
	-- Character stat strikes are already scaled in the native order; Arsenal's primary-hit formula differs.
	local itemExplosions = characterItemExplosions
	characterItemExplosions = {}
	for _, entry in itemExplosions do
		if not RunDirector.isActive() or not arsenal:hasOwner(entry.player.UserId) then
			continue
		end
		local sheet = ownerStats[entry.player] or {}
		local stats = CharacterExplosion.computeItemEffect(entry.damage, entry.scaling, entry.size, sheet)
		local ids = {}
		local count = EnemySim.queryRadius(entry.position, stats.radius, ids)
		arsenal:emitShared(
			entry.player.UserId,
			{ kind = "Blast", x = entry.position.X, z = entry.position.Z, radius = stats.radius }
		)
		local kills = 0
		for index = 1, count do
			local id = ids[index]
			local _, elite = EnemySim.getKind(id)
			local amount = stats.damage * (if elite then math.max(0, 1 + (sheet.eliteDamage or 0) / 100) else 1)
			local crit = RandomService.number("Combat") < stats.critChance
			if crit then
				amount *= stats.critDamage
			end
			local killed = WeaponService.structureHit(
				entry.player,
				id,
				amount,
				"Explosion",
				crit,
				entry.scaling ~= nil and entry.scaling.elementalDamage ~= nil
			)
			if killed then
				kills += 1
			end
		end
		WeaponService.reportExplosion(entry.player, kills)
	end
	local explosions = consumableExplosions
	consumableExplosions = {}
	for _, explosion in explosions do
		WeaponService.explodeCharacter(explosion.player, explosion.definition, explosion.position, explosion.sheet)
	end
	local pending = characterHits
	characterHits = {}
	for _, hit in pending do
		if
			RunDirector.isActive()
			and RunDirector.getParticipantState(hit.player) == "Alive"
			and EnemySim.isAlive(hit.enemyId)
		then
			WeaponService.structureHit(hit.player, hit.enemyId, hit.amount, "Strike")
		end
	end
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
		-- Paket 22: one compact packet per step (Net/WeaponFx) instead of a table per effect
		local packet = WeaponFx.encode(effects)
		for _, player in participants do
			Net.fireClient("WeaponEffects", player, packet)
		end
	end
end

-- B10: picks the starting weapon for the character the player chose in the lobby (remote SelectStartWeapon;
-- Paket 15: RunPlaceService applies the hub pick). False if it is not one of that character's starting weapons.
function WeaponService.selectStartWeapon(player: Player, classId: string, weaponId: string): boolean
	local class = Config.Classes[classId]
	if RunDirector.isOngoing() and RunDirector.getParticipantState(player) ~= nil then
		return false
	end
	if RunDirector.getSelectedClassId(player) ~= classId or not class or not class.available then
		return false
	end
	if not table.find(class.startWeapons, weaponId) then
		return false
	end
	if class.nativeStartSelection and not PlayerDataService.isUnlocked(player, "weapons", weaponId) then
		return false
	end
	local choices = selections[player] or {}
	selections[player] = choices
	choices[classId] = weaponId
	Net.fireClient("StartWeaponChoice", player, classId, weaponId)
	return true
end

-- Paket 15: the starting weapon the player picked for a character, nil if they kept the default.
function WeaponService.getStartWeapon(player: Player, classId: string): string?
	local choices = selections[player]
	return if choices then choices[classId] else nil
end

-- Lifecycle -------------------------------------------------------------------------

function WeaponService.init()
	EnemySim.CharmShot:Connect(function(ownerId, event)
		arsenal:emitShared(ownerId, event, "CharmShot")
	end)
	ExperienceService.OrbsPickedUp:Connect(function(player, count)
		BrotatoRuntime.reloadFromMaterials(arsenal:getWeapons(player.UserId), count, now())
	end)
	BrotatoCombat.configure({
		tryCharm = function(ownerId, id, stats, random)
			local player = playerOf(ownerId)
			return player ~= nil and EnemySim.tryCharm(player, id, stats, random)
		end,
		nativeSlow = EnemySim.nativeSlow,
		spawnMine = function(ownerId, x, z)
			local player = playerOf(ownerId)
			if player then
				WeaponService.NativeMineRequested:Fire(player, Vector3.new(x, floorY, z))
			end
		end,
		explosionResolved = function(ownerId, kills)
			local player = playerOf(ownerId)
			if player then
				WeaponService.reportExplosion(player, kills)
			end
		end,
		emitExplosion = function(ownerId, x, z, radius)
			arsenal:emitShared(ownerId, { kind = "Blast", x = x, z = z, radius = radius })
		end,
		health = EnemySim.getHealth,
		healthShare = EnemySim.getHealthShare,
		slowArea = function(hitId, x, z, radius, percent, hold)
			if EnemySim.getKind(hitId) == "Tree" then
				return
			end
			local ids = {}
			local count = EnemySim.queryRadius(Vector3.new(x, floorY, z), radius, ids)
			for index = 1, count do
				local id = ids[index]
				local kind = EnemySim.getKind(id)
				local position = EnemySim.getPosition(id)
				if kind ~= "Tree" and position and (position.X - x) ^ 2 + (position.Z - z) ^ 2 <= radius * radius then
					EnemySim.nativeSlow(id, -percent, true, hold)
				end
			end
		end,
		weakness = EnemySim.applyWeakness,
		isBurning = function(id)
			return arsenal:isBurning(id)
		end,
		knockbackPiercing = function(id, x, z, amount, piercing)
			local kindId, elite = EnemySim.getKind(id)
			local kind = kindId and EnemyKinds.get(kindId, elite)
			local position = EnemySim.getPosition(id)
			if not kind or kind.anchored or not position then
				return
			end
			local resistance = kind.knockbackResistance or (1 - 1 / math.max(1, kind.mass))
			local direction = Vector3.new(position.X - x, 0, position.Z - z)
			if direction.Magnitude < 1e-6 then
				return
			end
			local share = if amount < 0 then 1 - resistance + resistance * piercing else resistance * piercing
			local extra = direction.Unit * (amount * share)
			if resistance < 1 and amount > 0 then
				-- Brotato get_increased_piercing_knockback_amount: a bigger vector that glides like the hit's own
				local more = extra / (1 - resistance)
				EnemySim.knock(id, more.X, more.Z, true)
			elseif resistance < 1 then
				EnemySim.push(id, extra / (1 - resistance))
			else
				EnemySim.teleport(id, position + extra)
			end
		end,
		isElite = function(id)
			local _, elite = EnemySim.getKind(id)
			return elite
		end,
	})
	CombatService.PlayerDamaged:Connect(function(player)
		BrotatoRuntime.hurt(arsenal:getWeapons(player.UserId))
	end)
	require(script.BrotatoProjectile).setNativeSlow(EnemySim.nativeSlow)
	require(script.BrotatoProjectile).setSlowAura(function(x, z, radius, factor, seconds)
		local ids = {}
		local count = EnemySim.queryRadius(Vector3.new(x, floorY, z), radius, ids)
		for i = 1, count do
			EnemySim.slow(ids[i], factor, seconds)
		end
	end)
	Net.onServer("SelectStartWeapon", function(player, classId: string, weaponId: string)
		WeaponService.selectStartWeapon(player, classId, weaponId)
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
		if phase ~= "Running" then
			firePuddles:clear()
			table.clear(characterHits)
			table.clear(consumableExplosions)
			table.clear(characterItemExplosions)
		end
		if phase == "Shop" then
			table.clear(waveBonuses)
			for _, player in Players:GetPlayers() do
				for _, weapon in arsenal:getWeapons(player.UserId) do
					if weapon.config.minTier then
						table.clear(weapon.state)
					end
					weapon.state.waveKills = 0
					weapon.state.shots = 0
					weapon.state.reloadLeft = 0
				end
				send(player)
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
		firePuddles:clear()
		table.clear(characterHits)
		table.clear(consumableExplosions)
		table.clear(characterItemExplosions)
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
		waveBonuses[player] = nil
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
	local config = Config.Weapons[weaponId]
	local requestedTier = tier or (config and config.minTier) or 1
	local classId = RunDirector.getParticipantClassId(player)
	local slots = (ownerStats[player] and ownerStats[player].weaponSlots) or 0
	if not CharacterRules.weaponAllowed(classId, weaponId, requestedTier) then
		return false, "CharacterRestriction", nil
	end
	if not CharacterRules.hasSlot(classId, weaponId, WeaponService.getWeapons(player), slots, requestedTier) then
		return false, "SlotsFull", nil
	end
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
	for _, weapon in arsenal:getWeapons(player.UserId) do
		if
			weapon.uid == uid
			and not CharacterRules.weaponAllowed(RunDirector.getParticipantClassId(player), weapon.id, weapon.tier + 1)
		then
			return false, "CharacterRestriction"
		end
	end
	local ok, reason = arsenal:raiseTier(player.UserId, uid)
	if ok then
		send(player)
	end
	return ok, reason
end

-- Merges the weapon with another copy of the same tier into the next tier (Arsenal.merge).
function WeaponService.merge(player: Player, uid: number): (boolean, string?)
	for _, weapon in arsenal:getWeapons(player.UserId) do
		if
			weapon.uid == uid
			and not CharacterRules.weaponAllowed(RunDirector.getParticipantClassId(player), weapon.id, weapon.tier + 1)
		then
			return false, "CharacterRestriction"
		end
	end
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
	if (ownerStats[player] and ownerStats[player].nativeBurningTargetBonus or 0) > 0 then
		if arsenal:hasOwner(player.UserId) then
			table.insert(characterItemExplosions, {
				player = player,
				position = position,
				damage = damage,
				scaling = if scaling then table.clone(scaling) else nil,
				size = size,
			})
		end
	else
		arsenal:queueExplosion(player.UserId, position.X, position.Z, damage, scaling, size)
	end
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

-- Lich/Lucky use one already-scaled hit per native event, deferred to the normal combat step.
function WeaponService.queueCharacterStrike(player: Player, enemyId: number, amount: number)
	if paused or not RunDirector.isActive() or RunDirector.getParticipantState(player) ~= "Alive" then
		return
	end
	if amount > 0 and amount < math.huge and EnemySim.isAlive(enemyId) then
		table.insert(characterHits, { player = player, enemyId = enemyId, amount = amount })
	end
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
	local result = {}
	for _, id in arsenal:getImplemented() do
		if Config.Weapons[id].available ~= false then
			table.insert(result, id)
		end
	end
	return result
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
	return CharacterRules.maxWeapons(
		RunDirector.getParticipantClassId(player),
		(ownerStats[player] and ownerStats[player].weaponSlots) or 0
	)
end

function WeaponService.reportExplosion(player: Player, kills: number)
	WeaponService.ExplosionResolved:Fire(player, kills)
end

-- B12: already scaled structure damage, no primary weapon scaling or life steal.
function WeaponService.structureHit(
	player: Player,
	enemyId: number,
	amount: number,
	source: Arsenal.HitSource?,
	critical: boolean?,
	elemental: boolean?
)
	local bonus = burningTargetBonus(player.UserId, enemyId, elemental)
	local killed, dealt, applied =
		EnemySim.damage(enemyId, amount, player, bonus, source ~= "Burn" and source ~= "Strike")
	recordHit(player.UserId, enemyId, applied, critical == true, killed, false)
	if hitListener and dealt > 0 then
		hitListener(player.UserId, enemyId, dealt, critical == true, killed, source or "Weapon")
	end
	return killed
end

-- Snapshot after full-health gains, but defer collision to avoid recursive pickup/kill chains.
function WeaponService.queueConsumableExplosion(
	player: Player,
	definition: CharacterExplosions.Definition,
	origin: Vector3,
	items: { [string]: number }?
)
	if paused or not RunDirector.isActive() then
		return
	end
	local maximum = CharacterExplosions.consumableOffsetPoints
	local function offset(): number
		return (math.floor(RandomService.number("Combat", player) * (2 * maximum + 1)) - maximum)
			* Config.Stats.range.studsPerPoint
	end
	local snapshot = table.clone(ownerStats[player] or {})
	local globalBase = 0
	if definition.burn then
		for id, count in items or {} do
			local item = Config.Items.byId[id]
			for _, effect in (item and item.effects) or {} do
				if effect.trigger == "Hit" and effect.action == "Burn" then
					globalBase += (effect.amount or 0) * count
				end
			end
		end
	end
	snapshot.nativeGlobalBurnDamage = globalBase
	table.insert(consumableExplosions, {
		player = player,
		definition = definition,
		position = origin + Vector3.new(offset(), 0, offset()),
		sheet = snapshot,
	})
end

-- Native on-hurt explosions resolve before CombatService marks a lethally hurt owner down.
-- Source stats include their own crit multiplier and add ordinary/explosion damage before rounding.
function WeaponService.explodeCharacter(
	player: Player,
	definition: CharacterExplosions.Definition,
	origin: Vector3?,
	snapshot: StatMath.Sheet?
): boolean
	if paused or not RunDirector.isActive() or RunDirector.getParticipantState(player) ~= "Alive" then
		return false
	end
	local position = origin or MapService.getRootPosition(player)
	if not position then
		return false
	end
	local sheet = snapshot or ownerStats[player] or {}
	local stats = CharacterExplosion.compute(definition, sheet)
	local center = position + Vector3.new(0, 0, stats.offsetZ)
	local ids = {}
	local count = EnemySim.queryRadius(center, stats.radius, ids)
	arsenal:emitShared(player.UserId, { kind = "Blast", x = center.X, z = center.Z, radius = stats.radius })
	local kills = 0
	for index = 1, count do
		local id = ids[index]
		if EnemySim.isAlive(id) then
			local _, elite = EnemySim.getKind(id)
			local critical = RandomService.number("Combat", player) < stats.critChance
			local damage = CharacterExplosion.hitDamage(stats, critical, if elite then sheet.eliteDamage or 0 else 0)
			local killed = WeaponService.structureHit(
				player,
				id,
				damage,
				"Explosion",
				critical,
				definition.scaling.elementalDamage ~= nil
			)
			if killed then
				kills += 1
			end
			local burnDamage = CharacterExplosion.burnDamage(definition, sheet, sheet.nativeGlobalBurnDamage or 0)
			if burnDamage and definition.burn and EnemySim.isAlive(id) then
				WeaponService.structureBurn(player, id, burnDamage, definition.burn.ticks, sheet)
			end
		end
	end
	WeaponService.reportExplosion(player, kills)
	return true
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
		Afflictions.newBurn(
			player.UserId,
			nil,
			damage,
			ticks,
			StatMath.burnInterval(sheet.burnSpeed or 0),
			math.max(0, math.floor(sheet.burnSpread or 0))
		)
	)
end
function WeaponService.getWaveBonuses(player: Player): { [string]: number }
	return table.clone(waveBonuses[player] or {})
end

return WeaponService
