--!strict
-- Client entry point: starts every module in Controllers once the shared modules are available.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

-- Controllers are ModuleScripts returning a table with optional init() and start().
local controllers = {}
local controllersFolder = script:FindFirstChild("Controllers")
if controllersFolder then
	for _, child in controllersFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			controllers[child.Name] = (require :: any)(child)
		end
	end
end
for _, controller in controllers do
	if controller.init then
		controller.init()
	end
end
for _, controller in controllers do
	if controller.start then
		task.spawn(controller.start)
	end
end

local weaponCount = 0
for _ in Config.Weapons do
	weaponCount += 1
end
print(`[Lanternfall] Client ready: config loaded ({weaponCount} weapons)`)
