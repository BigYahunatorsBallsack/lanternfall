--!strict
-- B10: fixed starting stats bypass gain multipliers; item/card/level gains are scaled. Character conversions
-- read unconverted permanent + dynamic stats once, and weapon-dependent bonuses refresh on every loadout change.
-- Player stats and items in a run (DESIGN.md sections 4 and 6, Brotato direction since B2). Since B4 in layers like
-- Brotato's modifier pipeline: the base values, then the permanent gains (items stacking, level-up cards,
-- Harvesting growth, Max HP per team level from ExperienceService.LevelGained, Grow effects and since B5 the weapon class
-- bonuses of the weapons carried, Util/WeaponClasses, on WeaponService.Changed), then the bonuses item
-- effects give right now (EffectService.setDynamic: standing still, "per X", this wave, next wave). Every gain is
-- scaled by the class's gainMultipliers (Util/StatMath); caps apply where a stat is used. On every change the sheet
-- goes to WeaponService, CombatService and ExperienceService, the player gets Stats and everyone gets Items. Players
-- outside the run have the base stats. Fires ItemAdded and PermanentChanged for EffectService.
-- Used by ShopService (items, Luck, Harvesting, shop stats), UpgradeService (upgrades, Luck, items for evolutions and
-- chests), SpawnDirector (the team's enemy stats), EffectService, AdminService and RunStatsService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)
local StatMath = require(Shared.Util.StatMath)
local WeaponClasses = require(Shared.Util.WeaponClasses)
local CharacterRules = require(Shared.Util.CharacterRules)

local CombatService = require(script.Parent.CombatService)
local ExperienceService = require(script.Parent.ExperienceService)
local RunDirector = require(script.Parent.RunDirector)
local WeaponService = require(script.Parent.WeaponService)

type State = {
	rawPermanent: StatMath.Sheet,
	weaponKey: string,
	items: { [string]: number }, -- item id -> count
	itemOrder: { string }, -- in the order they were first taken, for the HUD
	upgrades: StatMath.Sheet, -- level-up cards, Harvesting growth and Grow effects
	levels: number, -- team levels gained in this run (Max HP each)
	classBonus: StatMath.Sheet, -- weapon class bonuses of the weapons carried (B5)
	dynamic: StatMath.Sheet, -- item effect bonuses right now (EffectService)
	permanent: StatMath.Sheet, -- base plus every permanent gain
	sheet: StatMath.Sheet, -- permanent plus dynamic: what the game uses
}

local StatService = {}

-- (player: Player, itemId: string): the player took one more of an item (shop, chest, debug)
StatService.ItemAdded = Signal.new()
-- (player: Player): the permanent stats changed (items, cards, growth, levels), not just effect bonuses
StatService.PermanentChanged = Signal.new()

local states: { [Player]: State } = {}

local function multipliersOf(player: Player): { [string]: number }?
	local classId = RunDirector.getParticipantClassId(player)
	local class = classId and Config.Classes[classId]
	return if class then class.gainMultipliers else nil
end

local function computePermanent(player: Player, state: State): StatMath.Sheet
	local gains: StatMath.Sheet = {}
	local classId = RunDirector.getParticipantClassId(player)
	local class = classId and Config.Classes[classId]
	if class then
		StatMath.add(gains, class.perLevel or {}, state.levels)
	end
	for itemId, count in state.items do
		local item = Config.Items.byId[itemId]
		if item then
			StatMath.add(gains, item.stats, count)
		end
	end
	StatMath.add(gains, state.upgrades)
	StatMath.add(gains, state.classBonus)
	gains.maxHp = (gains.maxHp or 0) + state.levels * Config.Stats.maxHpPerLevel
	local sheet = StatMath.addGains(StatMath.baseSheet(), gains, multipliersOf(player))
	if class then
		StatMath.add(sheet, class.stats)
	end
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

-- Recomputes the sheet (the permanent layer too if `permanent`) and sends it everywhere.
local function update(player: Player, state: State, permanent: boolean)
	if permanent then
		state.rawPermanent = computePermanent(player, state)
		state.permanent = table.clone(state.rawPermanent)
		StatMath.add(
			state.permanent,
			CharacterRules.bonuses(
				RunDirector.getParticipantClassId(player),
				state.rawPermanent,
				WeaponService.getWeapons(player)
			)
		)
	end
	state.sheet = StatMath.addGains(table.clone(state.rawPermanent), state.dynamic, multipliersOf(player))
	StatMath.add(
		state.sheet,
		CharacterRules.bonuses(
			RunDirector.getParticipantClassId(player),
			state.sheet,
			WeaponService.getWeapons(player),
			state.rawPermanent
		)
	)
	push(player, state.sheet)
	if permanent then
		StatService.PermanentChanged:Fire(player)
	end
end

local function classBonusOf(player: Player): StatMath.Sheet
	local ids = {}
	for _, weapon in WeaponService.getWeapons(player) do
		table.insert(ids, weapon.id)
	end
	local bonus = WeaponClasses.bonuses(ids)
	for _, weapon in WeaponService.getWeapons(player) do
		local config = Config.Weapons[weapon.id]
		if config and config.heldStats then
			StatMath.add(bonus, config.heldStats[weapon.tier])
		end
	end
	return bonus
end

-- The player's weapons changed: recompute only if the class bonuses did (setStats fires Changed as well).
local function onWeaponsChanged(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local bonus = classBonusOf(player)
	local ids = {}
	for _, weapon in WeaponService.getWeapons(player) do
		table.insert(ids, weapon.id)
	end
	local key = table.concat(ids, ":")
	local same = state.weaponKey == key
	for statId, value in bonus do
		same = same and state.classBonus[statId] == value
	end
	for statId in state.classBonus do
		same = same and bonus[statId] ~= nil
	end
	if not same then
		state.weaponKey = key
		state.classBonus = bonus
		update(player, state, true)
	end
end

local function resetToBase(player: Player)
	states[player] = nil
	push(player, StatMath.baseSheet())
	Net.fireAllClients("Items", itemLoadout(player))
end

local function onRunStarted(participants: { Player })
	for _, player in Players:GetPlayers() do
		if table.find(participants, player) then
			local state: State = {
				rawPermanent = {},
				weaponKey = "",
				items = {},
				itemOrder = {},
				upgrades = {},
				levels = 0,
				classBonus = classBonusOf(player),
				dynamic = {},
				permanent = {},
				sheet = {},
			}
			states[player] = state
			update(player, state, true)
			local classId = RunDirector.getParticipantClassId(player)
			local class = classId and Config.Classes[classId]
			for _, itemId in (class and class.startItems) or {} do
				StatService.addItem(player, itemId)
			end
			Net.fireAllClients("Items", itemLoadout(player))
		else
			resetToBase(player) -- sat this run out
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------

function StatService.init()
	WeaponService.KillGrowth:Connect(function(player, gains)
		StatService.addStats(player, gains)
	end)
	RunDirector.RunStarted:Connect(onRunStarted)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Lobby" or phase == "Countdown" then
			for _, player in Players:GetPlayers() do
				resetToBase(player)
			end
		end
	end)
	WeaponService.Changed:Connect(onWeaponsChanged)
	ExperienceService.LevelGained:Connect(function()
		for player, state in states do
			if RunDirector.getParticipantState(player) ~= "Out" then
				state.levels += 1
				update(player, state, true)
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
	update(player, state, true)
	Net.fireAllClients("Items", itemLoadout(player))
	StatService.ItemAdded:Fire(player, itemId)
	return true, nil
end

-- Adds `amount` to one stat for the rest of the run (level-up cards). False if the player is not in the run.
function StatService.addUpgrade(player: Player, statId: string, amount: number): boolean
	return StatService.addStats(player, { [statId] = amount })
end

-- Adds stats for the rest of the run (Grow effects, RandomStats, level-up cards). False if the player is not in the
-- run or a stat id is unknown.
function StatService.addStats(player: Player, stats: { [string]: number }): boolean
	local state = states[player]
	if not state then
		return false
	end
	for statId in stats do
		if not Config.Stats.byId[statId] then
			return false
		end
	end
	StatMath.add(state.upgrades, stats)
	update(player, state, true)
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
	update(player, state, true)
end

-- The bonuses item effects give the player right now (EffectService); replaces the previous ones.
function StatService.setDynamic(player: Player, bonuses: StatMath.Sheet)
	local state = states[player]
	if state then
		state.dynamic = table.clone(bonuses)
		update(player, state, false)
	end
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

-- The player's stats without the bonuses of item effects (a copy): what "per X" effects count.
function StatService.getPermanentSheet(player: Player): StatMath.Sheet
	local state = states[player]
	return if state then table.clone(state.permanent) else StatMath.baseSheet()
end

-- The sum of one stat over every participant who is not out (enemy stats work for the whole team).
function StatService.getTeamStat(statId: string): number
	local total = 0
	for player, state in states do
		if RunDirector.getParticipantState(player) ~= "Out" then
			total += state.sheet[statId] or 0
		end
	end
	return total
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
