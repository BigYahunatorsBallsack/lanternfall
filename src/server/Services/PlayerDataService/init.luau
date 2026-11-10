--!strict
-- Saved player data (Paket 12, DESIGN.md section 16): one ProfileStore session per player with session locking,
-- autosave and a last save on leave and shutdown. Schema in ProfileTemplate, upgrades in Migrations, run records in
-- ProfileRecords. Without DataStoreService (tests) it keeps data in MemoryStore. Called by RunDirector (class
-- checks), RunStatsService (records finished runs, resends the lobby record on sync) and AdminService (debug buttons).
-- Since Paket 13 also Embers, achievements and unlocks (Util/ProgressRules): what is locked for a player
-- (ShopService, UpgradeService) and the danger levels open per character (RunDirector). Since Paket 14 it keeps the
-- settings from the settings menu (remote SaveSettings). Since Paket 16 it grants developer products exactly once
-- (processPurchase, for MonetizationService's ProcessReceipt). Since Paket 17 EmberShopService changes the data and
-- calls refresh. Since Paket 18 QuestService, LeaderboardService and BadgeService add to each recorded run
-- (onRunRecorded).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local ProgressRules = require(Shared.Util.ProgressRules)
local PurchaseRules = require(Shared.Util.PurchaseRules)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)
local NativeWeaponAccess = require(Shared.Config.CharacterWeaponAccess)
local NativeCharacterAccess = require(Shared.Config.CharacterUnlocks)
local CharacterAccess = require(Shared.Util.CharacterAccess)

local MemoryStore = require(script.MemoryStore)
local Migrations = require(script.Migrations)
local ProfileRecords = require(script.ProfileRecords)
local ProfileTemplate = require(script.ProfileTemplate)

local LOG_PREFIX = "[Lanternfall] "

local PlayerDataService = {}

-- (player: Player, data: ProfileTemplate.Data): the player's saved data is loaded and ready to change
PlayerDataService.Loaded = Signal.new()
-- (player: Player): unlocks or records changed after loading (finished run, debug buttons); Paket 13
PlayerDataService.Changed = Signal.new()

local store: any = nil -- ProfileStore object or MemoryStore
local profileStore: any = nil -- the ProfileStore module, nil with MemoryStore
local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local announced = false

local function dataStoreAvailable(): boolean
	return (pcall(game.GetService, game, "DataStoreService"))
end

local function keyOf(player: Player): string
	return Config.Save.keyPrefix .. tostring(player.UserId)
end

local function present(player: Player): boolean
	return player.Parent == Players
end

-- "DataStore" saves for real; "Mock" is ProfileStore's stand-in in Studio without API access (gone when the test
-- stops); "Memory" is MemoryStore (no DataStoreService).
function PlayerDataService.getSaveMode(): Types.SaveMode
	if not profileStore then
		return "Memory"
	end
	return if profileStore.DataStoreState == "Access" then "DataStore" else "Mock"
end

local function announce()
	if announced then
		return
	end
	announced = true
	local mode = PlayerDataService.getSaveMode()
	if mode == "DataStore" then
		print(`{LOG_PREFIX}Saving: on (DataStore "{Config.Save.storeName}")`)
	elseif mode == "Mock" then
		warn(
			`{LOG_PREFIX}Saving: Studio test mode, nothing is kept after the test. Turn on Game Settings -> Security -> `
				.. `"Enable Studio Access to API Services" in the test experience to save for real.`
		)
	else
		print(`{LOG_PREFIX}Saving: memory only (no DataStoreService)`)
	end
end

local function sendInfo(player: Player)
	local profile = profiles[player]
	if profile then
		local info = ProfileRecords.info(profile.Data, PlayerDataService.getSaveMode())
		info.nativeWeaponUnlocks = CharacterAccess.weaponMask(profile.Data)
		info.nativeCharacterUnlocks = CharacterAccess.characterMask(profile.Data)
		Net.fireClient("ProfileInfo", player, info)
	end
end

