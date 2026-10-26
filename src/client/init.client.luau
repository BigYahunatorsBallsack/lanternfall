--!strict
-- Client entry point: waits for the shared modules and remotes, then starts every module in Controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Loader = require(Shared:WaitForChild("Util"):WaitForChild("Loader"))

Net.waitForRemotes()
local controllerCount = Loader.run(script:WaitForChild("Controllers"), "Controller")

print(`[Lanternfall] Client ready: {controllerCount} controllers`)
