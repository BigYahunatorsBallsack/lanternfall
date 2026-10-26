--!strict
-- Loads every ModuleScript in a folder and runs the init/start lifecycle. Used by the server bootstrap
-- (Services) and the client bootstrap (Controllers).
--
-- Contract for a service or controller module: it returns a table with optional init() and start().
--   * Top level: create state and Signals only; no yielding, no Roblox event connections.
--   * init(): connect remotes and events. Runs for every module (sorted by name) before any start().
--     Must not yield.
--   * start(): may yield (loops, waits). Each start() runs in its own thread.
-- Modules require each other directly. A module that fails is reported in red and the others keep running.

local Loader = {}

function Loader.run(folder: Instance, label: string): number
	local children: { ModuleScript } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(children, child)
		end
	end
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)

	local loaded: { { name: string, module: any } } = {}
	for _, child in children do
		local ok, result = pcall(require, child)
		if ok and typeof(result) == "table" then
			table.insert(loaded, { name = child.Name, module = result })
		else
			task.spawn(error, `[Lanternfall] {label} {child.Name} failed to load: {result}`, 0)
		end
	end

	-- task.spawn runs init() right away and shows errors with a stack trace without stopping the loop.
	for _, entry in loaded do
		if entry.module.init then
			local thread = task.spawn(entry.module.init)
			if coroutine.status(thread) ~= "dead" then
				warn(`[Lanternfall] {label} {entry.name}.init() yielded; move waiting code to start()`)
			end
		end
	end
	for _, entry in loaded do
		if entry.module.start then
			task.spawn(entry.module.start)
		end
	end

	return #loaded
end

return Loader
