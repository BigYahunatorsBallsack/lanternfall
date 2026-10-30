--!strict
-- Player HP, armor, dodge, hit protection and dash (rules in CombatService/Vitals). Takes enemy contact damage
-- from EnemySim, handles the RequestDash remote, knocks players down at 0 HP via RunDirector and sends
-- PlayerState to every client on change. Fires PlayerDamaged (RunStatsService, EffectService), Dodged and Blocked
-- (EffectService). Sets walk speed and turns jumping off on each character. Dodge rolls come from RandomService.
-- StatService sets the player's stats (setStats: Max HP, HP Regeneration, Armor, Dodge, Speed; Util/StatMath),
-- WeaponService calls lifeSteal, UpgradeService the level-up choice (setChoosing: shielded and standing still);
-- rewards and revives (WP11) use damagePlayer, healPlayer and protect; item effects (EffectService) healPlayer,
-- setHitShields and setHpFraction. When a wave ends
-- (Shop phase) players who are down stand up and everyone heals (Config.Shop.waveEnd); nobody walks or dashes in the
-- shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)
local StatMath = require(Shared.Util.StatMath)

local EnemySim = require(script.Parent.EnemySim)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local Vitals = require(script.Vitals)

local PlayerConfig = Config.Player

local SETTINGS: Vitals.Settings = {
	minDamagePerHit = PlayerConfig.minDamagePerHit,
	hitInvulnerability = PlayerConfig.hitInvulnerability,
	dashCooldown = PlayerConfig.dash.cooldown,
	dashInvulnerability = PlayerConfig.dash.invulnerability,
	dashCooldownTolerance = PlayerConfig.dash.cooldownTolerance,
}

local CombatService = {}

-- (player: Player, taken: number): a participant lost HP (RunStatsService counts it)
CombatService.PlayerDamaged = Signal.new()
-- (player: Player): a participant dodged a hit (Dodge stat)
CombatService.Dodged = Signal.new()
-- (player: Player): a hit shield nullified a hit (item effects)
CombatService.Blocked = Signal.new()

local vitals: { [Player]: Vitals.Vitals } = {}
local sentHp: { [Player]: number } = {} -- whole HP last sent, so regeneration does not send every frame
local stats: { [Player]: StatMath.Sheet } = {} -- the latest from StatService, kept until the player leaves
local regen: { [Player]: number } = {} -- HP per second
local lastLifeSteal: { [Player]: number } = {} -- server time of the last life steal heal
local choosing: { [Player]: boolean } = {} -- picking a level-up card

local function now(): number
	return workspace:GetServerTimeNow()
end

local function maxHpFor(player: Player): number
	local sheet = stats[player]
	return if sheet then StatMath.maxHp(sheet) else PlayerConfig.maxHp
end

