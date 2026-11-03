-- Runs the existing Luau test prelude with Lune, without requiring a Rust build.
-- Run from the repository root: lune run tools/luau-test-runner/lune-runner.luau
-- Pass spec paths after -- to run a subset.

local fs = require("@lune/fs")
local process = require("@lune/process")

-- Lune's _G is intentionally sparse; inherit its script environment for Luau built-ins.
setmetatable(_G, { __index = getfenv() })

-- The prelude runs specs under pcall. Preload file data so its host callbacks never yield.
local files = {}
local directories = {}
local function visit(path)
	local names = fs.readDir(path)
	table.sort(names)
	directories[path] = names
	for _, name in names do
		local child = path .. "/" .. name
		if fs.isDir(child) then
			visit(child)
		elseif name:match("%.lua[u]?$") then
			files[child] = fs.readFile(child)
		end
	end
end
visit("./src")
visit("./tests")

_G.__root = "."
_G.__readFile = function(path)
	return files[path] or files["./" .. path]
end
_G.__isFile = function(path)
	return files[path] ~= nil or files["./" .. path] ~= nil
end
_G.__isDir = function(path)
	return directories[path] ~= nil or directories["./" .. path] ~= nil
end
_G.__listDir = function(path)
	return directories[path] or directories["./" .. path] or {}
end
_G.__loadChunk = function(source, name, env)
	local chunk, err = loadstring(source, name)
	assert(chunk, err)
	setfenv(chunk, env)
	return chunk
end

local specs = {}
for _, arg in process.args do
	if arg:match("%.spec%.luau$") then
		table.insert(specs, (arg:gsub("\\", "/")))
	end
end
if #specs == 0 then
	for _, name in directories["./tests"] do
		if name:match("%.spec%.luau$") then
			table.insert(specs, "tests/" .. name)
		end
	end
end

local runSpecs = _G.__loadChunk(fs.readFile("tools/luau-test-runner/prelude.luau"), "@prelude.luau", _G)()
if not runSpecs(specs) then
	process.exit(1)
end
