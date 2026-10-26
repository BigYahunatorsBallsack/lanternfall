-- Fake Roblox environment for unit tests of pure modules. Loaded by main.rs.
-- Maps the Rojo tree (default.project.json) onto files: a folder with init.luau is a ModuleScript
-- with children, X.luau is a ModuleScript X. `require(instance)` loads and caches the file.
-- Specs get `describe`, `it` and `expect`, plus `fakeTime()` and the globals below.

local root = __root

local function join(a, b)
	return a .. "/" .. b
end

-- Instance proxies ---------------------------------------------------------

local proxyMeta = {}
local function makeProxy(name, dir, file, parent, children)
	return setmetatable(
		{ __name = name, __dir = dir, __file = file, __parent = parent, __children = children },
		proxyMeta
	)
end

local function findChild(proxy, name)
	local fixed = rawget(proxy, "__children")
	if fixed then
		return fixed[name]
	end
	local dir = rawget(proxy, "__dir")
	if not dir then
		return nil
	end
	local candidates = { join(dir, name .. ".luau"), join(dir, name .. ".lua") }
	for _, file in candidates do
		if __isFile(file) then
			return makeProxy(name, nil, file, proxy, nil)
		end
	end
	local childDir = join(dir, name)
	if __isDir(childDir) then
		local init = nil
		for _, initName in { "init.luau", "init.lua" } do
			if __isFile(join(childDir, initName)) then
				init = join(childDir, initName)
			end
		end
		return makeProxy(name, childDir, init, proxy, nil)
	end
	return nil
end

proxyMeta.__index = function(proxy, key)
	if key == "Parent" then
		return rawget(proxy, "__parent")
	elseif key == "Name" then
		return rawget(proxy, "__name")
	elseif key == "WaitForChild" or key == "FindFirstChild" then
		return function(self, name)
			local child = findChild(self, name)
			if not child and key == "WaitForChild" then
				error(`fake WaitForChild: {name} not found in {rawget(self, "__name")}`, 2)
			end
			return child
		end
	elseif key == "IsA" then
		return function(self, className)
			return className == "ModuleScript" and rawget(self, "__file") ~= nil
		end
	elseif key == "ClassName" then
		return if rawget(proxy, "__file") then "ModuleScript" else "Folder"
	elseif key == "GetChildren" then
		return function(self)
			local children = {}
			local fixed = rawget(self, "__children")
			if fixed then
				for _, child in fixed do
					table.insert(children, child)
				end
				return children
			end
			local dir = rawget(self, "__dir")
			if not dir then
				return children
			end
			for _, entry in __listDir(dir) do
				local name = string.match(entry, "^(.-)%.luau$") or string.match(entry, "^(.-)%.lua$")
				if name and string.find(name, "%.") then
					name = nil -- Script files like init.server.luau are not ModuleScripts
				end
				if name == "init" then
					name = nil
				end
				if not name and __isDir(join(dir, entry)) then
					name = entry
				end
				if name then
					local child = findChild(self, name)
					if child then
						table.insert(children, child)
					end
				end
			end
			return children
		end
	end
	local child = findChild(proxy, key)
	if child == nil then
		error(`fake instance: {key} is not a valid member of {rawget(proxy, "__name")}`, 2)
	end
	return child
end
proxyMeta.__tostring = function(proxy)
	return rawget(proxy, "__name")
end

-- Services ------------------------------------------------------------------

local services = {}
services.ReplicatedStorage = makeProxy("ReplicatedStorage", nil, nil, nil, {
	Shared = makeProxy("Shared", join(root, "src/shared"), nil, nil, nil),
})
services.ServerScriptService = makeProxy("ServerScriptService", nil, nil, nil, {
	Server = makeProxy("Server", join(root, "src/server"), nil, nil, nil),
})

local game = {}
_G.__services = services
function game:GetService(name)
	local service = services[name]
	if not service then
		error(`fake game: service {name} is not available in tests`, 2)
	end
	return service
end

-- require -------------------------------------------------------------------

local cache = {}
local loading = {}
local fakeRequire

local function moduleEnv(scriptProxy)
	return setmetatable({ script = scriptProxy, require = fakeRequire, game = game }, { __index = _G })
end

