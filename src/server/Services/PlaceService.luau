--!strict
-- Which place this server is (Paket 15): the hub with lobby and parties, the run place where one group plays in a
-- reserved server, or "Single" with lobby and arena in one server (Studio file, place ids not set yet). Rules in
-- Util/PlaceRules, ids in Config.Places. Also the teleports between hub and run place with retries (TeleportService)
-- and the tickets players arrive with. Called by PartyService (hub -> run place), RunPlaceService (arrivals, "Back to
-- hub"), RunDirector and MapService (role).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local PlaceRules = require(Shared.Util.PlaceRules)
local Signal = require(Shared.Util.Signal)

local LOG_PREFIX = "[Lanternfall] "

local PlaceService = {}

-- (player: Player, message: string): a teleport of this player failed for good (after the retries)
PlaceService.TeleportFailed = Signal.new()

type Pending = {
	placeId: number,
	options: Instance, -- TeleportOptions
	fallback: Instance?, -- tried once if the target server is gone or full (way back to a hub server)
	retries: number,
}

local override: { role: PlaceRules.Role, canTeleport: boolean, experience: PlaceRules.Experience? }? = nil
local pending: { [Player]: Pending } = {}
local idCounter = 0
local announced = false

local function teleportService(): any
	return game:GetService("TeleportService")
end

-- Tests: pretend to be this place (call before the server starts). `canTeleport` false = like Studio.
function PlaceService.useRole(role: PlaceRules.Role, canTeleport: boolean, experience: PlaceRules.Experience?)
	override = { role = role, canTeleport = canTeleport, experience = experience }
end

function PlaceService.getRole(): PlaceRules.Role
	if override then
		return override.role
	end
	local role = PlaceRules.resolve(game.PlaceId, Config.Places.experiences)
	return role
end

-- The experience entry of this place (hub and run place ids), nil in "Single".
function PlaceService.getExperience(): PlaceRules.Experience?
	if override then
		return override.experience
	end
	local _, experience = PlaceRules.resolve(game.PlaceId, Config.Places.experiences)
	return experience
end

function PlaceService.isHub(): boolean
	return PlaceService.getRole() == "Hub"
end

function PlaceService.isRunPlace(): boolean
	return PlaceService.getRole() == "Run"
end

-- Roblox cannot teleport in Studio: there the hub starts runs in its own server and "Back to hub" only explains.
function PlaceService.canTeleport(): boolean
	if override then
		return override.canTeleport
	end
	return not RunService:IsStudio() and PlaceService.getExperience() ~= nil
end

-- The teleport data the player arrived with (unchecked; PlaceRules parses it), nil without one.
function PlaceService.getTeleportData(player: Player): any
	local ok, joinData = pcall(function()
		return (player :: any):GetJoinData()
	end)
	if ok and typeof(joinData) == "table" then
		return joinData.TeleportData
	end
	return nil
end

-- A new id for a group that leaves the hub together (unique enough within the experience).
function PlaceService.newPartyId(): string
	idCounter += 1
	return `{string.sub(game.JobId or "", 1, 36)}-{os.time()}-{idCounter}`
end

local function newOptions(data: { [string]: any }): any
	local options = Instance.new("TeleportOptions") :: any
	options:SetTeleportData(data)
	return options
end

-- TeleportAsync with retries; true once Roblox accepted the teleport (it may still fail later, TeleportInitFailed).
local function teleport(
	placeId: number,
	players: { Player },
	options: Instance,
	fallback: Instance?,
	attempts: number?
): (boolean, string?)
	local settings = Config.Places.teleport
	local tries = attempts or settings.attempts
	local lastError = "unknown error"
	for attempt = 1, tries do
		local present = {}
		for _, player in players do
			if player.Parent == Players then
				table.insert(present, player)
			end
		end
		if #present == 0 then
			return false, "nobody left to teleport"
		end
		for _, player in present do
			pending[player] = { placeId = placeId, options = options, fallback = fallback, retries = 0 }
		end
		local ok, err = pcall(function()
			teleportService():TeleportAsync(placeId, present, options)
		end)
		if ok then
			return true, nil
		end
		lastError = tostring(err)
		warn(`{LOG_PREFIX}Teleport attempt {attempt} failed: {lastError}`)
		if attempt < tries then
			task.wait(settings.retryDelaySeconds)
		end
	end
	for _, player in players do
		pending[player] = nil
	end
	return false, lastError
end

-- Sends a group from the hub to a new reserved server of the run place, with the ticket as teleport data. Yields.
function PlaceService.teleportToRun(players: { Player }, ticket: PlaceRules.RunTicket): (boolean, string?)
	local experience = PlaceService.getExperience()
	if not (experience and PlaceService.canTeleport()) then
		return false, "teleports are off here"
	end
	local reserved, accessCode = pcall(function()
		return teleportService():ReserveServer(experience.run)
	end)
	if not reserved or typeof(accessCode) ~= "string" then
		warn(`{LOG_PREFIX}Could not reserve a run server: {accessCode}`)
		return false, tostring(accessCode)
	end
	local options = newOptions(PlaceRules.runTicket(ticket)) :: any
	options.ReservedServerAccessCode = accessCode
	return teleport(experience.run, players, options, nil)
end

-- Sends one player from the run place back to the hub: to the hub server they came from if it still runs and has
-- room, otherwise to any hub server. Yields.
function PlaceService.teleportToHub(
	player: Player,
	ticket: PlaceRules.HubTicket?,
	hubJobId: string?
): (boolean, string?)
	local experience = PlaceService.getExperience()
	if not (experience and PlaceService.canTeleport()) then
		return false, "teleports are off here"
	end
	local data = if ticket then PlaceRules.hubTicket(ticket) else {}
	local anyServer = newOptions(data)
	if hubJobId then
		local sameServer = newOptions(data) :: any
		sameServer.ServerInstanceId = hubJobId
		local ok = teleport(experience.hub, { player }, sameServer, anyServer, 1)
		if ok then
			return true, nil
		end
	end
	return teleport(experience.hub, { player }, anyServer, nil)
end

-- Whether Roblox is teleporting the player right now (between TeleportAsync and leaving or failing).
function PlaceService.isTeleporting(player: Player): boolean
	return pending[player] ~= nil
end

-- Forgets a teleport that never finished (PartyService gives up after Config.Places.teleport.timeoutSeconds).
function PlaceService.forget(player: Player)
	pending[player] = nil
end

local RETRY_RESULTS = { Flooded = true, Failure = true }
local GONE_RESULTS = { GameEnded = true, GameFull = true, GameNotFound = true }

local function onInitFailed(player: Player, result: EnumItem, message: string)
	local entry = pending[player]
	if not entry then
		return
	end
	local settings = Config.Places.teleport
	local name = result.Name
	warn(`{LOG_PREFIX}Teleport of {player.Name} failed ({name}): {message}`)
	local retryWith: Instance? = nil
	if GONE_RESULTS[name] and entry.fallback then
		retryWith = entry.fallback
		entry.fallback = nil
	elseif RETRY_RESULTS[name] and entry.retries < settings.attempts - 1 then
		retryWith = entry.options
	end
	if not retryWith then
		pending[player] = nil
		PlaceService.TeleportFailed:Fire(player, message)
		return
	end
	entry.retries += 1
	entry.options = retryWith
	local options = retryWith
	task.delay(settings.retryDelaySeconds, function()
		if pending[player] ~= entry or player.Parent ~= Players then
			return
		end
		local ok, err = pcall(function()
			teleportService():TeleportAsync(entry.placeId, { player }, options)
		end)
		if not ok then
			pending[player] = nil
			PlaceService.TeleportFailed:Fire(player, tostring(err))
		end
	end)
end

function PlaceService.init()
	local ok, service = pcall(teleportService)
	if ok and service then
		service.TeleportInitFailed:Connect(onInitFailed)
	end
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

function PlaceService.start()
	if announced then
		return
	end
	announced = true
	local role = PlaceService.getRole()
	local experience = PlaceService.getExperience()
	if role == "Single" then
		print(`{LOG_PREFIX}Place: lobby and arena in one server (no hub/run place ids for this place in Config.Places)`)
	elseif PlaceService.canTeleport() then
		print(`{LOG_PREFIX}Place: {role} of {if experience then experience.name else "?"}`)
	else
		print(`{LOG_PREFIX}Place: {role} (Studio cannot teleport: runs start in this server)`)
	end
end

return PlaceService
