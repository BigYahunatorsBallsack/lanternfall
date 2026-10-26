--!strict
-- Network layer: creates remotes from Net/Remotes and wraps them with rate limits and validation.
-- Server bootstrap calls Net.initServer(), client bootstrap Net.waitForRemotes(); services and
-- controllers use the on/fire functions.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Definitions = require(script.Remotes)
local RateLimiter = require(script.RateLimiter)

local FOLDER_NAME = "RemoteInstances" -- not "Remotes": that name is taken by the Remotes ModuleScript
local CLIENT_WAIT_SECONDS = 30

local Net = {}

local remotes: { [string]: RemoteEvent | UnreliableRemoteEvent } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}

local function getDefinition(name: string, direction: "toServer" | "toClient"): Definitions.Definition
	local definition = Definitions[name]
	assert(definition, `Unknown remote "{name}"`)
	assert(definition.direction == direction, `Remote "{name}" is {definition.direction}, not {direction}`)
	return definition
end

local function getRemote(name: string): any
	local remote = remotes[name]
	if remote then
		return remote
	end
	assert(RunService:IsClient(), `Net.initServer() must run before using remote "{name}"`)
	local folder = script:WaitForChild(FOLDER_NAME, CLIENT_WAIT_SECONDS)
	assert(folder, "Remotes folder did not replicate")
	local found = folder:WaitForChild(name, CLIENT_WAIT_SECONDS)
	assert(found, `Remote "{name}" did not replicate`)
	remotes[name] = found :: any
	return found
end

-- Server ------------------------------------------------------------------

function Net.initServer(): number
	assert(RunService:IsServer(), "Net.initServer() is server only")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local created = 0
	for name, definition in Definitions do
		if definition.direction == "toServer" then
			assert(definition.rateLimit, `Remote "{name}" needs a rate limit`)
			assert(definition.args, `Remote "{name}" needs argument validators`)
			limiters[name] = RateLimiter.new(definition.rateLimit.count, definition.rateLimit.perSeconds)
		end
		local remote = Instance.new(if definition.unreliable then "UnreliableRemoteEvent" else "RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote :: any
		created += 1
	end
	folder.Parent = script
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:forget(player)
		end
	end)
	return created
end

-- Connects a handler for a client intent. Calls that exceed the rate limit or fail validation are dropped.
function Net.onServer(name: string, handler: (player: Player, ...any) -> ()): RBXScriptConnection
	local definition = getDefinition(name, "toServer")
	local validators = definition.args :: { any }
	local limiter = limiters[name]
	return getRemote(name).OnServerEvent:Connect(function(player: Player, ...)
		if not limiter:allow(player) then
			return
		end
		local argCount = select("#", ...)
		if argCount > #validators then
			return
		end
		local args = table.pack(...)
		for i, validator in validators do
			if not validator(args[i]) then
				return
			end
		end
		handler(player, ...)
	end)
end

function Net.fireClient(name: string, player: Player, ...: any)
	getDefinition(name, "toClient")
	getRemote(name):FireClient(player, ...)
end

function Net.fireAllClients(name: string, ...: any)
	getDefinition(name, "toClient")
	getRemote(name):FireAllClients(...)
end

-- Client ------------------------------------------------------------------

-- Waits until every remote has replicated. The client bootstrap calls this once before the controllers
-- start, so their init() can connect handlers without yielding.
function Net.waitForRemotes()
	assert(RunService:IsClient(), "Net.waitForRemotes() is client only")
	for name in Definitions do
		getRemote(name)
	end
end

function Net.fireServer(name: string, ...: any)
	getDefinition(name, "toServer")
	getRemote(name):FireServer(...)
end

function Net.onClient(name: string, handler: (...any) -> ()): RBXScriptConnection
	getDefinition(name, "toClient")
	return getRemote(name).OnClientEvent:Connect(handler)
end

return Net
