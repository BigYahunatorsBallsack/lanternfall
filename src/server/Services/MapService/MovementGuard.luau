--!strict
-- Movement plausibility check (Paket 23, DESIGN.md section 16; rules in MapService/MovementRules, values in
-- Config.Security.movement). Roblox lets each client move its own character, so a cheat can make it run faster,
-- teleport, or walk through the arena walls and the ruin pillars (where no enemy reaches it). Once MapService placed a
-- character in the arena (watch), every position MapService reads goes through check(): a move the character could
-- not have made is undone (the character goes back to the last accepted spot) and the services keep that spot, so
-- enemies, pickups, revives and weapons never see the cheated one. Corrections are logged and fire Corrected
-- (AnalyticsService counts them). CombatService reports the walk speed it sets and the dashes it grants. Also caps the
-- velocity the services read (enemy aim, standing-still items). Off in Studio unless Config says otherwise or the
-- debug button turns it on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local MovementRules = require(script.Parent.MovementRules)

local Settings = Config.Security.movement
local DASH_SPEED = Config.Player.dash.distance / Config.Player.dash.duration
local SETTLE_SECONDS = 1 -- after the server placed a character, its own client may still report the old spot
local LOG_PREFIX = "[Lanternfall] "

type Watch = {
	root: BasePart,
	entry: MovementRules.Entry,
	settleUntil: number,
	lastStrikeAt: number,
	strikes: number,
}

local MovementGuard = {}

-- (player: Player, reason: "Speed" | "Outside" | "Pillar", distance: number): a move was undone (at most once per
-- Config.Security.movement.strikeGapSeconds and player)
MovementGuard.Corrected = Signal.new()

local enabled = Settings.enabled and (Settings.studio or not RunService:IsStudio())
local watches: { [Player]: Watch } = {}
local speeds: { [Player]: number } = {} -- latest walk speed from CombatService, kept across characters
local area: MovementRules.Area = (function()
	local arena = Config.Map.arena
	local half = arena.size / 2
	local pillars = {}
	for _, obstacle in arena.obstacles do
		table.insert(
			pillars,
			{ x = arena.center.X + obstacle.x, z = arena.center.Z + obstacle.z, radius = obstacle.radius }
		)
	end
	return {
		minX = arena.center.X - half,
		maxX = arena.center.X + half,
		minZ = arena.center.Z - half,
		maxZ = arena.center.Z + half,
		pillars = pillars,
	}
end)()

local function now(): number
	return os.clock()
end

local function speedOf(player: Player): number
	return speeds[player] or Config.Player.moveSpeed
end

local function rebase(watch: Watch, position: Vector3, t: number)
	MovementRules.rebase(watch.entry, position.X, position.Y, position.Z, t, Settings)
end

-- Puts the character back on the last accepted spot, facing where it faced.
local function correct(player: Player, watch: Watch, reason: string, distance: number, t: number)
	local entry = watch.entry
	local root = watch.root
	local target = Vector3.new(entry.x, entry.y, entry.z)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local cframe = if flat.Magnitude > 0.01 then CFrame.lookAt(target, target + flat) else CFrame.new(target)
	root.AssemblyLinearVelocity = Vector3.zero
	local character = root.Parent
	if character and character:IsA("Model") then
		character:PivotTo(cframe)
	else
		root.CFrame = cframe
	end
	if t - watch.lastStrikeAt >= Settings.strikeGapSeconds then
		watch.strikes += 1
		local shown = if distance == math.huge then "an invalid spot" else `{math.floor(distance + 0.5)} studs`
		warn(
			`{LOG_PREFIX}Movement check: {player.Name} moved back ({reason}, {shown}; correction {watch.strikes} since placed)`
		)
		MovementGuard.Corrected:Fire(player, reason, distance)
	end
	watch.lastStrikeAt = t
end

-- The server placed the player's character in the arena at its current spot: check it from now on.
function MovementGuard.watch(player: Player, root: BasePart)
	local t = now()
	local position = root.Position
	watches[player] = {
		root = root,
		entry = MovementRules.new(position.X, position.Y, position.Z, speedOf(player), t, Settings),
		settleUntil = t + SETTLE_SECONDS,
		lastStrikeAt = -math.huge,
		strikes = 0,
	}
