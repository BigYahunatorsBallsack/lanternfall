--!strict
-- Debug commands for testing (skip time, knock yourself down, hurt/heal yourself, win, spawn/hit/kill enemies, pause
-- spawning, add/swap/level/evolve weapons, weapons off, team level-up) and the stats panel feed (DebugStats once per second). Admins only:
-- everyone in Studio, the owner of a user-owned experience and Config.Admin.userIds. Handles the DebugCommand remote
-- and uses RunDirector, CombatService, EnemySim, ExperienceService, SpawnDirector, UpgradeService, WeaponService and
-- MapService. Sets the player
-- attribute "LanternfallAdmin" so the client shows the debug panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DebugCommands = require(Shared.Net.DebugCommands)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local ExperienceService = require(script.Parent.ExperienceService)
local MapService = require(script.Parent.MapService)
local RunDirector = require(script.Parent.RunDirector)
local SpawnDirector = require(script.Parent.SpawnDirector)
local UpgradeService = require(script.Parent.UpgradeService)
local WeaponService = require(script.Parent.WeaponService)

local ADMIN_ATTRIBUTE = "LanternfallAdmin"

local AdminService = {}

local hitList: { number } = {}

local function enemies(count: number): string
	return if count == 1 then "1 enemy" else `{count} enemies`
end

-- The admin's position during a run, or nil plus a RunDirector rejection reason.
local function runPosition(player: Player): (Vector3?, string?)
	if not RunDirector.isActive() then
		return nil, "NotRunning"
	end
	local position = MapService.getRootPosition(player)
	if not position then
		return nil, "NoCharacter"
	end
	return position, nil
end

local function weaponName(weaponId: string): string
	local weapon = Config.Weapons[weaponId]
	return if weapon then weapon.displayName else weaponId
end

-- A participant of the running run who can carry weapons, or false plus a RunDirector rejection reason.
local function armed(player: Player): (boolean, string?)
	if not RunDirector.isActive() then
		return false, "NotRunning"
	end
	if not WeaponService.isArmed(player) then
		return false, "NotParticipant"
	end
	return true, nil
end

local function ownedIds(player: Player): { string }
	local ids = {}
	for _, weapon in WeaponService.getWeapons(player) do
		table.insert(ids, weapon.id)
	end
	return ids
end

