--!strict
-- Debug commands for testing (end the wave, stop the wave timer, Shards, knock yourself down, hurt/heal yourself, win, spawn/hit/kill enemies and elites, pause
-- spawning, add/swap/level/evolve weapons, weapons off, team level-up, the B4 effect items one by one, since B6 Looters,
-- Trees and crates, since WP10 bosses and legendary crates) and the stats
-- panel feed (DebugStats once per second). Admins only:
-- everyone in Studio, the owner of a user-owned experience and Config.Admin.userIds. Handles the DebugCommand remote
-- and uses RunDirector, CombatService, EnemySim, ExperienceService, ShopService, SpawnDirector, StatService,
-- UpgradeService, WeaponService and MapService. Sets the player
-- attribute "LanternfallAdmin" so the client shows the debug panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DebugCommands = require(Shared.Net.DebugCommands)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local RunSchedule = require(Shared.Util.RunSchedule)
local Types = require(Shared.Net.Types)
local UpgradeText = require(Shared.Util.UpgradeText)

local BossService = require(script.Parent.BossService)
local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local ExperienceService = require(script.Parent.ExperienceService)
local LootService = require(script.Parent.LootService)
local MapService = require(script.Parent.MapService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RunDirector = require(script.Parent.RunDirector)
local ShopService = require(script.Parent.ShopService)
local SpawnDirector = require(script.Parent.SpawnDirector)
local StatService = require(script.Parent.StatService)
local UpgradeService = require(script.Parent.UpgradeService)
local WeaponService = require(script.Parent.WeaponService)

local ADMIN_ATTRIBUTE = "LanternfallAdmin"

local AdminService = {}

local hitList: { number } = {}
local effectItemIndex: { [Player]: number } = {} -- the last item "AddEffectItem" gave
local combatItemIndex: { [Player]: number } = {} -- the last item "AddCombatItem" gave
local newItemIndex: { [Player]: number } = {} -- the last item "AddNewItem" gave (B8)
local newEnemyIndex: { [Player]: number } = {} -- the last enemy "SpawnNewEnemy" spawned (B9)

-- Stats and effect actions of the combat items (B5).
local COMBAT_STATS = {
	knockback = true,
	explosionDamage = true,
	explosionSize = true,
	piercing = true,
	piercingDamage = true,
	bounce = true,
	burnSpeed = true,
	burnSpread = true,
}
local COMBAT_ACTIONS = { Burn = true, Explode = true }

-- Items with effects or a secondary stat (since B4) and the combat ones among them (B5), in the order of Config.Items.
local effectItems: { string } = {}
local combatItems: { string } = {}
for _, item in Config.Items.list do
	local secondary, combat = false, false
	for statId in item.stats do
		local stat = Config.Stats.byId[statId]
		secondary = secondary or (stat ~= nil and stat.hideWhenZero)
		combat = combat or COMBAT_STATS[statId] == true
	end
	for _, effect in item.effects or {} do
		combat = combat or COMBAT_ACTIONS[effect.action] == true
	end
	if item.effects or secondary then
		table.insert(effectItems, item.id)
	end
	if combat then
		table.insert(combatItems, item.id)
	end
end

-- Gives the player the next item of `list` after the one `last` remembers (skipping those at their limit).
local function nextItem(player: Player, list: { string }, last: { [Player]: number }): (boolean, string?)
	if not RunDirector.isOngoing() then
		return false, "NotRunning"
	end
	local start = last[player] or 0
	for step = 1, #list do
		local index = (start + step - 1) % #list + 1
		local itemId = list[index]
		local ok, reason = StatService.addItem(player, itemId)
		if ok then
			last[player] = index
			local item = Config.Items.byId[itemId]
			return true, `{item.displayName}: {UpgradeText.itemLines(itemId, nil, " · ")}`
		elseif reason == "NotParticipant" then
			return false, reason
		end
	end
	return true, "Every item of this list is at its limit"
end

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
	SkipWave = function()
		return RunDirector.skipTo(RunSchedule.wave(RunDirector.getWave()).endsAt)
	end,
	HoldWaves = function()
		local hold = not RunDirector.isHoldingWaves()
		RunDirector.setHoldWaves(hold)
		return true, if hold then "Wave timer stopped" else "Wave timer running"
	end,
	AddShards = function(player)
		if not ShopService.addShards(player, Config.Admin.addShards) then
			return false, "NotParticipant"
		end
		return true, `+{Config.Admin.addShards} Shards`
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
		local taken, dodged, blocked = CombatService.damagePlayer(player, Config.Admin.hurtSelfDamage)
		if dodged then
			return true, "Dodged!"
		elseif blocked then
			return true, "Blocked by a shield"
		elseif taken == 0 then
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
	SpawnElite = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		local name = SpawnDirector.spawnElite(position)
		if not name then
			return true, "No room for an elite here"
		end
		return true, `Spawned a {name}`
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
		for _, weapon in WeaponService.getWeapons(player) do
			WeaponService.removeWeapon(player, weapon.uid)
		end
		WeaponService.addWeapon(player, nextId)
		return true, `Now only {weaponName(nextId)}`
	end,
	TierUpWeapons = function(player)
		local ok, reason = armed(player)
		if not ok then
			return false, reason
		end
		local raised = 0
		for _, weapon in WeaponService.getWeapons(player) do
			if WeaponService.raiseTier(player, weapon.uid) then
				raised += 1
			end
		end
		if raised == 0 then
			return true, "Every weapon is at max tier"
		end
		local parts = {}
		for _, weapon in WeaponService.getWeapons(player) do
			table.insert(parts, `{weaponName(weapon.id)} {Format.tier(weapon.tier)}`)
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
				for _ = weapon.tier + 1, Config.Player.maxWeaponTier do
					WeaponService.raiseTier(player, weapon.uid)
				end
				if not table.find(UpgradeService.getEvolutions(player), evolutionId) then
					StatService.addItem(player, evolution.item) -- fails only for an unknown item
				end
				if UpgradeService.evolve(player, evolutionId) then
					table.insert(parts, evolution.displayName)
				else
					local item = Config.Items.byId[evolution.item]
					table.insert(
						parts,
						`no {evolution.displayName} (needs {if item then item.displayName else evolution.item})`
					)
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
	AddEffectItem = function(player)
		return nextItem(player, effectItems, effectItemIndex)
	end,
	AddCombatItem = function(player)
		return nextItem(player, combatItems, combatItemIndex)
	end,
	SpawnLooter = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		return true, if SpawnDirector.spawnLooter(position) then "A Looter appeared" else "No room for a Looter here"
	end,
	SpawnTree = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		return true, if SpawnDirector.spawnTree(position) then "A Tree grew" else "No room for a Tree here"
	end,
	DropCrate = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		LootService.dropPickup(position, "Crate")
		return true, "Dropped a crate"
	end,
	AddNewItem = function(player)
		return nextItem(player, Config.Admin.newItems, newItemIndex)
	end,
	SpawnNewEnemy = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		local list = Config.Admin.newEnemies
		local index = (newEnemyIndex[player] or 0) % #list + 1
		newEnemyIndex[player] = index
		local enemy = Config.Enemies.types[list[index]]
		return true,
			if SpawnDirector.spawnEnemy(enemy.id, position)
				then `A {enemy.displayName} appeared`
				else `No room for a {enemy.displayName} here`
	end,
	SpawnBoss = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		local name = BossService.spawnNext(position)
		return true, if name then `{name} appeared (a test boss: the run goes on)` else "No room for a boss"
	end,
	HurtBoss = function(player)
		local count = BossService.hurtAll(Config.Admin.hurtBossShare, player)
		return true, if count > 0 then `Hurt {count} boss(es) or champion(s)` else "No boss or champion alive"
	end,
	DropLegendaryCrate = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		LootService.dropPickup(position, "Legendary")
		return true, "Dropped a legendary crate"
	end,
	SpawnChampion = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		local name = BossService.spawnNextChampion(position)
		return true, if name then `{name} appeared` else "No room for a champion"
	end,
	PrintProfile = function(player)
		local lines = PlayerDataService.dump(player)
		if not lines then
			return false, "Your saved data is not loaded yet"
		end
		print(`[Lanternfall] ===== Saved data of {player.Name} ({PlayerDataService.getSaveMode()}) =====`)
		for _, line in lines do
			print(`[Lanternfall] {line}`)
		end
		return true, "Saved data printed to the Output"
	end,
	ResetProfile = function(player)
		if RunDirector.isOngoing() then
			return false, "Only in the lobby"
		end
		if not PlayerDataService.reset(player) then
			return false, "Your saved data is not loaded yet"
		end
		return true, "Saved data reset"
	end,
	UnlockAll = function(player)
		if not PlayerDataService.unlockAll(player) then
			return false, "Your saved data is not loaded yet"
		end
		return true, "Everything unlocked (Reset my saved data locks it again)"
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
		shots = EnemySim.getShotCount(),
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

handlers.GiveStructureKit = function(player)
	if not RunDirector.isOngoing() then
		return false, "NotRunning"
	end
	for id in Config.Structures.kinds do
		StatService.addItem(player, id)
	end
	StatService.addItem(player, "CalibratedTools")
	return true, "Structure kit granted: deploys next wave"
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

	Players.PlayerRemoving:Connect(function(player)
		effectItemIndex[player] = nil
		combatItemIndex[player] = nil
		newItemIndex[player] = nil
		newEnemyIndex[player] = nil
	end)

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
