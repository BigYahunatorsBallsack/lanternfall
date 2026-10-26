--!strict
-- Player HP, armor, hit protection and dash (rules in CombatService/Vitals). Takes enemy contact damage
-- from EnemySim, handles the RequestDash remote, knocks players down at 0 HP via RunDirector and sends
-- PlayerState to every client on change. Sets walk speed and turns jumping off on each character.
-- Weapons (WP5), level-ups (WP6) and revives (WP11) use damagePlayer, healPlayer and protect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local EnemySim = require(script.Parent.EnemySim)
local RunDirector = require(script.Parent.RunDirector)
local Vitals = require(script.Vitals)

local PlayerConfig = Config.Player

local SETTINGS: Vitals.Settings = {
	armor = PlayerConfig.armor,
	minDamagePerHit = PlayerConfig.minDamagePerHit,
	hitInvulnerability = PlayerConfig.hitInvulnerability,
	dashCooldown = PlayerConfig.dash.cooldown,
	dashInvulnerability = PlayerConfig.dash.invulnerability,
	dashCooldownTolerance = PlayerConfig.dash.cooldownTolerance,
}

local CombatService = {}

local vitals: { [Player]: Vitals.Vitals } = {}
local sentHp: { [Player]: number } = {} -- whole HP last sent, so regeneration does not send every frame

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Base max HP plus the class bonus of the player's run class (DESIGN.md section 5).
local function maxHpFor(player: Player): number
	local maxHp = PlayerConfig.maxHp
	local classId = RunDirector.getParticipantClassId(player)
	local class = classId and Config.Classes[classId]
	if class and class.bonus.stat == "maxHp" then
		maxHp *= 1 + class.bonus.value
	end
	return math.round(maxHp)
end

local function payload(player: Player, state: Vitals.Vitals): Types.PlayerVitals
	return {
		userId = player.UserId,
		hp = math.ceil(state.hp),
		maxHp = state.maxHp,
		dashReadyAt = state.dashReadyAt,
		invulnerableUntil = state.invulnerableUntil,
	}
end

local function send(player: Player)
	local state = vitals[player]
	if state then
		sentHp[player] = math.ceil(state.hp)
		Net.fireAllClients("PlayerState", payload(player, state))
	end
end

local function getVitals(player: Player): Vitals.Vitals
	local state = vitals[player]
	if not state then
		state = Vitals.new(maxHpFor(player), SETTINGS)
		vitals[player] = state
	end
	return state
end

local function canBeHurt(player: Player): boolean
	return RunDirector.isActive() and RunDirector.getParticipantState(player) == "Alive"
end

local function applyWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local participantState = RunDirector.getParticipantState(player)
	local standing = participantState == nil or participantState == "Alive" or not RunDirector.isActive()
	humanoid.WalkSpeed = if standing then PlayerConfig.moveSpeed else 0
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not (humanoid and humanoid:IsA("Humanoid")) then
		return
	end
	-- Space and gamepad A dash instead of jumping (DESIGN.md section 4); no jump button on phones.
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	applyWalkSpeed(player)
end

local function onPlayerAdded(player: Player)
	getVitals(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	send(player)
end

local function resetAll()
	for player, state in vitals do
		state:reset(maxHpFor(player))
		applyWalkSpeed(player)
		send(player)
	end
end

-- Damage to a living participant, e.g. from enemy contact or projectiles. Returns the HP lost.
function CombatService.damagePlayer(player: Player, damage: number): number
	if not canBeHurt(player) then
		return 0
	end
	local state = getVitals(player)
	local taken = state:hit(damage, now())
	if taken > 0 then
		send(player)
		if state:isDown() then
			RunDirector.setParticipantState(player, "Down")
		end
	end
	return taken
end

-- Heals a living player. Returns the HP gained.
function CombatService.healPlayer(player: Player, amount: number): number
	local state = getVitals(player)
	local gained = state:heal(amount)
	if gained > 0 then
		send(player)
	end
	return gained
end

-- Makes the player invulnerable for `seconds` (e.g. while choosing a level-up card, WP6).
function CombatService.protect(player: Player, seconds: number)
	getVitals(player):protect(now(), seconds)
	send(player)
end

function CombatService.getHp(player: Player): (number, number)
	local state = getVitals(player)
	return state.hp, state.maxHp
end

function CombatService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		vitals[player] = nil
		sentHp[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	EnemySim.Contact:Connect(CombatService.damagePlayer)

	-- The client moves its own character right away; the server checks the cooldown and grants the
	-- short invulnerability. Rejected dashes send the real cooldown back so the client corrects itself.
	Net.onServer("RequestDash", function(player)
		local participantState = RunDirector.getParticipantState(player)
		if RunDirector.isActive() and participantState ~= nil and participantState ~= "Alive" then
			send(player)
			return
		end
		getVitals(player):dash(now())
		send(player)
	end)

	RunDirector.RunStarted:Connect(resetAll)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Lobby" or phase == "Countdown" then
			resetAll() -- "Play again" goes from the results straight to the countdown
		end
	end)
	RunDirector.ParticipantStateChanged:Connect(function(player, participantState)
		local state = getVitals(player)
		if participantState == "Alive" and state:isDown() then
			state:setFraction(Config.Run.coop.reviveHpFraction)
		elseif participantState ~= "Alive" then
			state:knockDown()
		end
		applyWalkSpeed(player)
		send(player)
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		for player, state in vitals do
			Net.fireClient("PlayerState", requester, payload(player, state))
		end
	end)

	if PlayerConfig.regenPerSecond > 0 then
		RunService.Heartbeat:Connect(function(dt)
			for player, state in vitals do
				if canBeHurt(player) then
					state:heal(PlayerConfig.regenPerSecond * dt)
					if math.ceil(state.hp) ~= sentHp[player] then
						send(player)
					end
				end
			end
		end)
	end
end

return CombatService
