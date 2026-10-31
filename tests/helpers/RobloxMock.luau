-- Simulated Roblox engine for smoke tests: instances as property bags, signals, a task scheduler with
-- a fake clock, Players with characters, remotes that copy their arguments like the network does.
-- Loaded by specs via loadHelper("tests/helpers/RobloxMock.luau"); returns a `world` table.
-- Every error inside a spawned thread is collected in world.errors, so a spec can assert there were none.

local world = { errors = {}, instances = {}, frame = 0 }
local clock = { now = 1000 }
world.clock = clock

local realTypeof = typeof

local function recordError(message)
	table.insert(world.errors, message)
	print(`ERROR {message}`)
end

-- Scheduler -------------------------------------------------------------------

local queue = {}

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		recordError(debug.traceback(co, tostring(err)))
	end
end

local function toThread(callback)
	if type(callback) == "thread" then
		return callback
	end
	return coroutine.create(function(...)
		return callback(...)
	end)
end

local task = {}
function task.spawn(callback, ...)
	local co = toThread(callback)
	resume(co, ...)
	return co
end
function task.defer(callback, ...)
	local co = toThread(callback)
	table.insert(queue, { at = clock.now, frame = world.frame + 1, co = co, args = table.pack(...) })
	return co
end
function task.delay(seconds, callback, ...)
	local co = toThread(callback)
	table.insert(queue, { at = clock.now + (seconds or 0), frame = world.frame + 1, co = co, args = table.pack(...) })
	return co
end
function task.wait(seconds)
	local co = coroutine.running()
	assert(coroutine.isyieldable(), "task.wait called outside a yieldable thread")
	local startedAt = clock.now
	table.insert(queue, { at = clock.now + (seconds or 0), frame = world.frame + 1, co = co, args = table.pack() })
	coroutine.yield()
	return clock.now - startedAt
end
function task.cancel(co)
	for i = #queue, 1, -1 do
		if queue[i].co == co then
			table.remove(queue, i)
		end
	end
end

local function runDue()
	local guard = 0
	while true do
		guard += 1
		assert(guard < 10000, "scheduler loop")
		local index = nil
		for i, item in queue do
			if item.at <= clock.now and item.frame <= world.frame then
				index = i
				break
			end
		end
		if not index then
			return
		end
		local item = table.remove(queue, index)
		if coroutine.status(item.co) == "suspended" then
			resume(item.co, table.unpack(item.args, 1, item.args.n))
		end
	end
end

-- Signals ---------------------------------------------------------------------

local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(handler)
		local connection = { Connected = true }
		self.handlers[connection] = handler
		function connection.Disconnect()
			connection.Connected = false
			signal.handlers[connection] = nil
		end
		return connection
	end
	function signal:Once(handler)
		local connection
		connection = self:Connect(function(...)
			connection.Disconnect()
			handler(...)
		end)
		return connection
	end
	function signal:Fire(...)
		local list = {}
		for _, handler in self.handlers do
			table.insert(list, handler)
		end
		for _, handler in list do
			task.spawn(handler, ...)
		end
	end
	return signal
end
world.newSignal = newSignal

-- Datatypes -------------------------------------------------------------------

local Vector3 = { __type = "Vector3" }
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	end
	error(`{key} is not a valid member of Vector3`, 2)
end
Vector3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__div = function(a, b)
	return v3(a.X / b, a.Y / b, a.Z / b)
end
Vector3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
Vector3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3.__tostring = function(v)
	return `{v.X}, {v.Y}, {v.Z}`
end
local Vector3Lib = {
	new = v3,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

local Vector2Meta = { __type = "Vector2" }
Vector2Meta.__index = Vector2Meta
Vector2Meta.__mul = function(a, b)
	return setmetatable({ X = a.X * b, Y = a.Y * b }, Vector2Meta)
end
local Vector2Lib = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, Vector2Meta)
	end,
}

local CFrameMeta = { __type = "CFrame" }
CFrameMeta.__index = function(_, key)
	if key == "LookVector" then
		return v3(0, 0, -1) -- rotation is not simulated
	end
	return CFrameMeta[key]