local function load(player: Player)
	if profiles[player] or loading[player] then
		return
	end
	loading[player] = true
	local profile = store:StartSessionAsync(keyOf(player), {
		Cancel = function()
			return not present(player)
		end,
	})
	loading[player] = nil
	if not profile then
		if present(player) then
			warn(`{LOG_PREFIX}Could not load the saved data of {player.Name}; kicked so nothing gets lost`)
			player:Kick(Config.Save.kickLoadFailed)
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR: ties the profile to the player
	local from = Migrations.run(profile.Data, ProfileTemplate.SCHEMA_VERSION)
	profile:Reconcile()
	ProfileRecords.completeAchievements(profile.Data) -- e.g. old records that already reach a goal
	if from < ProfileTemplate.SCHEMA_VERSION then
		print(`{LOG_PREFIX}Saved data of {player.Name} upgraded from schema {from} to {ProfileTemplate.SCHEMA_VERSION}`)
	elseif from > ProfileTemplate.SCHEMA_VERSION then
		warn(`{LOG_PREFIX}Saved data of {player.Name} has schema {from}, newer than this server; kept as it is`)
	end

	if not present(player) then -- left while loading
		profile:EndSession()
		return
	end
	profile.OnSessionEnd:Connect(function()
		if profiles[player] ~= profile then -- ended because the player left
			return
		end
		profiles[player] = nil
		if present(player) then
			player:Kick(Config.Save.kickSessionEnded)
		end
	end)
	profiles[player] = profile
	announce()
	PlayerDataService.Loaded:Fire(player, profile.Data)
	sendInfo(player)
end

local releaseHooks: { (Player) -> () } = {}
local recordHooks: { (Player, ProfileTemplate.Data, ProfileRecords.RunRecord, Types.RunRewards) -> () } = {}

local function release(player: Player)
	loading[player] = nil
	local profile = profiles[player]
	if profile then
		for _, hook in releaseHooks do
			local ok, err = pcall(hook, player)
			if not ok then
				task.spawn(error, `[Lanternfall] PlayerDataService release hook failed: {err}`, 0)
			end
		end
	end
	profiles[player] = nil
	if profile then
		profile:EndSession() -- last save, frees the session lock
	end
end

-- Tests: use this store (MemoryStore) instead of opening one; call before init.
function PlayerDataService.useStore(custom: any)
	store = custom
	profileStore = nil
end

function PlayerDataService.init()
	if not store then
		if dataStoreAvailable() then
			-- Vendored ProfileStore by loleris (MadStudioRoblox/ProfileStore, Apache 2.0, commit 45c9847)
			profileStore = require(script.Parent.Parent.Vendor.ProfileStore) :: any
			store = profileStore.New(Config.Save.storeName, ProfileTemplate.new())
		else
			store = MemoryStore.new(ProfileTemplate.new())
		end
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	-- Paket 14: only the values change; nothing is sent back (the client already shows them)
	Net.onServer(
		"SaveSettings",
		function(player, shake: boolean, damageNumbers: boolean, music: number, effects: number, graphics: string?)
			local data = PlayerDataService.get(player)
			if data then
				data.settings = {
					shake = shake,
					damageNumbers = damageNumbers,
					music = music,
					effects = effects,
					graphics = graphics or Config.Settings.defaults.graphics, -- Paket 22
				}
			end
		end
	)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

-- nil until the data is loaded (or after the player left). Changes to it are saved.
function PlayerDataService.get(player: Player): ProfileTemplate.Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerDataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Free classes are owned unless an achievement locks them (Paket 13: then done or bought with Embers); others must
-- be in the profile.
function PlayerDataService.ownsClass(player: Player, classId: string): boolean
	local class = Config.Classes[classId]
	if not class then
		return false
	end
	local data = PlayerDataService.get(player)
	if class.nativeStartSelection then
		return CharacterAccess.characterUnlocked(data, classId)
	end
	if class.free then
		if not ProgressRules.isLockable("characters", classId) then
			return true
		end
		return data ~= nil and ProgressRules.isUnlocked("characters", classId, data.achievements, data.classes)
	end
	return data ~= nil and table.find(data.classes, classId) ~= nil
end

-- Paket 13: whether a weapon or item is unlocked for the player (everything lockable is locked until loaded).
function PlayerDataService.isUnlocked(player: Player, kind: ProgressRules.Kind, id: string): boolean
	local data = PlayerDataService.get(player)
	if kind == "characters" and Config.Classes[id] and Config.Classes[id].nativeStartSelection then
		return CharacterAccess.characterUnlocked(data, id)
	end
	if kind == "weapons" and NativeWeaponAccess[id] then
		return CharacterAccess.weaponUnlocked(data, id)
	end
	return ProgressRules.isUnlocked(
		kind,
		id,
		if data then data.achievements else {},
		if data then data.classes else nil
	)
end

