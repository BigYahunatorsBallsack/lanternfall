--!strict
-- Roblox badges (Paket 18, DESIGN.md section 11): when a player's saved data loads or changes, every badge of
-- Config.Badges whose condition is met and that is set up in this experience (id not 0) is awarded once and remembered
-- in the profile (ProfileTemplate.Data.badges). Studio can not award badges, there it only prints what it would award.
-- Hooks into PlayerDataService (Loaded, Changed). Named BadgeService like Roblox's service, which it reaches through
-- game:GetService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local BadgesConfig = require(Shared.Config.Badges)

local PlayerDataService = require(script.Parent.PlayerDataService)

local LOG_PREFIX = "[Lanternfall] "

local BadgeService = {}

local awardInStudio = false
local customIds: { [string]: number }? = nil
local pending: { [Player]: { [string]: boolean } } = {}
local told: { [string]: boolean } = {} -- Studio or "not set up" lines already printed

local function idsOfExperience(): { [string]: number }
	if customIds then
		return customIds
	end
	local fallback: BadgesConfig.Ids? = nil
	for _, experience in Config.Badges.experiences do
		if game.GameId ~= 0 and experience.gameId == game.GameId then
			return experience.ids
		elseif experience.gameId == 0 then
			fallback = fallback or experience
		end
	end
	return if fallback then fallback.ids else {}
end

local function tellOnce(key: string, text: string)
	if not told[key] then
		told[key] = true
		print(LOG_PREFIX .. text)
	end
end

-- Whether the player's saved data meets the badge's condition.
function BadgeService.earned(badge: BadgesConfig.Badge, data: any): boolean
	if badge.join then
		return true
	end
	local value = data.stats[badge.stat or ""]
	return type(value) == "number" and value >= (badge.goal or 1)
end

local function award(player: Player, badge: BadgesConfig.Badge, id: number): boolean
	local roblox = game:GetService("BadgeService") :: any
	for attempt = 1, Config.Badges.attempts do
		local ok, result = pcall(function()
			if roblox:UserHasBadgeAsync(player.UserId, id) then
				return true
			end
			return roblox:AwardBadge(player.UserId, id)
		end)
		if ok then
			return result == true
		elseif attempt == Config.Badges.attempts then
			warn(`{LOG_PREFIX}Badge {badge.name} not awarded to {player.Name}: {result}`)
		else
			task.wait(attempt)
		end
	end
	return false
end

local function check(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local ids = idsOfExperience()
	local busy = pending[player] or {}
	pending[player] = busy
	for _, badge in Config.Badges.badges do
		if data.badges[badge.key] or busy[badge.key] or not BadgeService.earned(badge, data) then
			continue
		end
		local id = ids[badge.key] or 0
		if id == 0 then
			tellOnce(`unset:{badge.key}`, `Badge "{badge.name}" earned but not set up (Config/Badges.luau id is 0)`)
			continue
		elseif RunService:IsStudio() and not awardInStudio then
			tellOnce(`studio:{player.UserId}:{badge.key}`, `Badge "{badge.name}" earned (Studio does not award badges)`)
			continue
		end
		busy[badge.key] = true
		task.spawn(function()
			local ok = award(player, badge, id)
			busy[badge.key] = nil
			local current = PlayerDataService.get(player)
			if ok and current then
				current.badges[badge.key] = true
				print(`{LOG_PREFIX}{player.Name} got the badge "{badge.name}"`)
			end
		end)
	end
end

function BadgeService.init()
	PlayerDataService.Loaded:Connect(check)
	PlayerDataService.Changed:Connect(check)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

-- Tests: these badge ids instead of Config.Badges.
function BadgeService.useIds(ids: { [string]: number })
	customIds = ids
end

-- Tests: award in Studio too (the mock's BadgeService records awards).
function BadgeService.allowStudio(allow: boolean)
	awardInStudio = allow
end

return BadgeService