end
local function cf(position)
	return setmetatable({ Position = position }, CFrameMeta)
end
CFrameMeta.__mul = function(a, b)
	if getmetatable(b) == CFrameMeta then
		return cf(a.Position + b.Position)
	end
	return a.Position + b
end
local CFrameLib = {
	new = function(x, y, z)
		if type(x) == "table" then
			return cf(x)
		end
		return cf(v3(x, y, z))
	end,
	lookAt = function(position)
		return cf(position)
	end,
	Angles = function()
		return cf(v3(0, 0, 0)) -- rotation is not simulated
	end,
}

local function plainType(typeName)
	return { __type = typeName }
end
local Color3Meta = plainType("Color3")
Color3Meta.__index = {
	Lerp = function(self, other, alpha)
		return setmetatable({
			R = self.R + (other.R - self.R) * alpha,
			G = self.G + (other.G - self.G) * alpha,
			B = self.B + (other.B - self.B) * alpha,
		}, Color3Meta)
	end,
}
local Color3Lib = {
	new = function(r, g, b)
		return setmetatable({ R = r, G = g, B = b }, Color3Meta)
	end,
	fromRGB = function(r, g, b)
		return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, Color3Meta)
	end,
}
local UDimMeta = plainType("UDim")
local UDimLib = {
	new = function(scale, offset)
		return setmetatable({ Scale = scale, Offset = offset }, UDimMeta)
	end,
}
local UDim2Meta = plainType("UDim2")
local function udim2(xs, xo, ys, yo)
	return setmetatable({ X = UDimLib.new(xs, xo), Y = UDimLib.new(ys, yo) }, UDim2Meta)
end
local UDim2Lib = {
	new = udim2,
	fromOffset = function(x, y)
		return udim2(0, x, 0, y)
	end,
	fromScale = function(x, y)
		return udim2(x, 0, y, 0)
	end,
}
-- Particle value types only carry their arguments.
local function argsType(typeName)
	return {
		new = function(...)
			return setmetatable({ args = { ... } }, plainType(typeName))
		end,
	}
end
local NumberSequenceLib = argsType("NumberSequence")
local NumberSequenceKeypointLib = argsType("NumberSequenceKeypoint")
local NumberRangeLib = argsType("NumberRange")
local ColorSequenceLib = argsType("ColorSequence")
local TweenInfoLib = {
	new = function(...)
		return setmetatable({ args = { ... } }, plainType("TweenInfo"))
	end,
}
-- Random.new(seed) is deterministic like Roblox's (xorshift32 here, other numbers than Roblox); without a seed it
-- follows math.random, so math.randomseed still controls it.
local function seededRandom(seed)
	local state = bit32.bxor(math.floor(seed) % 4294967296, 0x9E3779B9)
	if state == 0 then
		state = 1
	end
	local function nextUnit()
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state / 4294967296
	end
	return {
		NextNumber = function(_, a, b)
			return (a or 0) + nextUnit() * ((b or 1) - (a or 0))
		end,
		NextInteger = function(_, a, b)
			return a + math.min(b - a, math.floor(nextUnit() * (b - a + 1)))
		end,
	}
end

local RandomLib = {
	new = function(seed)
		if seed ~= nil then
			return seededRandom(seed)
		end
		return {
			NextNumber = function(_, a, b)
				return (a or 0) + math.random() * ((b or 1) - (a or 0))
			end,
			NextInteger = function(_, a, b)
				return math.random(a, b)
			end,
		}
	end,
}

local enumCache = {}
local EnumLib = setmetatable({}, {
	__index = function(_, typeName)
		local items = enumCache[typeName]
		if not items then
			items = setmetatable({}, {
				__index = function(itemsTable, itemName)
					local item =
						setmetatable({ Name = itemName, EnumType = typeName, Value = 0 }, plainType("EnumItem"))
					rawset(itemsTable, itemName, item)
					return item
				end,
			})
			enumCache[typeName] = items
		end
		return items
	end,
})

-- Instances -------------------------------------------------------------------