-- Paket 13: the player's locked ids of a kind as a set (the shop and crates skip them).
function PlayerDataService.lockedSet(player: Player, kind: ProgressRules.Kind): { [string]: boolean }
	local data = PlayerDataService.get(player)
	local result =
		ProgressRules.lockedSet(kind, if data then data.achievements else {}, if data then data.classes else nil)
	if kind == "weapons" then
		for id in NativeWeaponAccess do
			result[id] = if CharacterAccess.weaponUnlocked(data, id) then nil else true
		end
	elseif kind == "characters" then
		for id, class in Config.Classes do
			if class.nativeStartSelection then
				result[id] = if CharacterAccess.characterUnlocked(data, id) then nil else true
			end
		end
	elseif kind == "items" then
		for _, item in Config.Items.list do
			if item.nativeWinWith then
				local record = data and data.characterStats[item.nativeWinWith]
				local challenge = data
					and item.nativeChallenge
					and data.achievements[CharacterAccess.challengeKey(item.nativeChallenge)]
				result[item.id] = if challenge or (record and record.wins > 0) then nil else true
			end
		end
	end
	return result
end

-- The original lifetime challenge counts completed sites; online credit is restricted to live completion participants.
function PlayerDataService.observeNativeDigSite(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local rule = require(Shared.Config.Digging)
	data.nativeCounts.digSitesDug += 1
	if data.nativeCounts.digSitesDug >= rule.unlockCount then
		data.achievements[CharacterAccess.challengeKey(rule.challengeId)] = true
	end
	sendInfo(player)
	PlayerDataService.Changed:Fire(player)
end

-- Native stat challenges persist in the existing string-keyed achievement map; no profile field is replaced.
function PlayerDataService.observeNativeStats(player: Player, sheet: { [string]: number })
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local changed = false
	local function observe(stat: string?, threshold: number?, challengeId: string?, comparison: string?)
		local value = if stat then sheet[stat] or 0 else 0
		if
			stat
			and threshold
			and challengeId
			and (if comparison == "AtMost" then value <= threshold else value >= threshold)
		then
			local key = CharacterAccess.challengeKey(challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				changed = true
			end
		end
	end
	for _, rule in NativeWeaponAccess do
		observe(rule.stat, rule.threshold, rule.challengeId)
	end
	for _, rule in NativeCharacterAccess do
		if rule.kind == "Stat" then
			observe(rule.stat, rule.threshold, rule.challengeId, rule.comparison)
		end
	end
	if changed then
		sendInfo(player)
		PlayerDataService.Changed:Fire(player)
	end
end

-- Inventory challenges observe simultaneous personal equipment and stats, never spawned-object snapshots.
function PlayerDataService.observeNativeInventory(
	player: Player,
	counts: { [string]: number },
	sheet: { [string]: number },
	atWaveStart: boolean?
)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local changed = false
	for _, rule in NativeCharacterAccess do
		if
			rule.kind == "Inventory"
			and (not rule.waveStart or atWaveStart == true)
			and (counts[rule.count] or 0) >= rule.threshold
			and (not rule.stat or (sheet[rule.stat] or 0) >= (rule.statThreshold or 0))
		then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				changed = true
			end
		end
	end
	if changed then
		sendInfo(player)
		PlayerDataService.Changed:Fire(player)
	end
end

-- Medicine uses the native accepted-healing sum for one wave, separate from capped HP gains/Lich.
function PlayerDataService.observeNativeHealing(player: Player, total: number)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local changed = false
	for _, rule in NativeCharacterAccess do
		if rule.kind == "WaveHealing" and total >= rule.threshold then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				changed = true
			end
		end
	end
	if changed then
		sendInfo(player)
		PlayerDataService.Changed:Fire(player)
	end
end

-- Fireworks observes a single completed blast; independent explosions never add together.
function PlayerDataService.observeNativeExplosion(player: Player, kills: number)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	for _, rule in NativeCharacterAccess do
		if rule.kind == "ExplosionKills" and kills >= rule.threshold then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				sendInfo(player)
				PlayerDataService.Changed:Fire(player)
			end
		end
	end
end

-- Recycling counts actual weapon sales in one run, excluding merges and forced destruction.
function PlayerDataService.observeNativeRecycling(player: Player, total: number)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	for _, rule in NativeCharacterAccess do
		if rule.kind == "RunRecycledWeapons" and total >= rule.threshold then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				sendInfo(player)
				PlayerDataService.Changed:Fire(player)
			end
		end
	end
end

-- Forest is observed only after a successful wave and before its surviving trees are cleaned up.
function PlayerDataService.observeNativeWaveTrees(player: Player, trees: number)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	for _, rule in NativeCharacterAccess do
		if rule.kind == "WaveLivingTrees" and trees >= rule.threshold then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				sendInfo(player)
				PlayerDataService.Changed:Fire(player)
			end
		end
	end
end

-- Native Survivor counts personally credited enemies, excluding trees and despawn/cleanup.
function PlayerDataService.observeNativeEnemyKill(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	data.nativeCounts.enemiesKilled += 1
	for _, rule in NativeCharacterAccess do
		if rule.kind == "EnemiesKilled" and data.nativeCounts.enemiesKilled >= rule.threshold then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				sendInfo(player)
				PlayerDataService.Changed:Fire(player)
			end
		end
	end
end

-- Reckless is an exact alive wave-end HP check, before wave healing/rewards.
function PlayerDataService.observeNativeWaveHp(player: Player, hp: number)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	for _, rule in NativeCharacterAccess do
		if rule.kind == "WaveHp" and hp == rule.threshold then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				sendInfo(player)
				PlayerDataService.Changed:Fire(player)
			end
		end
	end
end

function PlayerDataService.observeNativeTreeKill(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	data.nativeCounts.treesKilled += 1
	for _, rule in NativeCharacterAccess do
		if rule.kind == "TreesKilled" and data.nativeCounts.treesKilled >= rule.threshold then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				sendInfo(player)
				PlayerDataService.Changed:Fire(player)
			end
		end
	end
end

-- Native Gatherer counts physical pickups once, even when their material value is doubled or shared.
function PlayerDataService.observeNativeMaterials(player: Player, count: number)
	local data = PlayerDataService.get(player)
	if not data or count <= 0 then
		return
	end
	data.nativeCounts.materialsCollected += count
	for _, rule in NativeCharacterAccess do
		if rule.kind == "MaterialsCollected" and data.nativeCounts.materialsCollected >= rule.threshold then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				sendInfo(player)
				PlayerDataService.Changed:Fire(player)
			end
		end
	end
end

-- Native Hungry challenge receives the authoritative per-run count from CharacterService.
function PlayerDataService.observeNativeConsumption(player: Player, count: number)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	for _, rule in NativeCharacterAccess do
		if rule.kind == "RunConsumables" and count >= rule.threshold then
			local key = CharacterAccess.challengeKey(rule.challengeId)
			if not data.achievements[key] then
				data.achievements[key] = true
				sendInfo(player)
				PlayerDataService.Changed:Fire(player)
			end
		end
	end
end

-- Paket 13: highest danger level open for this character (start level until loaded).
function PlayerDataService.maxDanger(player: Player, classId: string?): number
	local data = PlayerDataService.get(player)
	if not data then
		return ProgressRules.maxDanger({ stats = {}, characterStats = {} }, nil)
	end
	return ProgressRules.maxDanger(data :: any, classId)
end

-- Adds a finished run to the player's record (since Paket 13 with Embers and achievements), saves it and sends the
-- rewards to the player (RunRewards, a Notify per achievement). False if the data is not loaded; true plus the
-- rewards otherwise.
function PlayerDataService.recordRun(player: Player, run: ProfileRecords.RunRecord): (boolean, Types.RunRewards?)
	local profile = profiles[player]
	if not (profile and profile:IsActive()) then
		return false, nil
	end
	local rewards = ProfileRecords.applyRun(profile.Data, run)
	for _, hook in recordHooks do -- Paket 18: quests, leaderboards, badges
		local ok, err = pcall(hook, player, profile.Data, run, rewards)
		if not ok then
			task.spawn(error, `[Lanternfall] PlayerDataService run hook failed: {err}`, 0)
		end
	end
	rewards.totalEmbers = profile.Data.embers
	if Config.Save.saveAfterRun then
		profile:Save()
	end
	sendInfo(player)
	Net.fireClient("RunRewards", player, rewards)
	for _, id in rewards.achievements do
		local achievement = ProgressRules.get(id) :: any
		local names = ProgressRules.unlockNames(achievement)
		local unlock = if #names > 0 then ` - unlocked {table.concat(names, ", ")}` else ""
		Net.fireClient("Notify", player, `Achievement: {achievement.name}{unlock}`)
	end
	PlayerDataService.Changed:Fire(player)
	return true, rewards
end

-- Paket 16: "Granted" once the purchase is in the saved data (tell Roblox PurchaseGranted), "Retry" if that is not
-- certain yet (NotProcessedYet: Roblox asks again later, also in another server).
export type PurchaseResult = "Granted" | "Retry"

-- Paket 16: grants a developer product exactly once (DESIGN.md section 16, ProfileStore's receipt pattern). Waits up
-- to Config.Store.receiptWaitSeconds for the player's data to load. A PurchaseId the data does not know yet runs
-- `apply(data)` (must not yield) and is remembered with it; then the purchase counts as granted only once a save holds
-- the PurchaseId. Yields. Returns the result and whether `apply` ran now (false for a repeated receipt).
function PlayerDataService.processPurchase(
	player: Player,
	purchaseId: string,
	apply: (data: ProfileTemplate.Data) -> ()
): (PurchaseResult, boolean)
	local deadline = os.clock() + Config.Store.receiptWaitSeconds
	while not profiles[player] and present(player) and os.clock() < deadline do
		task.wait(0.1)
	end
	local profile = profiles[player]
	if not (profile and profile:IsActive()) then
		return "Retry", false
	end
	local applied = false
	if not PurchaseRules.knows(profile.Data.receipts, purchaseId) then
		apply(profile.Data)
		PurchaseRules.remember(profile.Data.receipts, purchaseId, Config.Store.receiptMemory)
		applied = true
		sendInfo(player)
	end
	local function saved(): boolean
		local last = profile.LastSavedData
		return type(last) == "table"
			and type(last.receipts) == "table"
			and PurchaseRules.knows(last.receipts, purchaseId)
	end
	if saved() then
		return "Granted", applied
	end
	local done = false
	local connection = profile.OnAfterSave:Connect(function()
		done = done or saved()
	end)
	profile:Save()
	while not done and profile:IsActive() and os.clock() < deadline do
		task.wait(0.1)
	end
	connection:Disconnect()
	return if done or saved() then "Granted" else "Retry", applied
end

-- B11 part 2: `hook(player)` runs right before a leaving player's data is saved for the last time (RunStatsService
-- records a run it held back for "Retry wave").
function PlayerDataService.onRelease(hook: (Player) -> ())
	table.insert(releaseHooks, hook)
end

-- Paket 18: `hook(player, data, run, rewards)` runs for every recorded run, after the run's Embers and achievements
-- and before the save; it may change the data and add Embers and lines to `rewards` (must not yield).
function PlayerDataService.onRunRecorded(hook: (
	Player,
	ProfileTemplate.Data,
	ProfileRecords.RunRecord,
	Types.RunRewards
) -> ())
	table.insert(recordHooks, hook)
end

-- Debug button (Paket 13): every achievement done, without paying its Embers.
function PlayerDataService.unlockAll(player: Player): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	for _, achievement in Config.Progress.achievements do
		data.achievements[achievement.id] = true
	end
	for _, rule in NativeWeaponAccess do
		if rule.challengeId then
			data.achievements[CharacterAccess.challengeKey(rule.challengeId)] = true
		end
	end
	for classId, class in Config.Classes do
		if class.available then
			if class.native and not class.free and not table.find(data.classes, classId) then
				table.insert(data.classes, classId)
			end
			local character = data.characterStats[classId] or ProfileTemplate.newCharacterStats()
			character.bestDanger = #Config.Difficulty.levels - 2 -- opens the highest level
			data.characterStats[classId] = character
		end
	end
	sendInfo(player)
	PlayerDataService.Changed:Fire(player)
	return true
end

-- Sends the lobby record again (the client asked for a full sync).
function PlayerDataService.sync(player: Player)
	sendInfo(player)
end

-- Paket 17: the data was changed from outside (Ember shop): sends the lobby record and fires Changed (unlocks).
function PlayerDataService.refresh(player: Player)
	sendInfo(player)
	PlayerDataService.Changed:Fire(player)
end

-- Debug button: every saved value as lines for the Output; nil if not loaded.
function PlayerDataService.dump(player: Player): { string }?
	local profile = profiles[player]
	return if profile then ProfileRecords.dump(profile.Data) else nil
end

-- Debug button: back to fresh data (keeps the session; saved with the next save).
function PlayerDataService.reset(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local data = profile.Data
	for key in table.clone(data) do
		data[key] = nil
	end
	for key, value in ProfileTemplate.new() :: any do
		data[key] = value
	end
	profile:Save()
	sendInfo(player)
	PlayerDataService.Changed:Fire(player)
	return true
end

return PlayerDataService