local function payload(player: Player, state: Vitals.Vitals): Types.PlayerVitals
	return {
		userId = player.UserId,
		hp = math.ceil(state.hp),
		maxHp = state.maxHp,
		dashReadyAt = state.dashReadyAt,
		invulnerableUntil = state.invulnerableUntil,
		choosing = choosing[player] == true,
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
	local sheet = stats[player]
	local speed = PlayerConfig.moveSpeed * StatMath.speedFactor(if sheet then sheet.speed or 0 else 0)
	local frozen = choosing[player] and Config.Run.levelUp.freezeWhileChoosing
	local shopping = RunDirector.getPhase() == "Shop" -- the shop is a screen of its own, the arena is hidden
	humanoid.WalkSpeed = if standing and not frozen and not shopping then speed else 0
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
	table.clear(choosing)
	table.clear(lastLifeSteal)
	for player, state in vitals do
		state:reset(maxHpFor(player))
		applyWalkSpeed(player)
		send(player)
	end
end

-- Damage to a living participant, e.g. from enemy contact or projectiles. Returns the HP lost, whether the hit
-- was dodged and whether a hit shield (item effect, since B4) took it.
function CombatService.damagePlayer(player: Player, damage: number): (number, boolean, boolean)
	if not canBeHurt(player) then
		return 0, false, false
	end
	local state = getVitals(player)
	local taken, dodged, blocked = state:hit(damage, now(), RandomService.number("Combat", player))
	if dodged then
		CombatService.Dodged:Fire(player)
	elseif blocked then
		CombatService.Blocked:Fire(player)
	end
	if taken > 0 then
		send(player)
		CombatService.PlayerDamaged:Fire(player, taken)
		if state:isDown() then
			RunDirector.setParticipantState(player, "Down")
		end
	end
	return taken, dodged, blocked
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

-- Hits the player shrugs off completely from now on (item effects); replaces the previous count.
function CombatService.setHitShields(player: Player, count: number)
	getVitals(player):setHitShields(count)
end

-- Sets a living participant's HP to `fraction` of their max HP (item effects: "start waves with -50 % HP").
function CombatService.setHpFraction(player: Player, fraction: number)
	local state = getVitals(player)
	if canBeHurt(player) and not state:isDown() then
		state:setFraction(fraction)
		send(player)
	end
end

-- Makes the player invulnerable for `seconds` (e.g. while choosing a level-up card, WP6).
function CombatService.protect(player: Player, seconds: number)
	getVitals(player):protect(now(), seconds)
	send(player)
end

-- The player's stats by id (StatService): Max HP (raising it heals by the difference), HP Regeneration, Armor,
-- Dodge and Speed, with Brotato's formulas (Util/StatMath).
function CombatService.setStats(player: Player, sheet: StatMath.Sheet)
	stats[player] = sheet
	regen[player] = StatMath.regenPerSecond(sheet.hpRegen or 0)
	local state = getVitals(player)
	state:setMaxHp(maxHpFor(player))
	state:setDefense(StatMath.armorFactor(sheet.armor or 0), StatMath.dodgeChance(sheet.dodge or 0))
	applyWalkSpeed(player)
	send(player)
end

-- A weapon hit rolled the player's life steal: heals Config.Stats.hpScale HP, at most once per
-- Config.Stats.lifeSteal.minSecondsBetween. Only for living participants while the run fights.
function CombatService.lifeSteal(player: Player)
	local time = now()
	if
		not canBeHurt(player)
		or time - (lastLifeSteal[player] or -math.huge) < Config.Stats.lifeSteal.minSecondsBetween
	then
		return
	end
	lastLifeSteal[player] = time
	CombatService.healPlayer(player, Config.Stats.hpScale)
end

-- Marks the player as choosing a level-up card (DESIGN.md section 8); weapons keep firing. Only with
-- Config.Run.levelUp.freezeWhileChoosing they stand still and are invulnerable, and ending the choice leaves
-- protectionAfterPick seconds of protection; otherwise they keep walking, dashing and taking hits.
function CombatService.setChoosing(player: Player, value: boolean)
	if (choosing[player] == true) == value then
		return
	end
	choosing[player] = if value then true else nil
	if Config.Run.levelUp.freezeWhileChoosing then
		getVitals(player):setShielded(value, now(), Config.Run.levelUp.protectionAfterPick)
	end
	applyWalkSpeed(player)
	send(player)
end

function CombatService.isChoosing(player: Player): boolean
	return choosing[player] == true
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
		stats[player] = nil
		regen[player] = nil
		lastLifeSteal[player] = nil
		choosing[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	EnemySim.Contact:Connect(CombatService.damagePlayer)
	EnemySim.ShotHit:Connect(CombatService.damagePlayer)

	-- The client moves its own character right away; the server checks the cooldown and grants the
	-- short invulnerability. Rejected dashes send the real cooldown back so the client corrects itself.
	Net.onServer("RequestDash", function(player)
		local participantState = RunDirector.getParticipantState(player)
		local standingStill = RunDirector.isActive() and participantState ~= nil and participantState ~= "Alive"
		local shopping = RunDirector.getPhase() == "Shop"
		if standingStill or shopping or (choosing[player] and Config.Run.levelUp.freezeWhileChoosing) then
			send(player)
			return
		end
		getVitals(player):dash(now())
		send(player)
	end)

	RunDirector.RunStarted:Connect(resetAll)
	RunDirector.PhaseChanged:Connect(function(phase, previous)
		if phase == "Lobby" or phase == "Countdown" then
			resetAll() -- "Play again" goes from the results straight to the countdown
		elseif previous == "Shop" then
			for _, player in RunDirector.getParticipants() do
				applyWalkSpeed(player) -- walking again in the next wave
			end
		elseif phase == "Shop" then
			-- end of a wave (Brotato direction, B1): players who are down stand up, everyone heals
			local waveEnd = Config.Shop.waveEnd
			for _, player in RunDirector.getParticipants() do
				if waveEnd.reviveDown and RunDirector.getParticipantState(player) == "Down" then
					RunDirector.setParticipantState(player, "Alive")
				end
				local state = getVitals(player)
				if not state:isDown() and state.hp < state.maxHp * waveEnd.healFraction then
					state:setFraction(waveEnd.healFraction)
				end
				applyWalkSpeed(player)
				send(player)
			end
		end
	end)
	RunDirector.ParticipantStateChanged:Connect(function(player, participantState)
		local state = getVitals(player)
		if participantState == "Alive" and state:isDown() then
			-- standing up at the end of a wave comes with the wave-end heal
			local shop = RunDirector.getPhase() == "Shop"
			state:setFraction(if shop then Config.Shop.waveEnd.healFraction else Config.Run.coop.reviveHpFraction)
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

	RunService.Heartbeat:Connect(function(dt)
		for player, perSecond in regen do
			local state = vitals[player]
			if state and perSecond > 0 and canBeHurt(player) then
				state:heal(perSecond * dt)
				if math.ceil(state.hp) ~= sentHp[player] then
					send(player)
				end
			end
		end
	end)
end

return CombatService