local SUPERCLASS = {
	Part = "BasePart",
	WedgePart = "BasePart",
	SpawnLocation = "Part",
	BasePart = "PVInstance",
	Model = "PVInstance",
	PVInstance = "Instance",
	Frame = "GuiObject",
	TextLabel = "GuiObject",
	ScrollingFrame = "GuiObject", -- Paket 13
	TextButton = "GuiButton",
	GuiButton = "GuiObject",
	GuiObject = "GuiBase2d",
	ScreenGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	GuiBase2d = "Instance",
	RemoteEvent = "BaseRemoteEvent",
	UnreliableRemoteEvent = "BaseRemoteEvent",
	BaseRemoteEvent = "Instance",
}

local EVENTS = {
	Activated = true,
	OnServerEvent = true,
	OnClientEvent = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Heartbeat = true,
	RenderStepped = true,
	Stepped = true,
	Died = true,
	Changed = true,
	AncestryChanged = true,
	-- Paket 14: tooltips and the settings menu
	MouseEnter = true,
	MouseLeave = true,
	MouseMoved = true,
	InputBegan = true,
	-- Paket 15: portals and teleports
	Triggered = true,
	TeleportInitFailed = true,
	-- Paket 16: purchases
	PromptGamePassPurchaseFinished = true,
}

local function isA(className, target)
	local current = className
	while current do
		if current == target then
			return true
		end
		current = SUPERCLASS[current]
	end
	return target == "Instance"
end

-- Roblox copies remote arguments; reject what the network cannot carry.
local function networkCopy(value, path)
	local kind = type(value)
	if kind == "function" or kind == "thread" then
		error(`remote argument {path} is a {kind}, which cannot be sent`, 3)
	elseif kind ~= "table" then
		return value
	end
	local meta = getmetatable(value)
	if meta ~= nil then
		return value -- datatypes and instances pass through
	end
	local count, hasString = 0, false
	for key in value do
		if type(key) == "string" then
			hasString = true
		elseif type(key) == "number" then
			count += 1
		else
			error(`remote argument {path} has a {type(key)} key`, 3)
		end
	end
	if hasString and count > 0 then
		error(`remote argument {path} mixes array and dictionary keys`, 3)
	end
	if count > 0 and count ~= #value then
		error(`remote argument {path} is an array with holes`, 3)
	end
	local copy = {}
	for key, item in value do
		copy[key] = networkCopy(item, `{path}.{key}`)
	end
	return copy
end

local function copyArgs(...)
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = networkCopy(args[i], `#{i}`)
	end
	return table.unpack(args, 1, args.n)
end

local InstanceMeta = { __type = "Instance" }
local methods = {}

-- Properties every new part starts with, as in Roblox.
local PART_DEFAULTS = { Transparency = 0, LocalTransparencyModifier = 0 }

local function newInstance(className, props)
	local instance = setmetatable({}, InstanceMeta)
	local initial = { ClassName = className, Name = className }
	if isA(className, "BasePart") then
		for key, value in PART_DEFAULTS do
			initial[key] = value
		end
	end
	rawset(instance, "__props", initial)
	rawset(instance, "__children", {})
	rawset(instance, "__events", {})
	rawset(instance, "__attributes", {})
	rawset(instance, "__changed", {})
	rawset(instance, "__attributeChanged", {})
	table.insert(world.instances, instance)
	for key, value in props or {} do
		instance[key] = value
	end
	return instance
end

InstanceMeta.__index = function(instance, key)
	local method = methods[key]
	if method then
		return method
	end
	local props = rawget(instance, "__props")
	local value = props[key]
	if value ~= nil then
		return value
	end
	if key == "Parent" then
		return nil
	end
	if key == "CFrame" and props.Position ~= nil then
		return cf(props.Position) -- Paket 17: a part placed by Position (rotation is not simulated)
	end
	if EVENTS[key] then
		local events = rawget(instance, "__events")
		events[key] = events[key] or newSignal()
		return events[key]
	end
	-- a child by name, like instance.Humanoid
	for _, child in rawget(instance, "__children") do
		if child.Name == key then
			return child
		end
	end
	return nil
end

