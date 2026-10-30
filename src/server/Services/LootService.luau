--!strict
-- Chests, fruits and crates on the arena floor (DESIGN.md sections 3, 7 and 8).
-- Elite chests: a killed Gloom Elite (EnemySim.EnemyKilled) leaves a chest on the floor. When a living participant
-- gets within Config.Run.coop.chestOpenRadius, it opens and every living participant within chestRadius gets their
-- own reward from UpgradeService.grantChest (evolution, else an item, else healing) and heals
-- Config.Run.coop.chestHealFraction of their max HP (CombatService). Chests still on the floor when a wave ends open
-- for every participant who is not out. Sends Chests (what lies on the floor) and ChestOpened to the participants.
-- Fruits and crates (since B6, Brotato's consumables; Config.Loot, Util/LootRules): killed enemies drop one by chance
-- (Luck raises it, crates get rarer with every crate of the wave); a living participant picks it up within their orb
-- pickup radius. A fruit heals, a crate heals and holds an item that UpgradeService offers at the end of the wave
-- (take or sell). Fruits left at the wave end vanish (everyone heals then anyway), crates left go to the nearest
-- participant who is not out. Sends Pickups to the participants.
-- Everything vanishes when a run starts or ends. Fires ChestCollected per player for chests and crates and
-- ConsumableCollected for fruits and crates (item effects, EffectService). Since WP10 a killed boss drops a legendary
-- crate (Config.Loot.legendaryCrate): it heals fully and its item is at least Legendary; it opens like a crate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local LootRules = require(Shared.Util.LootRules)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local StatService = require(script.Parent.StatService)
local UpgradeService = require(script.Parent.UpgradeService)

local KIND_NAMES = { "Fruit", "Crate", "Legendary" }

local Coop = Config.Run.coop
local Loot = Config.Loot

local FRUIT, CRATE, LEGENDARY = 1, 2, 3 -- kinds in Net/Types.PickupEvents

local LootService = {}

-- (player: Player): the player got the reward of a chest or picked up a crate (Brotato's crate pickup)
LootService.ChestCollected = Signal.new()
-- (player: Player, kind: string, wasFull: boolean): the player picked up a fruit or a crate ("Fruit", "Crate"; B6),
-- wasFull: at max HP before its healing (B8)
LootService.ConsumableCollected = Signal.new()

type Pickup = { id: number, x: number, z: number, kind: number }

local chests: { Types.ChestInfo } = {}
local nextId = 0
local pickups: { Pickup } = {}
local nextPickupId = 0
local fruitsOnFloor = 0
local cratesThisWave = 0
local dropsPaused = false
-- Changes since the last flush, in the flat Net/Types.PickupEvents layout.
local droppedPickups: { number } = {}
local collectedPickups: { number } = {}

local function list(): { Types.ChestInfo }
	return table.clone(chests)
end

local function sendChests()
	local payload = list()
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("Chests", player, payload)
	end
end

local function flattenPickups(): { number }
	local flat = table.create(#pickups * 4)
	for _, pickup in pickups do
		table.insert(flat, pickup.id)
		table.insert(flat, pickup.x)
		table.insert(flat, pickup.z)
		table.insert(flat, pickup.kind)
	end
	return flat
end

local function flushPickups()
	if #droppedPickups == 0 and #collectedPickups == 0 then
		return
	end
	local events: Types.PickupEvents = { dropped = droppedPickups, collected = collectedPickups }
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("Pickups", player, events)
	end
	droppedPickups = {}
	collectedPickups = {}
end

local function clearPickups()
	table.clear(pickups)
	fruitsOnFloor = 0
	droppedPickups = {}
	collectedPickups = {}
	Net.fireAllClients("Pickups", { reset = true, dropped = {}, collected = {} } :: Types.PickupEvents)
end

local function clear()
	table.clear(chests)
	sendChests()
	clearPickups()
	cratesThisWave = 0
end

local function distance(position: Vector3, x: number, z: number): number
	local dx, dz = position.X - x, position.Z - z
	return math.sqrt(dx * dx + dz * dz)
end

-- Opens the chest at `index`: every living participant close enough gets a reward, with `everyone` every participant
-- who is not out.
local function open(index: number, everyone: boolean?)
	local chest = table.remove(chests, index) :: Types.ChestInfo
	local rewards: { { userId: number, reward: Types.ChestReward } } = {}
	for _, player in RunDirector.getParticipants() do
		local position = EnemySim.getPlayerPosition(player) -- nil unless alive
		local reached = if everyone
			then RunDirector.getParticipantState(player) ~= "Out"
			else position ~= nil and distance(position, chest.x, chest.z) <= Coop.chestRadius
		if reached then
			local reward = UpgradeService.grantChest(player)
			local _, maxHp = CombatService.getHp(player)
			CombatService.healPlayer(player, maxHp * Coop.chestHealFraction)
			if reward then
				table.insert(rewards, { userId = player.UserId, reward = reward })
			end
			LootService.ChestCollected:Fire(player)
		end
	end
	local opened: Types.ChestOpened = { id = chest.id, x = chest.x, z = chest.z, rewards = rewards }
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("ChestOpened", player, opened)
	end
	sendChests()
end

-- Average Luck of the participants who are not out (Brotato averages it over the players in co-op).
local function teamLuck(): number
	local total, count = 0, 0
	for _, player in RunDirector.getParticipants() do
		if RunDirector.getParticipantState(player) ~= "Out" then
			total += StatService.getStat(player, "luck")
			count += 1
		end
	end
	return if count > 0 then total / count else 0
end

local function round(value: number): number
	return math.round(value * 10) / 10
end

-- Puts a fruit or crate on the floor at x/z; returns its id, or nil when too many fruits lie around already.
local function dropPickup(x: number, z: number, kind: number): number?
	if kind == FRUIT and fruitsOnFloor >= Loot.consumables.maxOnFloor then
		return nil
	end
	nextPickupId += 1
	local pickup = { id = nextPickupId, x = round(x), z = round(z), kind = kind }
	table.insert(pickups, pickup)
	if kind == FRUIT then
		fruitsOnFloor += 1
	end
	table.insert(droppedPickups, pickup.id)
	table.insert(droppedPickups, pickup.x)
	table.insert(droppedPickups, pickup.z)
	table.insert(droppedPickups, kind)
	return pickup.id
end

local function removePickup(index: number, userId: number): Pickup
	local pickup = table.remove(pickups, index) :: Pickup
	if pickup.kind == FRUIT then
		fruitsOnFloor -= 1
	end
	table.insert(collectedPickups, pickup.id)
	table.insert(collectedPickups, userId)
	return pickup
end

-- What a fruit or crate does for the player who takes it: healing, and a crate's item waits for the wave end.
local function consume(player: Player, kind: number)
	local hp, maxHp = CombatService.getHp(player)
	local wasFull = hp >= maxHp -- before the healing (B8: effects for picking one up at full HP)
	if kind == LEGENDARY then
		CombatService.healPlayer(player, maxHp * Loot.legendaryCrate.healShare)
	else
		local base = if kind == CRATE then Loot.crate.heal else Loot.fruit.heal
		CombatService.healPlayer(player, math.max(0, base + StatService.getStat(player, "fruitHeal")))
	end
	if kind == CRATE or kind == LEGENDARY then
		local legendary = kind == LEGENDARY
		if UpgradeService.addCrate(player, legendary) and RunDirector.getPhase() == "Running" then
			local text = if legendary then "Legendary crate!" else "Crate!"
			Net.fireClient("Notify", player, `{text} It opens after the wave.`)
		end
		LootService.ChestCollected:Fire(player)
		LootService.ConsumableCollected:Fire(player, "Crate", wasFull)
	else
		LootService.ConsumableCollected:Fire(player, "Fruit", wasFull)
	end
end

local function onEnemyKilled(info: EnemySim.KillInfo)
	if not RunDirector.isActive() then
		return
	end
	if info.boss then
		if Config.Enemies.bossWave.legendaryCrate then
			dropPickup(info.position.X, info.position.Z, LEGENDARY)
		end
		return
	end
	if info.elite and Config.Enemies.elite.dropsChest then
		LootService.drop(info.position)
		return
	end
	local kind = EnemyKinds.get(info.enemyId, info.elite)
	if not kind or dropsPaused then
		return
	end
	local random = RandomService.stream("Loot")
	local dropped = LootRules.consumable(kind, teamLuck(), cratesThisWave, random:NextNumber(), random:NextNumber())
	if dropped == "Crate" then
		cratesThisWave += 1
		dropPickup(info.position.X, info.position.Z, CRATE)
	elseif dropped == "Fruit" then
		dropPickup(info.position.X, info.position.Z, FRUIT)
	end
end

local function pickUp()
	for _, player in RunDirector.getParticipants() do
		local position = EnemySim.getPlayerPosition(player) -- nil unless alive
		if position then
			local radius = Config.Player.pickupRadius
				* math.max(0, 1 + StatService.getStat(player, "pickupRange") / 100)
			for index = #pickups, 1, -1 do
				local pickup = pickups[index]
				if distance(position, pickup.x, pickup.z) <= radius then
					removePickup(index, player.UserId)
					consume(player, pickup.kind)
				end
			end
		end
	end
end

local function onStepped()
	if #chests > 0 then
		for _, player in RunDirector.getParticipants() do
			local position = EnemySim.getPlayerPosition(player)
			if position then
				for index = #chests, 1, -1 do
					if distance(position, chests[index].x, chests[index].z) <= Coop.chestOpenRadius then
						open(index)
					end
				end
			end
		end
	end
	if #pickups > 0 and RunDirector.isActive() then
		pickUp()
	end
	flushPickups()
end

-- The participant who is not out closest to x/z (last known positions); else the first one not out.
local function nearestSharer(x: number, z: number): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	local fallback: Player? = nil
	for _, player in RunDirector.getParticipants() do
		if RunDirector.getParticipantState(player) ~= "Out" then
			fallback = fallback or player
			local position = EnemySim.getPlayerPosition(player)
			if position then
				local d = distance(position, x, z)
				if d < bestDistance then
					best, bestDistance = player, d
				end
			end
		end
	end
	return best or fallback
end

-- End of a wave: chests open for everyone, crates go to the nearest participant, fruits vanish.
local function onWaveEnd()
	for index = #chests, 1, -1 do
		open(index, true)
	end
	for index = #pickups, 1, -1 do
		local pickup = pickups[index]
		local taker = if pickup.kind ~= FRUIT then nearestSharer(pickup.x, pickup.z) else nil
		removePickup(index, if taker then taker.UserId else 0)
		if taker then
			consume(taker, pickup.kind)
		end
	end
	flushPickups()
end

-- Lifecycle -------------------------------------------------------------------------

function LootService.init()
	EnemySim.EnemyKilled:Connect(onEnemyKilled)
	EnemySim.Stepped:Connect(onStepped)
	RunDirector.RunStarted:Connect(clear)
	RunDirector.RunEnded:Connect(clear)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Shop" then
			onWaveEnd()
		elseif phase == "Running" then
			cratesThisWave = 0
		end
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		Net.fireClient("Chests", requester, list())
		Net.fireClient(
			"Pickups",
			requester,
			{ reset = true, dropped = flattenPickups(), collected = {} } :: Types.PickupEvents
		)
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

-- Puts a fruit ("Fruit"), crate ("Crate") or legendary crate ("Legendary", WP10) on the floor at `position` (x/z;
-- tests and debug). Returns its id, or nil when too many fruits lie around.
function LootService.dropPickup(position: Vector3, kind: string): number?
	local code = if kind == "Crate" then CRATE elseif kind == "Legendary" then LEGENDARY else FRUIT
	local id = dropPickup(position.X, position.Z, code)
	flushPickups()
	return id
end

-- Tests: while paused, kills drop no fruits or crates (elite chests still drop). Stays until changed, also across
-- runs.
function LootService.setDropsPaused(value: boolean)
	dropsPaused = value
end

-- Queries ---------------------------------------------------------------------------

-- The chests on the floor right now.
function LootService.getChests(): { Types.ChestInfo }
	return list()
end

-- Fruits and crates on the floor right now: { id, x, z, kind ("Fruit", "Crate" or "Legendary") }.
function LootService.getPickups(): { { id: number, x: number, z: number, kind: string } }
	local result = {}
	for _, pickup in pickups do
		table.insert(result, { id = pickup.id, x = pickup.x, z = pickup.z, kind = KIND_NAMES[pickup.kind] })
	end
	return result
end

-- Crates dropped so far in this wave (they get rarer with every one).
function LootService.getCratesThisWave(): number
	return cratesThisWave
end

return LootService
