--!strict
-- Player stats and items in a run (DESIGN.md sections 4 and 6, Brotato direction since B2). Each participant's stats
-- are summed (Util/StatMath) from the base values, their class (Config.Classes), their items (Config.Items, stacking),
-- level-up upgrades (UpgradeService) and Max HP per team level (ExperienceService.LevelGained); Harvesting grows at
-- every wave end (ShopService calls growHarvesting). On every change the sheet goes to WeaponService, CombatService
-- and ExperienceService, the player gets Stats and everyone gets Items. Players outside the run have the base stats.
-- Used by ShopService (items, Luck, Harvesting), UpgradeService (upgrades, Luck, items for evolutions and chests),
-- AdminService and RunStatsService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)
local StatMath = require(Shared.Util.StatMath)

local CombatService = require(script.Parent.CombatService)
local ExperienceService = require(script.Parent.ExperienceService)
local RunDirector = require(script.Parent.RunDirector)
local WeaponService = require(script.Parent.WeaponService)

type State = {
	items: { [string]: number }, -- item id -> count
	itemOrder: { string }, -- in the order they were first taken, for the HUD
	upgrades: StatMath.Sheet, -- level-up cards and Harvesting growth
	levels: number, -- team levels gained in this run (Max HP each)
	sheet: StatMath.Sheet,
}

local StatService = {}

local states: { [Player]: State } = {}

local function compute(player: Player, state: State): StatMath.Sheet
	local sheet = StatMath.baseSheet()
	local classId = RunDirector.getParticipantClassId(player)
	local class = classId and Config.Classes[classId]
	if class then
		StatMath.add(sheet, class.stats)
	end
	for itemId, count in state.items do
		local item = Config.Items.byId[itemId]
		if item then
			StatMath.add(sheet, item.stats, count)
		end
	end
	StatMath.add(sheet, state.upgrades)
	sheet.maxHp += state.levels * Config.Stats.maxHpPerLevel
	return sheet
end

local function push(player: Player, sheet: StatMath.Sheet)
	WeaponService.setStats(player, table.clone(sheet))
	CombatService.setStats(player, table.clone(sheet))
	ExperienceService.setStats(player, table.clone(sheet))
	Net.fireClient("Stats", player, table.clone(sheet) :: Types.StatSheet)
end

local function itemLoadout(player: Player): Types.ItemLoadout
	local list: { Types.ItemInfo } = {}
	local state = states[player]
	if state then
		for _, itemId in state.itemOrder do
			table.insert(list, { id = itemId, count = state.items[itemId] })
		end
	end
	return { userId = player.UserId, items = list }
end

local function update(player: Player, state: State)
	state.sheet = compute(player, state)
	push(player, state.sheet)
end

local function resetToBase(player: Player)
	states[player] = nil
	push(player, StatMath.baseSheet())
	Net.fireAllClients("Items", itemLoadout(player))
end

local function onRunStarted(participants: { Player })
	for _, player in Players:GetPlayers() do
		if table.find(participants, player) then
			local state: State = { items = {}, itemOrder = {}, upgrades = {}, levels = 0, sheet = {} }
			states[player] = state
			update(player, state)
			Net.fireAllClients("Items", itemLoadout(player))
		else
			resetToBase(player) -- sat this run out
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------

function StatService.init()
	RunDirector.RunStarted:Connect(onRunStarted)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Lobby" or phase == "Countdown" then
			for _, player in Players:GetPlayers() do
				resetToBase(player)
			end
		end
	end)
	ExperienceService.LevelGained:Connect(function()
		for player, state in states do
			if RunDirector.getParticipantState(player) ~= "Out" then
				state.levels += 1
				update(player, state)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		push(player, StatMath.baseSheet())
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		Net.fireAllClients("Items", { userId = player.UserId, items = {} } :: Types.ItemLoadout)
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		for _, player in Players:GetPlayers() do
			Net.fireClient("Items", requester, itemLoadout(player))
		end
		local state = states[requester]
		Net.fireClient(
			"Stats",
			requester,
			(if state then table.clone(state.sheet) else StatMath.baseSheet()) :: Types.StatSheet
		)
	end)
end

-- Commands --------------------------------------------------------------------------

-- Gives the player one more of an item (shop, chests, debug). False plus a reason if they are not in the run
-- ("NotParticipant"), the item does not exist ("UnknownItem") or they own its limit ("Limit").
function StatService.addItem(player: Player, itemId: string): (boolean, string?)
	local state = states[player]
	local item = Config.Items.byId[itemId]
	if not state then
		return false, "NotParticipant"
	elseif not item then
		return false, "UnknownItem"
	end
	local count = state.items[itemId] or 0
	if item.limit and count >= item.limit then
		return false, "Limit"
	end
	if count == 0 then
		table.insert(state.itemOrder, itemId)
	end
	state.items[itemId] = count + 1
	update(player, state)
	Net.fireAllClients("Items", itemLoadout(player))
	return true, nil
end

-- Adds `amount` to one stat for the rest of the run (level-up cards). False if the player is not in the run.
function StatService.addUpgrade(player: Player, statId: string, amount: number): boolean
	local state = states[player]
	if not (state and Config.Stats.byId[statId]) then
		return false
	end
	state.upgrades[statId] = (state.upgrades[statId] or 0) + amount
	update(player, state)
	return true
end

-- Harvesting grows by Config.Stats.harvesting.growth (rounded up) after it paid out at the end of a wave; nothing
-- happens while it is 0 or below.
function StatService.growHarvesting(player: Player)
	local state = states[player]
	local harvesting = if state then state.sheet.harvesting or 0 else 0
	if not state or harvesting <= 0 then
		return
	end
	state.upgrades.harvesting = (state.upgrades.harvesting or 0)
		+ math.ceil(harvesting * Config.Stats.harvesting.growth)
	update(player, state)
end

-- Queries ---------------------------------------------------------------------------

-- One stat of the player (the base value outside a run).
function StatService.getStat(player: Player, statId: string): number
	local state = states[player]
	local sheet = if state then state.sheet else StatMath.baseSheet()
	return sheet[statId] or 0
end

-- All stats of the player (a copy).
function StatService.getSheet(player: Player): StatMath.Sheet
	local state = states[player]
	return if state then table.clone(state.sheet) else StatMath.baseSheet()
end

-- Item id -> count in the current (or last) run (a copy).
function StatService.getItemCounts(player: Player): { [string]: number }
	local state = states[player]
	return if state then table.clone(state.items) else {}
end

-- The player's items in the order they were first taken, with counts.
function StatService.getItems(player: Player): { Types.ItemInfo }
	return itemLoadout(player).items
end

return StatService