InstanceMeta.__newindex = function(instance, key, value)
	local props = rawget(instance, "__props")
	if key == "Parent" then
		local old = props.Parent
		if old ~= nil and getmetatable(old) == InstanceMeta then
			local siblings = rawget(old, "__children")
			for i, child in siblings do
				if child == instance then
					table.remove(siblings, i)
					break
				end
			end
		end
		props.Parent = value
		if value ~= nil and getmetatable(value) == InstanceMeta then
			table.insert(rawget(value, "__children"), instance)
		end
		return
	end
	local changed = props[key] ~= value
	props[key] = value
	local signal = rawget(instance, "__changed")[key]
	if changed and signal then
		signal:Fire()
	end
end

InstanceMeta.__tostring = function(instance)
	return instance.Name
end

function methods.GetChildren(self)
	return table.clone(rawget(self, "__children"))
end
function methods.GetDescendants(self)
	local list = {}
	local function walk(node)
		for _, child in rawget(node, "__children") do
			table.insert(list, child)
			walk(child)
		end
	end
	walk(self)
	return list
end
function methods.FindFirstChild(self, name, recursive)
	for _, child in rawget(self, "__children") do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in rawget(self, "__children") do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	local child = self:FindFirstChild(name)
	if not child then
		recordError(`WaitForChild({name}) on {self.Name} would wait forever`)
	end
	return child
end
function methods.FindFirstChildOfClass(self, className)
	for _, child in rawget(self, "__children") do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end
function methods.IsA(self, className)
	return isA(self.ClassName, className)
end
function methods.Destroy(self)
	self.Parent = nil
	for _, child in self:GetChildren() do
		child:Destroy()
	end
end
function methods.GetPropertyChangedSignal(self, name)
	local signals = rawget(self, "__changed")
	signals[name] = signals[name] or newSignal()
	return signals[name]
end
function methods.SetAttribute(self, name, value)
	local attributes = rawget(self, "__attributes")
	local changed = attributes[name] ~= value
	attributes[name] = value
	local signal = rawget(self, "__attributeChanged")[name]
	if changed and signal then
		signal:Fire()
	end
end
function methods.GetAttribute(self, name)
	return rawget(self, "__attributes")[name]
end
function methods.GetAttributeChangedSignal(self, name)
	local signals = rawget(self, "__attributeChanged")
	signals[name] = signals[name] or newSignal()
	return signals[name]
end
function methods.PivotTo(self, cframe)
	local root = self:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
		root.Position = cframe.Position
	end
end
function methods.RequestStreamAroundAsync() end
function methods.SetStateEnabled() end
function methods.SetCoreGuiEnabled() end
function methods.BindToRenderStep(self, name, _, callback)
	world.renderSteps[name] = callback
end
-- ContextActionService: actions are stored so tests can press their keys with world.pressAction.
function methods.BindActionAtPriority(_, name, callback)
	world.actions[name] = callback
end
-- Rough top-down projection for Camera: 10 pixels per stud around the camera's x/z (0, 0 without a CFrame).
function methods.WorldToViewportPoint(self, position)
	local center = if self.CFrame then self.CFrame.Position else v3(0, 0, 0)
	local size = self.ViewportSize
	local x = size.X / 2 + (position.X - center.X) * 10
	local y = size.Y / 2 + (position.Z - center.Z) * 10
	return v3(x, y, 10), x >= 0 and x <= size.X and y >= 0 and y <= size.Y
end
-- Trail and Beam segments are not simulated.
function methods.Clear() end
-- ParticleEmitter: counts emitted particles in world.particlesEmitted.
function methods.Emit(_, count)
	world.particlesEmitted = (world.particlesEmitted or 0) + (count or 1)
end
function methods.BulkMoveTo(self, parts, cframes)
	if self ~= world.workspace then
		error("BulkMoveTo is only on Workspace", 2)
	end
	if #parts ~= #cframes then
		error(`BulkMoveTo got {#parts} parts but {#cframes} CFrames`, 2)
	end
	for i, part in parts do
		if not part:IsA("BasePart") then
			error(`BulkMoveTo item {i} is not a BasePart`, 2)
		end
		part.CFrame = cframes[i]
		part.Position = cframes[i].Position
	end
	world.bulkMoves = (world.bulkMoves or 0) + 1