-- Each handler returns ok plus, on failure, a RunDirector rejection reason or, on success, an optional
-- message for the admin.
local handlers: { [string]: (player: Player) -> (boolean, string?) } = {
	SkipMinute = function()
		return RunDirector.skipTo(RunDirector.getElapsed() + Config.Admin.skipMinuteSeconds)
	end,
	SkipToBoss = function()
		return RunDirector.skipTo(Config.Run.durationSeconds - Config.Admin.skipToBossLeadSeconds)
	end,
	DownSelf = function(player)
		return RunDirector.setParticipantState(player, "Down")
	end,
	ReviveSelf = function(player)
		return RunDirector.setParticipantState(player, "Alive")
	end,
	HurtSelf = function(player)
		if RunDirector.getParticipantState(player) ~= "Alive" or not RunDirector.isActive() then
			return false, "NotRunning"
		end
		local taken = CombatService.damagePlayer(player, Config.Admin.hurtSelfDamage)
		if taken == 0 then
			return true, "No damage: you are protected right now"
		end
		return true, `Took {taken} damage`
	end,
	HealSelf = function(player)
		local hp, maxHp = CombatService.getHp(player)
		CombatService.healPlayer(player, maxHp - hp)
		return true, "HP full"
	end,
	WinRun = function()
		return RunDirector.endRun("Victory")
	end,
	SpawnWave = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		local spawned = SpawnDirector.spawnWave(position, Config.Admin.spawnWaveCount)
		if spawned == 0 then
			return false, "EnemyCap"
		end
		return true, `Spawned {enemies(spawned)}`
	end,
	HitNearby = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		local found = EnemySim.queryRadius(position, Config.Admin.hitNearbyRadius, hitList)
		local killed = 0
		for i = 1, found do
			if EnemySim.damage(hitList[i], Config.Admin.hitNearbyDamage, player) then
				killed += 1
			end
		end
		return true, `Hit {enemies(found)}, {killed} died`
	end,
	KillEnemies = function(player)
		return true, `Killed {enemies(EnemySim.killAll(player))}`
	end,
	ToggleSpawning = function()
		local paused = not SpawnDirector.isPaused()
		SpawnDirector.setPaused(paused)
		return true, if paused then "Enemy spawning paused" else "Enemy spawning resumed"
	end,
	AddWeapon = function(player)
		local ok, reason = armed(player)
		if not ok then
			return false, reason
		end
		local owned = ownedIds(player)
		if #owned >= Config.Player.maxWeapons then
			return true, "All weapon slots are full"
		end
		for _, weaponId in WeaponService.getImplemented() do
			if not table.find(owned, weaponId) then
				WeaponService.addWeapon(player, weaponId)
				return true, `Added {weaponName(weaponId)}`
			end
		end
		return true, "You already have every weapon in the game so far"
	end,
	NextWeapon = function(player)
		local ok, reason = armed(player)
		if not ok then
			return false, reason
		end
		local implemented = WeaponService.getImplemented()
		if #implemented == 0 then
			return true, "There are no weapons in the game yet"
		end
		local owned = ownedIds(player)
		local index = if owned[1] then table.find(implemented, owned[1]) or 0 else 0
		local nextId = implemented[index % #implemented + 1]
		for _, weaponId in owned do
			WeaponService.removeWeapon(player, weaponId)
		end
		WeaponService.addWeapon(player, nextId)
		return true, `Now only {weaponName(nextId)}`
	end,
	LevelUpWeapons = function(player)
		local ok, reason = armed(player)
		if not ok then
			return false, reason
		end
		local raised = 0
		for _, weaponId in ownedIds(player) do
			if WeaponService.levelUp(player, weaponId) then
				raised += 1
			end
		end
		if raised == 0 then
			return true, "Every weapon is at max level"
		end
		local parts = {}
		for _, weapon in WeaponService.getWeapons(player) do
			table.insert(parts, `{weaponName(weapon.id)} LV {weapon.level}`)
		end
		return true, table.concat(parts, ", ")
	end,
	EvolveWeapons = function(player)
		local ok, reason = armed(player)
		if not ok then
			return false, reason
		end
		local parts = {}
		for _, weapon in WeaponService.getWeapons(player) do
			for evolutionId, evolution in Config.Evolutions do
				if evolution.weapon ~= weapon.id then
					continue
				end
				if weapon.evolution then
					table.insert(parts, `{evolution.displayName} already`)
					continue
				end
				for _ = weapon.level + 1, Config.Player.maxItemLevel do
					WeaponService.levelUp(player, weapon.id)
				end
				if not table.find(UpgradeService.getEvolutions(player), evolutionId) then
					UpgradeService.addPassive(player, evolution.passive) -- fails if the passive slots are full
				end
				if UpgradeService.evolve(player, evolutionId) then
					table.insert(parts, evolution.displayName)
				else
					local passive = Config.Passives[evolution.passive]
					local passiveName = if passive then passive.displayName else evolution.passive
					table.insert(parts, `no {evolution.displayName} (needs {passiveName}, passive slots full)`)
				end
			end
		end
		if #parts == 0 then
			return true, "None of your weapons has an evolution"
		end
		return true, table.concat(parts, ", ")
	end,
	ToggleWeapons = function()
		local paused = not WeaponService.isPaused()
		WeaponService.setPaused(paused)
		return true, if paused then "Weapons off" else "Weapons on"
	end,
	GainLevel = function()
		if not ExperienceService.grantLevel() then
			return false, "NotRunning"
		end
		return true, `Team level {ExperienceService.getLevel()}`
	end,
}

local function collectStats(): Types.DebugStats
	local sim = EnemySim.getStats()
	local rate = SpawnDirector.getRate()
	return {
		enemies = EnemySim.getCount(),
		cap = SpawnDirector.getCap(),
		spawnRate = rate,
		spawning = rate > 0,
		paused = SpawnDirector.isPaused(),
		stepMilliseconds = sim.stepMilliseconds,
		stepMaxMilliseconds = sim.stepMaxMilliseconds,
		stepsPerSecond = sim.stepsPerSecond,
		sentKilobytesPerSecond = sim.sentKilobytesPerSecond,
	}
end

function AdminService.isAdmin(player: Player): boolean
	if Config.Admin.allowInStudio and RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(Config.Admin.userIds, player.UserId) ~= nil
end

function AdminService.init()
	for _, command in DebugCommands do
		assert(handlers[command], `Debug command {command} has no handler`)
	end

	local function onPlayerAdded(player: Player)
		player:SetAttribute(ADMIN_ATTRIBUTE, AdminService.isAdmin(player))
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Net.onServer("DebugCommand", function(player, command: string)
		if not AdminService.isAdmin(player) then
			return
		end
		local ok, detail = handlers[command](player)
		print(`[Lanternfall] Debug command {command} by {player.Name}: {if ok then detail or "done" else detail}`)
		if not ok then
			RunDirector.notifyRejection(player, detail)
		elseif detail then
			Net.fireClient("Notify", player, detail)
		end
	end)
end

-- Sends the stats panel numbers to every admin once per Config.Admin.statsInterval.
function AdminService.start()
	while true do
		task.wait(Config.Admin.statsInterval)
		local stats: Types.DebugStats? = nil
		for _, player in Players:GetPlayers() do
			if player:GetAttribute(ADMIN_ATTRIBUTE) == true then
				stats = stats or collectStats()
				Net.fireClient("DebugStats", player, stats)
			end
		end
	end
end

return AdminService
