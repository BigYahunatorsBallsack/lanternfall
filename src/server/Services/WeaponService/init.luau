--!strict
-- Weapon framework on the server (DESIGN.md section 6): every participant starts a run with their class weapon,
-- the Arsenal (rules in WeaponService/Arsenal, stats in WeaponStats) steps right after every enemy simulation step
-- (EnemySim.Stepped), and loadouts (Loadout, to everyone) and weapon effects (WeaponEffects, batched per step, to
-- the participants) go to the clients, and every player gets the damage numbers of their own hits per step
-- (DamageNumbers, Net/HitNumbers). One behavior module per weapon in WeaponService/Behaviors. The shop
-- (ShopService), chests (UpgradeService) and AdminService call addWeapon, removeWeapon, merge, raiseTier and evolve
-- (weapons are named by their uid, since B3 a player may carry the same weapon several times); StatService sets the
-- owner's stats (setStats) and life steal heals through CombatService; the results screen (WP14) getDamageStats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)
local HitNumbers = require(Shared.Net.HitNumbers)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local MapService = require(script.Parent.MapService)
local RunDirector = require(script.Parent.RunDirector)
local Arsenal = require(script.Arsenal)

local WeaponService = {}

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
local rng = Random.new()
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

local function recordHit(ownerId: number, id: number, applied: number, crit: boolean, killed: boolean)
	if not Config.Feedback.damageNumbers.enabled or applied <= 0 then
		return
	end
	local feed = hitFeeds[ownerId]
	if not feed then
		feed = { indexOf = {}, xs = {}, zs = {}, amounts = {}, flags = {}, count = 0 }
		hitFeeds[ownerId] = feed
	end
	local flags = (if crit then HitNumbers.FLAG_CRIT else 0) + (if killed then HitNumbers.FLAG_KILL else 0)
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
		damage = function(id: number, amount: number, ownerId: number, crit: boolean): (boolean, number)
			local killed, dealt, applied = EnemySim.damage(id, amount, playerOf(ownerId))
			recordHit(ownerId, id, applied, crit, killed)
			return killed, dealt
		end,
		push = function(id: number, dx: number, dz: number)
			EnemySim.push(id, Vector3.new(dx, 0, dz))
		end,
	},
	behaviors = loadBehaviors(),
	maxWeapons = Config.Player.maxWeapons,
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
	sweepStep = Config.Simulation.weaponSweepStep,
	random = function(): number
		return rng:NextNumber()
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
			local ok, reason = arsenal:addWeapon(player.UserId, class.startWeapon, now())
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
	RunDirector.RunStarted:Connect(onRunStarted)
	EnemySim.Stepped:Connect(onStepped)
	RunDirector.SyncRequested:Connect(function(requester)
		for _, player in Players:GetPlayers() do
			Net.fireClient("Loadout", requester, loadoutOf(player))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
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
	local ok, reason, uid = arsenal:addWeapon(player.UserId, weaponId, now(), tier)
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

-- Damage dealt and kills per weapon in the current (or last) run.
function WeaponService.getDamageStats(player: Player): Arsenal.DamageStats
	return arsenal:getDamageStats(player.UserId)
end

return WeaponService
