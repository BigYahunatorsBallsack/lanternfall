--!strict
-- Weapon framework on the server (DESIGN.md section 6): every participant starts a run with their class weapon,
-- the Arsenal (rules in WeaponService/Arsenal, stats in WeaponStats) steps right after every enemy simulation step
-- (EnemySim.Stepped), and loadouts (Loadout, to everyone) and weapon effects (WeaponEffects, batched per step, to
-- the participants) go to the clients. One behavior module per weapon in WeaponService/Behaviors. Level-up cards
-- (UpgradeService), chests (WP9) and AdminService call addWeapon, levelUp and evolve, UpgradeService also setBonuses
-- for passives; the results screen (WP14) getDamageStats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

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
local extraBonuses: { [Player]: Arsenal.Bonuses } = {} -- from passives (UpgradeService), cleared at run start

local function playerOf(ownerId: number): Player?
	return Players:GetPlayerByUserId(ownerId)
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
		damage = function(id: number, amount: number, ownerId: number): (boolean, number)
			return EnemySim.damage(id, amount, playerOf(ownerId))
		end,
		push = function(id: number, dx: number, dz: number)
			EnemySim.push(id, Vector3.new(dx, 0, dz))
		end,
	},
	behaviors = loadBehaviors(),
	maxWeapons = Config.Player.maxWeapons,
	maxLevel = Config.Player.maxItemLevel,
	critChance = Config.Player.critChance,
	critMultiplier = Config.Player.critMultiplier,
	minCooldown = Config.Player.minWeaponCooldown,
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
			id = weapon.id,
			level = weapon.level,
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

-- Class bonuses (DESIGN.md section 5) plus passives as weapon bonuses; talents (WP13) will add to these.
local function bonusesFor(player: Player): Arsenal.Bonuses
	local bonuses: Arsenal.Bonuses = table.clone(extraBonuses[player] or {})
	local classId = RunDirector.getParticipantClassId(player)
	local class = classId and Config.Classes[classId]
	if class then
		bonuses[class.bonus.stat] = (bonuses[class.bonus.stat] or 0) + class.bonus.value
	end
	return bonuses
end

local function onRunStarted(participants: { Player })
	arsenal:clear()
	table.clear(extraBonuses)
	paused = false
	for _, player in participants do
		arsenal:addOwner(player.UserId, bonusesFor(player))
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
		extraBonuses[player] = nil
		arsenal:removeOwner(player.UserId)
		Net.fireAllClients("Loadout", { userId = player.UserId, weapons = {}, paused = paused } :: Types.Loadout)
	end)
end

-- Commands --------------------------------------------------------------------------
-- Each returns false plus a reason from Arsenal ("NotParticipant", "NotImplemented", "SlotsFull", ...) if the
-- change is not possible, and sends the new loadout to everyone otherwise.

function WeaponService.addWeapon(player: Player, weaponId: string): (boolean, string?)
	local ok, reason = arsenal:addWeapon(player.UserId, weaponId, now())
	if ok then
		send(player)
	end
	return ok, reason
end

function WeaponService.removeWeapon(player: Player, weaponId: string): boolean
	local ok = arsenal:removeWeapon(player.UserId, weaponId)
	if ok then
		send(player)
	end
	return ok
end

function WeaponService.levelUp(player: Player, weaponId: string): (boolean, string?)
	local ok, reason = arsenal:levelUp(player.UserId, weaponId)
	if ok then
		send(player)
	end
	return ok, reason
end

-- The passive an evolution needs is checked by the caller (chests, WP9).
function WeaponService.evolve(player: Player, weaponId: string, evolutionId: string): (boolean, string?)
	local ok, reason = arsenal:evolve(player.UserId, weaponId, evolutionId)
	if ok then
		send(player)
	end
	return ok, reason
end

-- Bonuses from passives by stat name (UpgradeService); weapons use damage, cooldown and area (WeaponStats).
-- Recomputes the player's weapons and sends the new loadout. Cleared when the next run starts.
function WeaponService.setBonuses(player: Player, bonuses: Arsenal.Bonuses)
	extraBonuses[player] = bonuses
	if arsenal:hasOwner(player.UserId) then
		arsenal:setBonuses(player.UserId, bonusesFor(player))
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
