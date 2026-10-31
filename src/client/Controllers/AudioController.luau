--!strict
-- Which game event plays which sound effect (Paket 21, DESIGN.md section 14): weapons firing (WeaponEffects, team
-- mates quieter), the own hits and crits (DamageNumbers), loot picked up by the local player (XpOrbs with a rising
-- combo pitch, Pickups, ChestOpened), the local player hurt, downed, dashing and levelling up, and the run flow
-- (wave start and end, boss wave, boss attack warnings). Enemy deaths play from EnemyRenderer/DeathBursts, button
-- clicks from Widgets.button. Sounds come from Audio/Sfx; cues and numbers from Config.Audio. Combat sounds only play
-- while the local player is in a running run (RunStateController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HitNumbers = require(Shared:WaitForChild("Net"):WaitForChild("HitNumbers"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local WeaponFx = require(Shared:WaitForChild("Net"):WaitForChild("WeaponFx"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local PlayerStateController = require(script.Parent.PlayerStateController)
local ProgressController = require(script.Parent.ProgressController)
local RunStateController = require(script.Parent.RunStateController)

local AudioController = {}

local lastPhase: string? = nil
local lastLocalState: string? = nil
local comboSteps = 0
local comboAt = -math.huge
local crates: { [number]: boolean } = {} -- pickup ids that are crates (not fruit), from the drop events

local FRUIT = 1 -- PickupEvents kind

local function inRun(): boolean
	return RunStateController.getView() == "Run"
end

local function localId(): number
	return Players.LocalPlayer.UserId
end

local function floorPoint(x: number?, z: number?): Vector3?
	if x == nil or z == nil then
		return nil
	end
	return Vector3.new(x, Config.Map.arena.center.Y, z)
end

local function onWeaponEffects(packet: any)
	if not inRun() then
		return
	end
	local effects: { Types.WeaponEffect } = WeaponFx.decodeShared(packet) :: any
	local me = localId()
	for _, effect in effects do
		local cueId = Config.Audio.weaponKinds[effect.kind]
		if cueId then
			local scale = if effect.userId == me then 1 else Config.Audio.otherPlayersVolume
			Sfx.play(cueId, floorPoint(effect.x, effect.z), scale)
		end
	end
end

local function onDamageNumbers(packet: any)
	if not (inRun() and typeof(packet) == "buffer") then
		return
	end
	local ok, hits = pcall(HitNumbers.decode, packet)
	if not ok then
		return
	end
	local hit, crit = false, false
	for _, entry in hits do
		if not entry.burn then
			hit = true
			crit = crit or entry.crit
		end
	end
	if crit then
		Sfx.play("crit")
	elseif hit then
		Sfx.play("hit")
	end
end

-- Orbs the local player picks up quickly one after the other climb in pitch.
local function playOrb()
	local combo = Config.Audio.orbCombo
	local at = workspace:GetServerTimeNow()
	if at - comboAt > combo.resetSeconds then
		comboSteps = 0
	end
	comboAt = at
	if Sfx.play("orb", nil, 1, 1 + comboSteps * combo.step) then
		comboSteps = math.min(comboSteps + 1, combo.maxSteps)
	end
end

local function onXpOrbs(events: Types.XpOrbEvents)
	if not inRun() then
		return
	end
	local me = localId()
	local collected = events.collected
	for index = 2, #collected, 2 do
		if collected[index] == me then
			playOrb()
			return -- one per step is enough; the combo carries the rest
		end
	end
end

local function onPickups(events: Types.PickupEvents)
	if events.reset then
		table.clear(crates)
	end
	-- the kind is only in the drop event, so the client remembers which pickups are crates
	local dropped = events.dropped
	for index = 1, #dropped - 3, 4 do
		if dropped[index + 3] ~= FRUIT then
			crates[dropped[index]] = true
		end
	end
	local me = localId()
	local collected = events.collected
	for index = 1, #collected - 1, 2 do
		local id = collected[index]
		if collected[index + 1] == me and inRun() then
			Sfx.play(if crates[id] then "crate" else "fruit")
		end
		crates[id] = nil
	end
end

local function onChestOpened(opened: Types.ChestOpened)
	if not inRun() then
		return
	end
	local me = localId()
	for _, entry in opened.rewards do
		if entry.userId == me then
			Sfx.play("chest")
			return
		end
	end
end

local function onRunState(state: Types.RunState)
	local phase = state.phase
	local info = RunStateController.getLocalPlayer()
	local participant = info ~= nil and info.participant
	if participant and phase ~= lastPhase then
		if phase == "Running" and (lastPhase == "Countdown" or lastPhase == "Shop") then
			Sfx.play("waveStart")
		elseif phase == "Boss" then
			Sfx.play("bossRoar")
		elseif phase == "Shop" and (lastPhase == "Running" or lastPhase == "Boss") then
			Sfx.play("waveEnd")
		end
	end
	lastPhase = phase
	local localState = if participant and info then info.state else nil
	if localState == "Down" and lastLocalState == "Alive" and inRun() then
		Sfx.play("down")
	end
	lastLocalState = localState
end

-- Lifecycle -------------------------------------------------------------------------

function AudioController.init()
	Sfx.group("Effects")
	Net.onClient("WeaponEffects", onWeaponEffects)
	Net.onClient("DamageNumbers", onDamageNumbers)
	Net.onClient("XpOrbs", onXpOrbs)
	Net.onClient("Pickups", onPickups)
	Net.onClient("ChestOpened", onChestOpened)
	Net.onClient("BossTelegraphs", function(list: { Types.BossTelegraph })
		if inRun() and #list > 0 then
			Sfx.play("telegraph", floorPoint(list[1].x, list[1].z))
		end
	end)
	RunStateController.Changed:Connect(onRunState)
	PlayerStateController.Changed:Connect(
		function(userId: number, vitals: Types.PlayerVitals, previous: Types.PlayerVitals?)
			if userId == localId() and previous and vitals.hp < previous.hp and vitals.hp > 0 and inRun() then
				Sfx.play("hurt")
			end
		end
	)
	PlayerStateController.Dashed:Connect(function(userId: number)
		if inRun() then
			local scale = if userId == localId() then 1 else Config.Audio.otherPlayersVolume
			Sfx.play("dash", nil, scale)
		end
	end)
	ProgressController.TeamChanged:Connect(function(progress: Types.TeamProgress, previous: Types.TeamProgress?)
		if previous and progress.level > previous.level and inRun() then
			Sfx.play("levelUp")
		end
	end)
end

return AudioController