end

-- The character left the arena (lobby) or is gone: no more checks.
function MovementGuard.unwatch(player: Player)
	watches[player] = nil
end

-- CombatService: the walk speed it just gave the character (0 while it may not walk).
function MovementGuard.setSpeed(player: Player, speed: number)
	speeds[player] = speed
	local watch = watches[player]
	if watch then
		MovementRules.setSpeed(watch.entry, speed, now(), Settings)
	end
end

-- CombatService: the server granted a dash.
function MovementGuard.dashed(player: Player)
	local watch = watches[player]
	if watch then
		MovementRules.addDash(watch.entry, Config.Player.dash.distance, now(), Settings)
	end
end

-- The position MapService hands to the services for `root` (the player's HumanoidRootPart): its real position if the
-- move is believable, else the last accepted one after putting the character back there.
function MovementGuard.check(player: Player, root: BasePart): Vector3
	local position = root.Position
	local watch = watches[player]
	if not watch then
		return position
	elseif watch.root ~= root then
		watches[player] = nil -- a new character the server has not placed yet
		return position
	elseif not enabled then
		return position
	end
	local entry = watch.entry
	if position.X == entry.x and position.Y == entry.y and position.Z == entry.z then
		return position
	end
	local t = now()
	local block = MovementRules.blocked(area, position.X, position.Z, Settings)
	if t < watch.settleUntil then
		if block then
			return Vector3.new(entry.x, entry.y, entry.z) -- the client may still report the spot before the placement
		end
		rebase(watch, position, t)
		return position
	end
	local reason: string? = block
	local distance = 0
	if reason then
		local dx, dz = position.X - entry.x, position.Z - entry.z
		distance = math.sqrt(dx * dx + dz * dz)
	else
		local ok, moved = MovementRules.tryMove(entry, position.X, position.Y, position.Z, t, Settings)
		if ok then
			return position
		end
		reason, distance = "Speed", moved
	end
	correct(player, watch, reason :: string, distance, t)
	return Vector3.new(entry.x, entry.y, entry.z)
end

-- `velocity` of the player's character, shortened to the fastest believable speed over the floor (the height part
-- stays). Unchanged for characters that are not checked.
function MovementGuard.clampVelocity(player: Player, velocity: Vector3): Vector3
	local watch = watches[player]
	if not (enabled and watch) then
		return velocity
	end
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local limit = MovementRules.maxSpeed(watch.entry, DASH_SPEED, now(), Settings)
	local speed = flat.Magnitude
	if speed <= limit or speed == 0 then
		return velocity
	end
	if speed ~= speed then
		return Vector3.zero
	end
	local scaled = flat * (limit / speed)
	return Vector3.new(scaled.X, velocity.Y, scaled.Z)
end

-- Turns the check on or off for this server (debug button, tests). Turning it on accepts where everyone stands now.
function MovementGuard.setEnabled(on: boolean)
	if on and not enabled then
		local t = now()
		for _, watch in watches do
			rebase(watch, watch.root.Position, t)
			watch.settleUntil = t
		end
	end
	enabled = on
end

function MovementGuard.isEnabled(): boolean
	return enabled
end

-- How often the player was moved back since the server last placed their character (tests, debug).
function MovementGuard.getStrikes(player: Player): number
	local watch = watches[player]
	return if watch then watch.strikes else 0
end

-- Checks every watched character each frame, so a cheat is undone even while no service reads the position.
function MovementGuard.init()
	Players.PlayerRemoving:Connect(function(player)
		watches[player] = nil
		speeds[player] = nil
	end)
	RunService.Heartbeat:Connect(function()
		if not enabled then
			return
		end
		for player, watch in watches do
			local character = player.Character
			if watch.root.Parent ~= character or character == nil then
				watches[player] = nil
			else
				MovementGuard.check(player, watch.root)
			end
		end
	end)
end

return MovementGuard