function fakeRequire(proxy)
	local file = type(proxy) == "table" and rawget(proxy, "__file")
	if not file then
		error(`fake require: {proxy} is not a ModuleScript`, 2)
	end
	if cache[file] ~= nil then
		return cache[file]
	end
	if loading[file] then
		error(`fake require: cyclic require of {file}`, 2)
	end
	loading[file] = true
	local source = __readFile(file)
	local chunk = __loadChunk(source, "@" .. file, moduleEnv(proxy))
	local result = chunk()
	loading[file] = nil
	cache[file] = result
	return result
end

-- Roblox globals used by pure modules -----------------------------------------

local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
_G.Vector3 = Vector3
_G.warn = function(...)
	print("WARN", ...)
end

-- Test API --------------------------------------------------------------------

local results = { passed = 0, failed = 0 }
local prefix = {}

local function describe(name, body)
	table.insert(prefix, name)
	body()
	table.remove(prefix)
end

local function it(name, body)
	local fullName = table.concat(prefix, " > ") .. " > " .. name
	local ok, err = pcall(body)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		print(`FAIL {fullName}\n     {err}`)
	end
end

local function show(value)
	if type(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

local function expect(actual)
	local matchers = {}
	function matchers.toBe(expected)
		if actual ~= expected then
			error(`expected {show(expected)}, got {show(actual)}`, 2)
		end
	end
	function matchers.toBeNear(expected, tolerance)
		if type(actual) ~= "number" or math.abs(actual - expected) > (tolerance or 1e-6) then
			error(`expected about {show(expected)}, got {show(actual)}`, 2)
		end
	end
	function matchers.toBeTruthy()
		if not actual then
			error(`expected a truthy value, got {show(actual)}`, 2)
		end
	end
	function matchers.toBeFalsy()
		if actual then
			error(`expected a falsy value, got {show(actual)}`, 2)
		end
	end
	return matchers
end

-- Controllable clock for modules that take `now` as an argument.
local function fakeTime(start)
	local clock = { now = start or 1000 }
	function clock.advance(seconds)
		clock.now += seconds
		return clock.now
	end
	return clock
end

-- Loads a Script file (e.g. src/server/init.server.luau) as if it ran with `script` = scriptProxy.
local function runScript(scriptProxy, fileName)
	local file = join(rawget(scriptProxy, "__dir"), fileName)
	local chunk = __loadChunk(__readFile(file), "@" .. file, moduleEnv(scriptProxy))
	return chunk()
end

-- Proxy for a Rojo folder that is not under a fake service, e.g. src/client as StarterPlayerScripts.Client.
local function folderProxy(relativeDir, name)
	return makeProxy(name, join(root, relativeDir), nil, nil, nil)
end

local function snapshotGlobals()
	local copy = {}
	for key, value in _G do
		copy[key] = value
	end
	return copy
end

local function restoreGlobals(copy)
	for key in _G do
		if copy[key] == nil then
			_G[key] = nil
		end
	end
	for key, value in copy do
		_G[key] = value
	end
end

local baseServices = {}
for name, service in services do
	baseServices[name] = service
end

return function(specs)
	local globals = snapshotGlobals()
	for _, spec in specs do
		-- every spec file starts with a fresh module cache, globals and services
		table.clear(cache)
		restoreGlobals(globals)
		table.clear(services)
		for name, service in baseServices do
			services[name] = service
		end
		for key in game do
			if key ~= "GetService" then
				game[key] = nil
			end
		end
		local source = __readFile(spec)
		if not source then
			print(`FAIL cannot read {spec}`)
			results.failed += 1
			continue
		end
		local env
		env = setmetatable({
			game = game,
			require = fakeRequire,
			describe = describe,
			it = it,
			expect = expect,
			fakeTime = fakeTime,
			runScript = runScript,
			folderProxy = folderProxy,
			-- runs a helper file from the repo with the spec's environment and returns its result
			loadHelper = function(relativePath)
				local file = join(root, relativePath)
				return __loadChunk(__readFile(file), "@" .. file, env)()
			end,
		}, { __index = _G })
		local ok, err = pcall(function()
			__loadChunk(source, "@" .. spec, env)()
		end)
		if not ok then
			print(`FAIL {spec} crashed: {err}`)
			results.failed += 1
		end
	end
	print(`{results.passed} passed, {results.failed} failed`)
	return results.failed == 0
end
