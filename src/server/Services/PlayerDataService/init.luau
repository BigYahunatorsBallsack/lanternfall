--!strict
-- Saved player data (Paket 12, DESIGN.md section 16): one ProfileStore session per player with session locking,
-- autosave and a last save on leave and shutdown. Schema in ProfileTemplate, upgrades in Migrations, run records in
-- ProfileRecords. Without DataStoreService (tests) it keeps data in MemoryStore. Called by RunDirector (class
-- checks), RunStatsService (records finished runs, resends the lobby record on sync) and AdminService (debug buttons).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)

local MemoryStore = require(script.MemoryStore)
local Migrations = require(script.Migrations)
local ProfileRecords = require(script.ProfileRecords)
local ProfileTemplate = require(script.ProfileTemplate)

local LOG_PREFIX = "[Lanternfall] "

local PlayerDataService = {}

-- (player: Player, data: ProfileTemplate.Data): the player's saved data is loaded and ready to change
PlayerDataService.Loaded = Signal.new()

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
		Net.fireClient("ProfileInfo", player, ProfileRecords.info(profile.Data, PlayerDataService.getSaveMode()))
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

local function release(player: Player)
	loading[player] = nil
	local profile = profiles[player]
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

-- Free classes are always owned; others must be unlocked in the profile.
function PlayerDataService.ownsClass(player: Player, classId: string): boolean
	local class = Config.Classes[classId]
	if not class then
		return false
	end
	if class.free then
		return true
	end
	local data = PlayerDataService.get(player)
	return data ~= nil and table.find(data.classes, classId) ~= nil
end

-- Adds a finished run to the player's record and saves it. False if the data is not loaded.
function PlayerDataService.recordRun(player: Player, run: ProfileRecords.RunRecord): boolean
	local profile = profiles[player]
	if not (profile and profile:IsActive()) then
		return false
	end
	ProfileRecords.applyRun(profile.Data, run)
	if Config.Save.saveAfterRun then
		profile:Save()
	end
	sendInfo(player)
	return true
end

-- Sends the lobby record again (the client asked for a full sync).
function PlayerDataService.sync(player: Player)
	sendInfo(player)
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
	return true
end

return PlayerDataService