end
function methods.FireServer(self, ...)
	self.OnServerEvent:Fire(world.localPlayer, copyArgs(...))
end
function methods.FireClient(self, player, ...)
	if player == world.localPlayer then
		self.OnClientEvent:Fire(copyArgs(...))
	end
end
function methods.FireAllClients(self, ...)
	if world.localPlayer then
		self.OnClientEvent:Fire(copyArgs(...))
	end
end
function methods.Create(_, target, _, goals)
	return {
		Play = function()
			for key, value in goals do
				target[key] = value
			end
		end,
	}
end

-- Paket 15: TeleportOptions keep their data; players return what world.addPlayer gave them as join data.
function methods.SetTeleportData(self, data)
	self.TeleportData = data
end
function methods.GetTeleportData(self)
	return self.TeleportData
end
function methods.GetJoinData(self)
	return { TeleportData = self.JoinTeleportData }
end
-- TeleportService: reserved servers are numbered, teleports are recorded in world.teleports (world.teleportError
-- makes TeleportAsync throw, like a Roblox error).
world.teleports = {}
world.reservedServers = 0
function methods.ReserveServer(_, placeId)
	world.reservedServers += 1
	return `access-{placeId}-{world.reservedServers}`, `server-{world.reservedServers}`
end
function methods.TeleportAsync(_, placeId, players, options)
	if world.teleportError then
		error(world.teleportError, 2)
	end
	table.insert(world.teleports, { placeId = placeId, players = table.clone(players), options = options })
end

-- Paket 16: MarketplaceService. world.ownedPasses["userId:passId"] = true owns a pass, world.marketError makes the
-- calls throw, world.robuxPrices[id] is what GetProductInfo reports; prompts are recorded in world.prompts and
-- world.buyProduct runs ProcessReceipt like Roblox does after a purchase.
world.ownedPasses = {}
world.robuxPrices = {}
world.prompts = {}
function methods.UserOwnsGamePassAsync(_, userId, passId)
	if world.marketError then
		error(world.marketError, 2)
	end
	return world.ownedPasses[`{userId}:{passId}`] == true
end
function methods.GetProductInfo(_, id, infoType)
	if world.marketError then
		error(world.marketError, 2)
	end
	return { PriceInRobux = world.robuxPrices[id] or 0, InfoType = infoType }
end
function methods.PromptProductPurchase(_, player, id)
	table.insert(world.prompts, { kind = "Product", player = player, id = id })
end
function methods.PromptGamePassPurchase(_, player, id)
	table.insert(world.prompts, { kind = "Pass", player = player, id = id })
end

-- Paket 18: BadgeService records awards in world.badges["userId:badgeId"] (world.badgeError makes the calls throw),
-- UserService names offline players, Players:GetFriendsAsync lists world.friends[userId] on one page.
world.badges = {}
world.friends = {}
function methods.UserHasBadgeAsync(_, userId, badgeId)
	if world.badgeError then
		error(world.badgeError, 2)
	end
	return world.badges[`{userId}:{badgeId}`] == true
end
function methods.AwardBadge(_, userId, badgeId)
	if world.badgeError then
		error(world.badgeError, 2)
	end
	world.badges[`{userId}:{badgeId}`] = true
	return true
end
function methods.GetUserInfosByUserIdsAsync(_, ids)
	local infos = {}
	for _, id in ids do
		table.insert(infos, { Id = id, Username = `user{id}`, DisplayName = `User {id}` })
	end
	return infos
end
function methods.GetFriendsAsync(_, userId)
	local page = {}
	for _, id in world.friends[userId] or {} do
		table.insert(page, { Id = id, Username = `user{id}`, DisplayName = `User {id}`, IsOnline = false })
	end
	return {
		IsFinished = true,
		GetCurrentPage = function()
			return page
		end,
		AdvanceToNextPageAsync = function() end,
	}
end

-- Paket 20: AnalyticsService records every call in world.analytics as { method, player, args }
-- (world.analyticsError makes the calls throw).
world.analytics = {}
for _, method in
	{
		"LogOnboardingFunnelStepEvent",
		"LogFunnelStepEvent",
		"LogEconomyEvent",
		"LogProgressionStartEvent",
		"LogProgressionCompleteEvent",
		"LogProgressionFailEvent",
		"LogCustomEvent",
	}
