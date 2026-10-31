--!strict
-- Launch check (Paket 24): runs Util/LaunchRules for this server's experience and place once at start. Studio prints
-- one summary line, a live server warns about open "must" items (Developer Console). AdminService's debug command
-- "LaunchCheck" prints the full list through LaunchService.report().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local LaunchRules = require(Shared.Util.LaunchRules)

local ConfigCheck = require(script.Parent.Parent.ConfigCheck)

local LOG_PREFIX = "[Lanternfall] "

local LaunchService = {}

local configProblems: number? = nil -- counted once; the config does not change while a server runs

local function items(): { LaunchRules.Item }
	if configProblems == nil then
		configProblems = #ConfigCheck.run()
	end
	return LaunchRules.check({
		gameId = game.GameId,
		placeId = game.PlaceId,
		configProblems = configProblems :: number,
	})
end

-- The current check (for tests and the debug command).
function LaunchService.check(): { LaunchRules.Item }
	return items()
end

-- Prints every item to the Output; returns the summary line.
function LaunchService.report(): string
	local list = items()
	print(`{LOG_PREFIX}===== Launch check (experience {game.GameId}, place {game.PlaceId}) =====`)
	for _, line in LaunchRules.lines(list) do
		print(LOG_PREFIX .. line)
	end
	return LaunchRules.summary(list)
end

function LaunchService.start()
	local settings = Config.Launch.check
	local studio = RunService:IsStudio()
	if studio and not settings.printInStudio then
		return
	end
	if not studio and not settings.warnLive then
		return
	end
	task.defer(function()
		local list = items()
		if studio then
			print(LOG_PREFIX .. LaunchRules.summary(list))
			return
		end
		for _, item in list do
			if not item.ok and item.level == "must" then
				warn(`{LOG_PREFIX}Launch check: {item.text}`)
			end
		end
	end)
end

return LaunchService
