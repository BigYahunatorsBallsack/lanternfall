--!strict
-- Client entry point: starts every module in Controllers once the shared modules are available.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared:WaitForChild("Util"):WaitForChild("Loader"))

local controllerCount = Loader.run(script:WaitForChild("Controllers"), "Controller")

print(`[Lanternfall] Client ready: {controllerCount} controllers`)