do
	methods[method] = function(_, player, ...)
		if world.analyticsError then
			error(world.analyticsError, 2)
		end
		table.insert(world.analytics, { method = method, player = player, args = table.pack(...) })
	end
end

local InstanceLib = { new = newInstance }

-- Services ----------------------------------------------------------------------

local Players = newInstance("Players", { Name = "Players" })
local RunService = newInstance("RunService", { Name = "RunService" })
local Workspace = newInstance("Workspace", { Name = "Workspace" })
local TweenService = newInstance("TweenService", { Name = "TweenService" })
local ContextActionService = newInstance("ContextActionService", { Name = "ContextActionService" })
local StarterGui = newInstance("StarterGui", { Name = "StarterGui" })
local SoundService = newInstance("SoundService", { Name = "SoundService" }) -- Paket 14
local TeleportService = newInstance("TeleportService", { Name = "TeleportService" }) -- Paket 15
local MarketplaceService = newInstance("MarketplaceService", { Name = "MarketplaceService" }) -- Paket 16
local BadgeService = newInstance("BadgeService", { Name = "BadgeService" }) -- Paket 18
local AnalyticsService = newInstance("AnalyticsService", { Name = "AnalyticsService" }) -- Paket 20
local UserService = newInstance("UserService", { Name = "UserService" }) -- Paket 18
local UserInputService =
	newInstance("UserInputService", { Name = "UserInputService", TouchEnabled = false, KeyboardEnabled = true })
world.renderSteps = {}
world.actions = {}
Workspace.CurrentCamera = newInstance("Camera", { ViewportSize = Vector2Lib.new(1280, 720) })
world.workspace = Workspace

function methods.GetPlayers(self)
	if self ~= Players then
		error("GetPlayers is only on Players", 2)
	end
	return self:GetChildren()
end
function methods.GetPlayerByUserId(_, userId)
	for _, player in Players:GetChildren() do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end
function methods.GetServerTimeNow()
	return clock.now
end
function methods.IsStudio()
	return true
end
function methods.IsServer()
	return true
end
function methods.IsClient()
	return true
end

__services.Players = Players
__services.RunService = RunService
__services.Workspace = Workspace
__services.TweenService = TweenService
__services.ContextActionService = ContextActionService
__services.StarterGui = StarterGui
__services.SoundService = SoundService
__services.TeleportService = TeleportService
__services.MarketplaceService = MarketplaceService
world.market = MarketplaceService
__services.BadgeService = BadgeService
__services.AnalyticsService = AnalyticsService
__services.UserService = UserService
game.PlaceId = 0
game.GameId = 0
game.JobId = ""
__services.UserInputService = UserInputService
game.CreatorType = EnumLib.CreatorType.User
game.CreatorId = 0

-- Globals -------------------------------------------------------------------------

_G.task = task
_G.Instance = InstanceLib
_G.Vector3 = Vector3Lib
_G.Vector2 = Vector2Lib
_G.CFrame = CFrameLib
_G.Color3 = Color3Lib
_G.UDim = UDimLib
_G.UDim2 = UDim2Lib
_G.TweenInfo = TweenInfoLib
_G.NumberSequence = NumberSequenceLib
_G.NumberSequenceKeypoint = NumberSequenceKeypointLib
_G.NumberRange = NumberRangeLib
_G.ColorSequence = ColorSequenceLib
_G.Random = RandomLib
_G.Enum = EnumLib
_G.workspace = Workspace
-- Paket 18: os.time follows the fake clock from a fixed date (2027-01-01 00:00 UTC + clock.now), so daily quests and
-- weekly leaderboards are the same in every test run
world.unixBase = 1798761600
_G.os = setmetatable({
	clock = function()
		return clock.now
	end,
	time = function()
		return world.unixBase + math.floor(clock.now)
	end,
}, { __index = os })
_G.typeof = function(value)
	local meta = getmetatable(value)
	if type(meta) == "table" and rawget(meta, "__type") then
		return meta.__type
	end
	return realTypeof(value)
