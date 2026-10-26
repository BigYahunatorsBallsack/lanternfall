--!strict
-- Elite chests (DESIGN.md sections 7 and 8): a killed Gloom Elite (EnemySim.EnemyKilled) leaves a chest on the floor.
-- When a living participant gets within Config.Run.coop.chestOpenRadius, it opens and every living participant within
-- chestRadius gets their own reward from UpgradeService.grantChest (evolution, else an upgrade, else healing) and heals
-- Config.Run.coop.chestHealFraction of their max HP (CombatService).
-- Sends Chests (what lies on the floor) and ChestOpened to the participants; chests vanish when a run starts or ends.
-- The boss chest (WP10) can reuse drop().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local RunDirector = require(script.Parent.RunDirector)
local UpgradeService = require(script.Parent.UpgradeService)

local Coop = Config.Run.coop

local LootService = {}

local chests: { Types.ChestInfo } = {}
local nextId = 0

local function list(): { Types.ChestInfo }
	return table.clone(chests)
end

local function sendChests()
	local payload = list()
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("Chests", player, payload)
	end
end

local function clear()
	table.clear(chests)
	sendChests()
end

local function distance(position: Vector3, chest: Types.ChestInfo): number
	local dx, dz = position.X - chest.x, position.Z - chest.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Opens the chest at `index`: every living participant close enough gets a reward.
local function open(index: number)
	local chest = table.remove(chests, index) :: Types.ChestInfo
	local rewards: { { userId: number, reward: Types.ChestReward } } = {}
	for _, player in RunDirector.getParticipants() do
		local position = EnemySim.getPlayerPosition(player) -- nil unless alive
		if position and distance(position, chest) <= Coop.chestRadius then
			local reward = UpgradeService.grantChest(player)
			local _, maxHp = CombatService.getHp(player)
			CombatService.healPlayer(player, maxHp * Coop.chestHealFraction)
			if reward then
				table.insert(rewards, { userId = player.UserId, reward = reward })
			end
		end
	end
	local opened: Types.ChestOpened = { id = chest.id, x = chest.x, z = chest.z, rewards = rewards }
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("ChestOpened", player, opened)
	end
	sendChests()
end

local function onStepped()
	if #chests == 0 then
		return
	end
	for _, player in RunDirector.getParticipants() do
		local position = EnemySim.getPlayerPosition(player)
		if position then
			for index = #chests, 1, -1 do
				if distance(position, chests[index]) <= Coop.chestOpenRadius then
					open(index)
				end
			end
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------

function LootService.init()
	EnemySim.EnemyKilled:Connect(function(info: EnemySim.KillInfo)
		if info.elite and Config.Enemies.elite.dropsChest and RunDirector.isActive() then
			LootService.drop(info.position)
		end
	end)
	EnemySim.Stepped:Connect(onStepped)
	RunDirector.RunStarted:Connect(clear)
	RunDirector.RunEnded:Connect(clear)
	RunDirector.SyncRequested:Connect(function(requester)
		Net.fireClient("Chests", requester, list())
	end)
end

-- Commands --------------------------------------------------------------------------

-- Puts a chest on the floor at `position` (x/z) and returns its id.
function LootService.drop(position: Vector3): number
	nextId += 1
	table.insert(chests, { id = nextId, x = position.X, z = position.Z })
	sendChests()
	return nextId
end

-- Queries ---------------------------------------------------------------------------

-- The chests on the floor right now.
function LootService.getChests(): { Types.ChestInfo }
	return list()
end

return LootService
