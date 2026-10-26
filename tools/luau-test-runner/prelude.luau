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
	return setmetatable({ __name = name, __dir = dir, __file = file, __parent = parent, __children = children }, proxyMeta)
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

return function(specs)
	for _, spec in specs do
		local source = __readFile(spec)
		if not source then
			print(`FAIL cannot read {spec}`)
			results.failed += 1
			continue
		end
		local env = setmetatable({
			game = game,
			require = fakeRequire,
			describe = describe,
			it = it,
			expect = expect,
			fakeTime = fakeTime,
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