end

-- World API --------------------------------------------------------------------------

-- One frame: advance the clock, fire Heartbeat, run due threads.
function world.step(dt)
	dt = dt or 1 / 30
	clock.now += dt
	world.frame += 1
	runDue()
	RunService.Heartbeat:Fire(dt)
	RunService.RenderStepped:Fire(dt)
	for _, callback in world.renderSteps do
		callback(dt)
	end
	runDue()
end

function world.advance(seconds, dt)
	dt = dt or 0.1
	local steps = math.ceil(seconds / dt)
	for _ = 1, steps do
		world.step(dt)
	end
end

local function spawnCharacter(player)
	local character = newInstance("Model", { Name = player.Name })
	newInstance("Humanoid", {
		Name = "Humanoid",
		HipHeight = 2,
		Health = 100,
		WalkSpeed = 16,
		MoveDirection = v3(0, 0, 0),
		Parent = character,
	})
	local spawnAt = if player.RespawnLocation then player.RespawnLocation.CFrame.Position else v3(0, 0, 0)
	newInstance("Part", {
		Name = "HumanoidRootPart",
		Size = v3(2, 2, 1),
		Position = spawnAt + v3(0, 4, 0),
		AssemblyLinearVelocity = v3(0, 0, 0),
		Parent = character,
	})
	character.Parent = Workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end
world.spawnCharacter = spawnCharacter

function world.addPlayer(name, userId, isLocal, teleportData)
	local player = newInstance("Player", { Name = name, DisplayName = name, UserId = userId })
	player.JoinTeleportData = teleportData -- Paket 15: what player:GetJoinData().TeleportData returns
	newInstance("PlayerGui", { Name = "PlayerGui", Parent = player })
	newInstance("PlayerScripts", { Name = "PlayerScripts", Parent = player })
	if isLocal then
		world.localPlayer = player
		Players.LocalPlayer = player
	end
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	task.defer(spawnCharacter, player)
	return player
end

function world.removePlayer(player)
	Players.PlayerRemoving:Fire(player)
	player.Parent = nil
end

-- Paket 12: Player:Kick removes the player like leaving; the message stays readable on the player.
function methods.Kick(self, message)
	self.KickMessage = message or ""
	if self.Parent == Players then
		world.removePlayer(self)
	end
end

function world.getRemote(name)
	for _, instance in world.instances do
		if isA(instance.ClassName, "BaseRemoteEvent") and instance.Name == name then
			return instance
		end
	end
	error(`no remote {name}`)
end

-- A client intent sent by any player (the local client uses its controllers instead).
function world.fireServerAs(player, name, ...)
	world.getRemote(name).OnServerEvent:Fire(player, copyArgs(...))
end

-- Finds a GUI object by name path inside the local PlayerGui, e.g. world.gui("Lobby", "Ready").
function world.gui(screenName, objectName)
	local playerGui = world.localPlayer:FindFirstChild("PlayerGui")
	local screen = playerGui:FindFirstChild(screenName)
	if not screen then
		return nil
	end
	if not objectName then
		return screen
	end
	return screen:FindFirstChild(objectName, true)
end

-- Presses the key of a ContextActionService action (e.g. Space for the dash).
function world.pressAction(name)
	local callback = world.actions[name]
	assert(callback, `no action {name}`)
	return callback(name, EnumLib.UserInputState.Begin)
end

-- Paket 16: Roblox calls ProcessReceipt for a purchase; returns a table whose `decision` is filled in when the
-- callback returns (it may wait for a save).
function world.buyProduct(player, productId, purchaseId)
	local outcome = { decision = nil }
	task.spawn(function()
		local callback = MarketplaceService.ProcessReceipt
		assert(callback, "no ProcessReceipt callback")
		outcome.decision = callback({
			PlayerId = player.UserId,
			ProductId = productId,
			PurchaseId = purchaseId,
			CurrencySpent = world.robuxPrices[productId] or 0,
			PlaceIdWherePurchased = game.PlaceId,
		})
	end)
	return outcome
end

function world.click(button)
	assert(button, "button not found")
	button.Activated:Fire()
end

return world
