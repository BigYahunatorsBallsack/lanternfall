--!strict
-- Server entry point: creates remotes, checks Config and starts every module in Services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ConfigCheck = require(script.ConfigCheck)

local remoteCount = Net.initServer()

local problems = ConfigCheck.run()
for _, message in problems do
	warn(`[Lanternfall] Config problem: {message}`)
end

-- Services are ModuleScripts returning a table with optional init() and start().
-- init() runs for all services first, then start(), so services may reference each other in start().
local services = {}
local servicesFolder = script:FindFirstChild("Services")
if servicesFolder then
	for _, child in servicesFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			services[child.Name] = (require :: any)(child)
		end
	end
end
for _, service in services do
	if service.init then
		service.init()
	end
end
for _, service in services do
	if service.start then
		task.spawn(service.start)
	end
end

print(`[Lanternfall] Server ready: {remoteCount} remotes, config problems: {#problems}`)
