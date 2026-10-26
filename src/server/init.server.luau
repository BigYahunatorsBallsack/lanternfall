--!strict
-- Server entry point: creates remotes, checks Config and starts every module in Services (see Util/Loader).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Loader = require(ReplicatedStorage.Shared.Util.Loader)
local ConfigCheck = require(script.ConfigCheck)

local remoteCount = Net.initServer()

local problems = ConfigCheck.run()
for _, message in problems do
	warn(`[Lanternfall] Config problem: {message}`)
end

local serviceCount = Loader.run(script:WaitForChild("Services"), "Service")

print(`[Lanternfall] Server ready: {remoteCount} remotes, {serviceCount} services, config problems: {#problems}`)
