--!strict
-- Item effects in a run (DESIGN.md section 6, Brotato direction since B4; records in Config.Items and Config.Effects,
-- rules in EffectService/EffectRules). The event bus of the effect engine: it listens to the other services (wave
-- start and end, shop, level-ups, weapon hits, crits and kills, dodges, hits taken, orbs, chests, a timer), fires the
-- matching effects of each participant's items and carries out their actions (stats for the rest of the run, this
-- wave, a few seconds or the next wave, healing, Shards, HP, random stats, hit shields, weapon tiers). Passive effects
-- (standing still or moving, "per X") and the temporary bonuses go to StatService as one bonus sheet (setDynamic),
-- only when it changes. Also does what a secondary stat does on its own: Orb Healing heals on pickups. Sends
-- EffectProcs (feedback texts over the character) during a wave, one Notify toast for what paid out at the wave end or
-- in the shop (Util/EffectText), and ActiveBonuses (for the HUD) to the owner. Rolls on RandomService's Effects stream.
-- Uses CombatService, EnemySim, ExperienceService, LootService, MapService, RandomService, RunDirector, ShopService,
-- StatService and WeaponService; the smoke test reads getBonuses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)
local EffectText = require(Shared.Util.EffectText)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local ExperienceService = require(script.Parent.ExperienceService)
local LootService = require(script.Parent.LootService)
local MapService = require(script.Parent.MapService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local ShopService = require(script.Parent.ShopService)
local StatService = require(script.Parent.StatService)
local WeaponService = require(script.Parent.WeaponService)
local EffectRules = require(script.EffectRules)

local StandStill = Config.Effects.standStill

type State = {
	player: Player,
	entries: { EffectRules.Entry },
	byTrigger: { [string]: { EffectRules.Entry } },
	watchesMovement: boolean,
	countsShards: boolean,
	countsWeapons: boolean,
	hitTriggers: boolean, -- has Hit, Crit or Kill effects
	eliteMatters: boolean, -- one of them asks for elites
	moveState: string?, -- "Still" or "Moving" while fighting and alive, settled (Config.Effects.standStill)
	pendingState: string?,
	pendingSince: number,
	shards: number,
	distinctWeapons: number,
	shields: number, -- hit shields given this wave
	buffs: EffectRules.Buffs,
	timers: { [string]: number }, -- seconds counted per Timer entry
	dynamic: EffectRules.Sheet, -- last sent to StatService
	bonusKey: string, -- last ActiveBonuses sent, serialized
	procs: { Types.EffectProc },
	roll: () -> number, -- 0 <= n < 1 from the player's Effects stream
}

local EffectService = {}

local states: { [Player]: State } = {}
local byUserId: { [number]: State } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function scaled(stats: { [string]: number }?, times: number): EffectRules.Sheet
	local sheet: EffectRules.Sheet = {}
	for id, value in stats or {} do
		sheet[id] = value * times
	end
	return sheet
end

local function countDistinctWeapons(player: Player): number
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, weapon in WeaponService.getWeapons(player) do
		if not seen[weapon.id] then
			seen[weapon.id] = true
			count += 1
		end
	end
	return count
end

-- A wave (or the boss) is on and the player is alive: standing still, moving and timers count.
local function fighting(player: Player): boolean
	return RunDirector.isActive() and RunDirector.getParticipantState(player) == "Alive"
end

-- Feedback -----------------------------------------------------------------------------------

local function addProc(state: State, proc: Types.EffectProc)
	if #state.procs < Config.Effects.procs.maxPerStep then
		table.insert(state.procs, proc)
	end
end

-- Sends what paid out since the last flush: texts over the character during a wave, else (wave end, shop) one toast
-- naming the items.
local function flushProcs(state: State, toast: boolean?)
	if #state.procs == 0 then
		return
	end
	if toast then
		local lines = {}
		for _, proc in state.procs do
			table.insert(lines, EffectText.procWithItem(proc))
		end
		Net.fireClient("Notify", state.player, table.concat(lines, "\n"))
	else
		Net.fireClient("EffectProcs", state.player, state.procs)
	end
	state.procs = {}
end

local function bonusKey(list: { EffectRules.Bonus }): string
	local parts = {}
	for _, bonus in list do
		local stats = {}
		for id, value in bonus.stats do
			table.insert(stats, `{id}={value}`)
		end
		table.sort(stats)
		table.insert(parts, `{bonus.itemId}/{bonus.kind}/{table.concat(stats, ",")}`)
	end
	return table.concat(parts, ";")
end

-- Bonuses ------------------------------------------------------------------------------------

local function context(state: State): EffectRules.Context
	return {
		moveState = state.moveState,
		permanent = StatService.getPermanentSheet(state.player),
		shards = state.shards,
		distinctWeapons = state.distinctWeapons,
	}
end

-- Recomputes the bonus sheet and the active bonuses; sends what changed.
local function refresh(state: State)
	local ctx = context(state)
	local sheet = EffectRules.passive(state.entries, ctx)
	for id, value in EffectRules.buffSheet(state.buffs) do
		sheet[id] = (sheet[id] or 0) + value
	end
	if not EffectRules.sameSheet(sheet, state.dynamic) then
		state.dynamic = sheet
		StatService.setDynamic(state.player, sheet)
	end
	local bonuses = EffectRules.activeBonuses(state.entries, ctx, state.buffs)
	local key = bonusKey(bonuses)
	if key ~= state.bonusKey then
		state.bonusKey = key
		Net.fireClient("ActiveBonuses", state.player, bonuses :: { Types.ActiveBonus })
	end
end

local function rebuild(state: State)
	local entries = EffectRules.entries(StatService.getItemCounts(state.player))
	state.entries = entries
	state.byTrigger = EffectRules.byTrigger(entries)
	state.watchesMovement = EffectRules.watchesMovement(entries)
	state.countsShards = EffectRules.counts(entries, "shards")
	state.countsWeapons = EffectRules.counts(entries, "distinctWeapons")
	state.hitTriggers = state.byTrigger.Hit ~= nil or state.byTrigger.Crit ~= nil or state.byTrigger.Kill ~= nil
	state.eliteMatters = false
	for _, trigger in { "Hit", "Crit", "Kill" } do
		for _, entry in state.byTrigger[trigger] or {} do
			state.eliteMatters = state.eliteMatters or entry.effect.elite == true
		end
	end
	if not state.watchesMovement then
		state.moveState = nil
		state.pendingState = nil
	end
	refresh(state)
end

-- Actions ------------------------------------------------------------------------------------

local function upgradeWeapon(state: State, entry: EffectRules.Entry)
	local player = state.player
	local candidates = {}
	for _, weapon in WeaponService.getWeapons(player) do
		if weapon.tier < Config.Player.maxWeaponTier and not weapon.evolution then
			table.insert(candidates, weapon)
		end
	end
	if #candidates == 0 then
		local stats = scaled(entry.effect.stats, 1)
		if next(stats) and StatService.addStats(player, stats) then
			addProc(state, { itemId = entry.itemId, kind = "Stats", stats = stats })
		end
		return
	end
	local pick = candidates[RandomService.stream("Effects", player):NextInteger(1, #candidates)]
	if WeaponService.raiseTier(player, pick.uid) then
		addProc(state, { itemId = entry.itemId, kind = "Weapon", weaponId = pick.id, tier = pick.tier + 1 })
	end
end

-- Carries out one firing of an entry with `strength` (EffectRules.strength). Returns true if a bonus changed.
local function apply(state: State, entry: EffectRules.Entry, strength: number): boolean
	local player = state.player
	local effect = entry.effect
	local action = effect.action
	if action == "Grow" then
		local stats = scaled(effect.stats, strength)
		if StatService.addStats(player, stats) then
			addProc(state, { itemId = entry.itemId, kind = "Stats", stats = stats })
		end
	elseif action == "WaveStats" then
		if EffectRules.addWaveStats(state.buffs, entry, strength) then
			addProc(state, { itemId = entry.itemId, kind = "Stats", stats = scaled(effect.stats, strength) })
			return true
		end
	elseif action == "TimedStats" then
		if EffectRules.addTimedStats(state.buffs, entry, strength, now()) then
			addProc(state, { itemId = entry.itemId, kind = "Stats", stats = scaled(effect.stats, strength) })
		end
		return true -- refreshed or stacked
	elseif action == "NextWaveStats" then
		EffectRules.addNextWave(state.buffs, entry, strength)
	elseif action == "Heal" then
		local gained = CombatService.healPlayer(player, (effect.amount or 0) * strength)
		if gained > 0 then
			addProc(state, { itemId = entry.itemId, kind = "Heal", amount = math.round(gained) })
		end
	elseif action == "Shards" then
		local amount = (effect.amount or 0) * strength
		if ShopService.addShards(player, amount) then
			addProc(state, { itemId = entry.itemId, kind = "Shards", amount = amount })
		end
	elseif action == "ShardShare" then
		local amount = EffectRules.shardShare(effect, ShopService.getShards(player), strength)
		if amount > 0 and ShopService.addShards(player, amount) then
			addProc(state, { itemId = entry.itemId, kind = "Shards", amount = amount })
		end
	elseif action == "HpFraction" then
		CombatService.setHpFraction(player, effect.amount or 1)
	elseif action == "RandomStats" then
		local stats = EffectRules.randomStats(math.floor((effect.amount or 0) * strength), state.roll)
		if StatService.addStats(player, stats) then
			addProc(state, { itemId = entry.itemId, kind = "Stats", stats = stats })
		end
	elseif action == "Shields" then
		state.shields += math.floor((effect.amount or 0) * strength)
		CombatService.setHitShields(player, state.shields)
	elseif action == "UpgradeWeapon" then
		for _ = 1, strength do
			upgradeWeapon(state, entry)
		end
	end
	return false
end

-- Fires every entry of the state that matches `event`. Refreshes the bonuses once if any changed.
local function fire(state: State, event: EffectRules.Event, entries: { EffectRules.Entry }?)
	local list = entries or state.byTrigger[event.trigger]
	if not list then
		return
	end
	local changed = false
	for _, entry in list do
		if EffectRules.matches(entry, event, state.buffs) then
			local strength = EffectRules.strength(entry, state.roll)
			if strength > 0 then
				EffectRules.countFiring(entry, state.buffs)
				changed = apply(state, entry, strength) or changed
			end
		end
	end
	if changed then
		refresh(state)
	end
end

local function fireFor(player: Player, trigger: string, extra: { crit: boolean?, elite: boolean? }?)
	local state = states[player]
	if state and state.byTrigger[trigger] then
		fire(state, {
			trigger = trigger,
			wave = RunDirector.getWave(),
			crit = extra and extra.crit,
			elite = extra and extra.elite,
		})
	end
end

-- Events -------------------------------------------------------------------------------------

local function onHit(ownerId: number, enemyId: number, _dealt: number, crit: boolean, killed: boolean)
	local state = byUserId[ownerId]
	if not (state and state.hitTriggers) then
		return
	end
	local elite = false
	if state.eliteMatters then
		local _, isElite = EnemySim.getKind(enemyId)
		elite = isElite
	end
	local wave = RunDirector.getWave()
	fire(state, { trigger = "Hit", wave = wave, crit = crit, elite = elite })
	if crit then
		fire(state, { trigger = "Crit", wave = wave, crit = true, elite = elite })
	end
	if killed then
		fire(state, { trigger = "Kill", wave = wave, crit = crit, elite = elite })
	end
end

local function onItemAdded(player: Player, itemId: string)
	local state = states[player]
	if not state then
		return
	end
	rebuild(state)
	local acquired = {}
	for _, entry in state.byTrigger.Acquire or {} do
		if entry.itemId == itemId then
			-- only the new copy fires
			table.insert(acquired, { key = entry.key, itemId = entry.itemId, effect = entry.effect, count = 1 })
		end
	end
	if #acquired > 0 then
		fire(state, { trigger = "Acquire", wave = RunDirector.getWave() }, acquired)
	end
	if not fighting(player) then
		flushProcs(state, true)
	end
end

local function onPickup(player: Player, orbs: number)
	local state = states[player]
	if not state then
		return
	end
	local chance = StatService.getStat(player, "shardHealing") / 100
	if chance > 0 then
		local heals = 0
		for _ = 1, orbs do
			if state.roll() < chance then
				heals += 1
			end
		end
		if heals > 0 then
			local gained = CombatService.healPlayer(player, heals * Config.Stats.hpScale)
			if gained > 0 then
				addProc(state, { kind = "Heal", amount = math.round(gained) })
			end
		end
	end
	if state.byTrigger.Pickup then
		for _ = 1, orbs do
			fireFor(player, "Pickup")
		end
	end
end

local function onWaveStart()
	local wave = RunDirector.getWave()
	for player, state in states do
		EffectRules.startWave(state.buffs)
		table.clear(state.timers)
		state.moveState = nil
		state.pendingState = nil
		state.shields = 0
		CombatService.setHitShields(player, 0)
		if RunDirector.getParticipantState(player) ~= "Out" then
			fire(state, { trigger = "WaveStart", wave = wave })
		end
		refresh(state)
	end
end

local function onWaveEnd()
	for player, state in states do
		EffectRules.endWave(state.buffs)
		state.moveState = nil
		state.pendingState = nil
		state.shields = 0
		CombatService.setHitShields(player, 0)
		refresh(state)
	end
end

-- Settles standing still or moving from the character's speed (Config.Effects.standStill).
local function updateMovement(state: State, time: number)
	local player = state.player
	local observed: string? = nil
	if fighting(player) then
		local velocity = MapService.getRootVelocity(player)
		local speed = math.sqrt(velocity.X * velocity.X + velocity.Z * velocity.Z)
		observed = if speed < StandStill.maxSpeed then "Still" else "Moving"
	end
	if observed == nil then
		if state.moveState ~= nil then
			state.moveState = nil
			state.pendingState = nil
			refresh(state)
		end
		return
	end
	if observed == state.moveState then
		state.pendingState = nil
		return
	end
	if state.pendingState ~= observed then
		state.pendingState = observed
		state.pendingSince = time
	end
	if time - state.pendingSince >= StandStill.settleSeconds then
		state.moveState = observed
		state.pendingState = nil
		refresh(state)
	end
end

local function onStepped(dt: number, stepNow: number)
	for player, state in states do
		if state.watchesMovement then
			updateMovement(state, stepNow)
		end
		local timers = state.byTrigger.Timer
		if timers and fighting(player) then
			for _, entry in timers do
				local interval = entry.effect.interval or math.huge
				local counted = (state.timers[entry.key] or 0) + dt
				while counted >= interval do
					counted -= interval
					fire(state, { trigger = "Timer", wave = RunDirector.getWave() }, { entry })
				end
				state.timers[entry.key] = counted
			end
		end
		if EffectRules.expire(state.buffs, stepNow) then
			refresh(state)
		end
		flushProcs(state)
	end
end

local function newState(player: Player): State
	return {
		player = player,
		entries = {},
		byTrigger = {},
		watchesMovement = false,
		countsShards = false,
		countsWeapons = false,
		hitTriggers = false,
		eliteMatters = false,
		moveState = nil,
		pendingState = nil,
		pendingSince = 0,
		shards = 0,
		distinctWeapons = countDistinctWeapons(player),
		shields = 0,
		buffs = EffectRules.newBuffs(),
		timers = {},
		dynamic = {},
		bonusKey = "",
		procs = {},
		roll = function(): number
			return RandomService.number("Effects", player)
		end,
	}
end

local function clear()
	for player in states do
		Net.fireClient("ActiveBonuses", player, {} :: { Types.ActiveBonus })
	end
	table.clear(states)
	table.clear(byUserId)
end

-- Lifecycle -------------------------------------------------------------------------

function EffectService.init()
	RunDirector.RunStarted:Connect(function(participants: { Player })
		clear()
		for _, player in participants do
			local state = newState(player)
			states[player] = state
			byUserId[player.UserId] = state
		end
	end)
	RunDirector.PhaseChanged:Connect(function(phase, previous)
		if phase == "Running" then
			onWaveStart()
		elseif phase == "Lobby" or phase == "Countdown" then
			clear()
		elseif phase == "Shop" or previous == "Running" then
			onWaveEnd() -- the shop, or the run went on to the boss or ended in a wave
		end
	end)
	RunDirector.ParticipantStateChanged:Connect(function(player)
		local state = states[player]
		if state and state.watchesMovement then
			updateMovement(state, now())
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		byUserId[player.UserId] = nil
	end)

	StatService.ItemAdded:Connect(onItemAdded)
	StatService.PermanentChanged:Connect(function(player)
		local state = states[player]
		if state then
			refresh(state)
		end
	end)
	WeaponService.Changed:Connect(function(player)
		local state = states[player]
		if not state then
			return
		end
		local count = countDistinctWeapons(player)
		if count ~= state.distinctWeapons then
			state.distinctWeapons = count
			if state.countsWeapons then
				refresh(state)
			end
		end
	end)
	WeaponService.setHitListener(onHit)

	ShopService.ShardsChanged:Connect(function(player, shards: number)
		local state = states[player]
		if state then
			state.shards = shards
			if state.countsShards then
				refresh(state)
			end
		end
	end)
	ShopService.WaveEnding:Connect(function(player)
		fireFor(player, "WaveEnd")
		local state = states[player]
		if state then
			flushProcs(state, true)
		end
	end)
	ShopService.Opened:Connect(function(player)
		fireFor(player, "ShopEnter")
		local state = states[player]
		if state then
			flushProcs(state, true)
		end
	end)
	ShopService.Rerolled:Connect(function(player)
		fireFor(player, "Reroll")
	end)
	ShopService.Bought:Connect(function(player)
		fireFor(player, "Buy")
	end)
	ShopService.Sold:Connect(function(player)
		fireFor(player, "Sell")
	end)

	ExperienceService.LevelGained:Connect(function()
		for player in states do
			if RunDirector.getParticipantState(player) ~= "Out" then
				fireFor(player, "LevelUp")
			end
		end
	end)
	ExperienceService.OrbsPickedUp:Connect(onPickup)
	CombatService.Dodged:Connect(function(player)
		fireFor(player, "Dodge")
	end)
	CombatService.PlayerDamaged:Connect(function(player)
		fireFor(player, "Hurt")
	end)
	CombatService.Blocked:Connect(function(player)
		local state = states[player]
		if state then
			addProc(state, { kind = "Blocked" })
		end
	end)
	LootService.ChestCollected:Connect(function(player)
		fireFor(player, "Chest")
	end)
	EnemySim.Stepped:Connect(onStepped)

	RunDirector.SyncRequested:Connect(function(requester)
		local state = states[requester]
		if state then
			local bonuses = EffectRules.activeBonuses(state.entries, context(state), state.buffs)
			Net.fireClient("ActiveBonuses", requester, bonuses :: { Types.ActiveBonus })
		end
	end)
end

-- Queries ---------------------------------------------------------------------------

-- The player's effect bonuses right now (smoke test): the sheet given to StatService and the active bonuses.
function EffectService.getBonuses(player: Player): (EffectRules.Sheet, { EffectRules.Bonus })
	local state = states[player]
	if not state then
		return {}, {}
	end
	return table.clone(state.dynamic), EffectRules.activeBonuses(state.entries, context(state), state.buffs)
end

-- Whether the player counts as standing still ("Still"), moving ("Moving") or neither right now.
function EffectService.getMoveState(player: Player): string?
	local state = states[player]
	return if state then state.moveState else nil
end

return EffectService
