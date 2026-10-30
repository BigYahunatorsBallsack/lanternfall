--!strict
-- Item effect rules as pure functions (DESIGN.md section 6, Brotato direction since B4; record format and numbers in
-- Config.Effects): which effects a player has (one entry per effect of an owned item, with the item count), whether
-- an event fires an entry (conditions, chance rolled per copy, limits per wave), the stat bonuses of passive effects
-- (standing still or moving, "per X") and the bookkeeping of temporary bonuses (this wave, timed, next wave). No
-- Roblox objects; used by EffectService and tested in tests/EffectRules.spec.luau.

local Shared = game:GetService("ReplicatedStorage").Shared
local Effects = require(Shared.Config.Effects)
local Items = require(Shared.Config.Items)
local Stats = require(Shared.Config.Stats)

export type Sheet = { [string]: number }

-- One effect of one item the player owns.
export type Entry = {
	key: string, -- "<itemId>#<index>", unique per player
	itemId: string,
	effect: Effects.Effect,
	count: number, -- copies of the item
}

-- What passive effects look at.
export type Context = {
	moveState: string?, -- "Still" or "Moving" while fighting, nil otherwise (shop, down)
	permanent: Sheet, -- the stats without effect bonuses (StatService.getPermanentSheet)
	shards: number, -- held
	distinctWeapons: number, -- different weapons carried
}

-- One event that may fire triggered effects.
export type Event = {
	trigger: string,
	wave: number,
	crit: boolean?, -- Hit, Crit, Kill
	elite: boolean?, -- Hit, Crit, Kill
	enemyId: number?, -- Hit, Crit, Kill (B5: Burn and Explode act on it)
}

-- Temporary bonuses of one player.
export type Buffs = {
	wave: { [string]: { itemId: string, sheet: Sheet, stacks: number } }, -- by entry key, until the wave ends
	timed: { [string]: { itemId: string, sheet: Sheet, stacks: number, expiresAt: number } }, -- by entry key
	nextWave: { [string]: Sheet }, -- by item id: collected now, active during the next wave
	currentWave: { [string]: Sheet }, -- by item id: the "next wave" bonuses active in this wave
	fired: { [string]: number }, -- firings per entry key this wave (maxPerWave)
}

-- A bonus active right now, for the HUD (Net/Types.ActiveBonus).
export type Bonus = { itemId: string, kind: string, stats: Sheet }

local EffectRules = {}

local function addScaled(sheet: Sheet, stats: { [string]: number }?, times: number)
	if not stats then
		return
	end
	for id, value in stats do
		sheet[id] = (sheet[id] or 0) + value * times
	end
end

local function isEmpty(sheet: Sheet): boolean
	for _, value in sheet do
		if value ~= 0 then
			return false
		end
	end
	return true
end

-- Effects ----------------------------------------------------------------------------------

-- One entry per effect of every item the player owns, sorted by item id and effect order (stable rolls).
function EffectRules.entries(itemCounts: { [string]: number }): { Entry }
	local ids = {}
	for itemId, count in itemCounts do
		local item = Items.byId[itemId]
		if count > 0 and item and item.effects then
			table.insert(ids, itemId)
		end
	end
	table.sort(ids)
	local list: { Entry } = {}
	for _, itemId in ids do
		for index, effect in Items.byId[itemId].effects :: { Effects.Effect } do
			table.insert(
				list,
				{ key = `{itemId}#{index}`, itemId = itemId, effect = effect, count = itemCounts[itemId] }
			)
		end
	end
	return list
end

-- The entries grouped by trigger.
function EffectRules.byTrigger(entries: { Entry }): { [string]: { Entry } }
	local groups: { [string]: { Entry } } = {}
	for _, entry in entries do
		local trigger = entry.effect.trigger
		local group = groups[trigger]
		if not group then
			group = {}
			groups[trigger] = group
		end
		table.insert(group, entry)
	end
	return groups
end

-- Passive effects ---------------------------------------------------------------------------

local function sourceValue(source: string, context: Context): number
	if source == "shards" then
		return context.shards
	elseif source == "distinctWeapons" then
		return context.distinctWeapons
	end
	return context.permanent[source] or 0
end

-- How many steps a PerX effect gives: the source divided by `per`, rounded toward zero, at most `max`.
function EffectRules.perXSteps(effect: Effects.Effect, context: Context): number
	local per = effect.per or 1
	local value = sourceValue(effect.source or "", context) / per
	local steps = if value >= 0 then math.floor(value + 1e-9) else -math.floor(-value + 1e-9)
	if effect.max then
		steps = math.min(steps, effect.max)
	end
	return steps
end

-- The stats passive effects give right now: Stats while their state holds (or always without one) and PerX.
function EffectRules.passive(entries: { Entry }, context: Context): Sheet
	local sheet: Sheet = {}
	for _, entry in entries do
		local effect = entry.effect
		if effect.trigger ~= "Always" then
			continue
		end
		if effect.action == "Stats" then
			if effect.state == nil or effect.state == context.moveState then
				addScaled(sheet, effect.stats, entry.count)
			end
		elseif effect.action == "PerX" then
			local steps = EffectRules.perXSteps(effect, context)
			if steps ~= 0 then
				addScaled(sheet, effect.stats, steps * entry.count)
			end
		end
	end
	return sheet
end

-- True if any entry needs to know whether the player stands still or moves.
function EffectRules.watchesMovement(entries: { Entry }): boolean
	for _, entry in entries do
		if entry.effect.state then
			return true
		end
	end
	return false
end

-- True if any PerX entry counts `source`.
function EffectRules.counts(entries: { Entry }, source: string): boolean
	for _, entry in entries do
		if entry.effect.action == "PerX" and entry.effect.source == source then
			return true
		end
	end
	return false
end

-- Triggered effects -------------------------------------------------------------------------

-- Whether the entry's conditions allow it to fire for `event` (before its chance): the trigger, crit and elite, the
-- wave window and the limit per wave.
function EffectRules.matches(entry: Entry, event: Event, buffs: Buffs): boolean
	local effect = entry.effect
	if effect.trigger ~= event.trigger then
		return false
	end
	if effect.crit and not event.crit then
		return false
	end
	if effect.elite and not event.elite then
		return false
	end
	if (effect.fromWave and event.wave < effect.fromWave) or (effect.untilWave and event.wave > effect.untilWave) then
		return false
	end
	if effect.maxPerWave and (buffs.fired[entry.key] or 0) >= effect.maxPerWave then
		return false
	end
	return true
end

-- How strong one firing is: without a chance the item count; with a chance one roll per copy, and the number of
-- rolls that hit (0 = nothing happens). `random` gives 0 <= n < 1.
function EffectRules.strength(entry: Entry, random: () -> number): number
	local chance = entry.effect.chance
	if chance == nil then
		return entry.count
	end
	local hits = 0
	for _ = 1, entry.count do
		if random() < chance then
			hits += 1
		end
	end
	return hits
end

-- Counts one firing of the entry for its limit per wave.
function EffectRules.countFiring(entry: Entry, buffs: Buffs)
	buffs.fired[entry.key] = (buffs.fired[entry.key] or 0) + 1
end

-- Shards a ShardShare effect gives: `amount` percent of the Shards held per strength, rounded down, at most `max`.
function EffectRules.shardShare(effect: Effects.Effect, shards: number, strength: number): number
	local gained = math.floor(math.max(0, shards) * (effect.amount or 0) / 100 * strength)
	if effect.max then
		gained = math.min(gained, effect.max * strength)
	end
	return gained
end

-- `points` points split at random between the primary stats (Brotato's Candy Bag); one point is
-- Config.Effects.randomPoint[stat] or 1.
function EffectRules.randomStats(points: number, random: () -> number): Sheet
	local primary = {}
	for _, stat in Stats.order do
		if stat.primary then
			table.insert(primary, stat.id)
		end
	end
	local sheet: Sheet = {}
	for _ = 1, points do
		local statId = primary[math.min(#primary, math.floor(random() * #primary) + 1)]
		sheet[statId] = (sheet[statId] or 0) + (Effects.randomPoint[statId] or 1)
	end
	return sheet
end

-- Temporary bonuses -------------------------------------------------------------------------

function EffectRules.newBuffs(): Buffs
	return { wave = {}, timed = {}, nextWave = {}, currentWave = {}, fired = {} }
end

-- One more stack of a WaveStats entry (stats times strength), unless it has maxStacks. True if anything changed.
function EffectRules.addWaveStats(buffs: Buffs, entry: Entry, strength: number): boolean
	local buff = buffs.wave[entry.key]
	if not buff then
		buff = { itemId = entry.itemId, sheet = {}, stacks = 0 }
		buffs.wave[entry.key] = buff
	end
	local maxStacks = entry.effect.maxStacks
	if strength <= 0 or (maxStacks and buff.stacks >= maxStacks) then
		return false
	end
	buff.stacks += 1
	addScaled(buff.sheet, entry.effect.stats, strength)
	return true
end

-- A TimedStats entry fired at `now`: its bonus lasts `seconds` from now; a new stack (up to maxStacks, default 1)
-- adds stats times strength. True if anything changed.
function EffectRules.addTimedStats(buffs: Buffs, entry: Entry, strength: number, now: number): boolean
	if strength <= 0 then
		return false
	end
	local effect = entry.effect
	local buff = buffs.timed[entry.key]
	if not buff then
		buff = { itemId = entry.itemId, sheet = {}, stacks = 0, expiresAt = 0 }
		buffs.timed[entry.key] = buff
	end
	buff.expiresAt = now + (effect.seconds or 0)
	if buff.stacks >= (effect.maxStacks or 1) then
		return false
	end
	buff.stacks += 1
	addScaled(buff.sheet, effect.stats, strength)
	return true
end

-- Stats times strength for the next wave (NextWaveStats).
function EffectRules.addNextWave(buffs: Buffs, entry: Entry, strength: number)
	local sheet = buffs.nextWave[entry.itemId]
	if not sheet then
		sheet = {}
		buffs.nextWave[entry.itemId] = sheet
	end
	addScaled(sheet, entry.effect.stats, strength)
end

-- Drops timed bonuses that ran out by `now`. True if any did.
function EffectRules.expire(buffs: Buffs, now: number): boolean
	local changed = false
	for key, buff in buffs.timed do
		if now >= buff.expiresAt then
			buffs.timed[key] = nil
			changed = true
		end
	end
	return changed
end

-- A wave starts: the "next wave" bonuses become active, everything of the last wave is gone.
function EffectRules.startWave(buffs: Buffs)
	buffs.currentWave = buffs.nextWave
	buffs.nextWave = {}
	buffs.wave = {}
	buffs.timed = {}
	buffs.fired = {}
end

-- A wave ends: bonuses for this wave and timed ones are gone; "next wave" bonuses wait for the next wave.
function EffectRules.endWave(buffs: Buffs)
	buffs.currentWave = {}
	buffs.wave = {}
	buffs.timed = {}
	buffs.fired = {}
end

-- Every temporary bonus active right now, added up.
function EffectRules.buffSheet(buffs: Buffs): Sheet
	local sheet: Sheet = {}
	for _, buff in buffs.wave do
		addScaled(sheet, buff.sheet, 1)
	end
	for _, buff in buffs.timed do
		addScaled(sheet, buff.sheet, 1)
	end
	for _, stats in buffs.currentWave do
		addScaled(sheet, stats, 1)
	end
	return sheet
end

-- The bonuses active right now that come and go (for the HUD): standing still or moving, this wave, timed, and the
-- next-wave ones while that wave runs; sorted by item id and kind. PerX bonuses are left out (they show in the
-- stats).
function EffectRules.activeBonuses(entries: { Entry }, context: Context, buffs: Buffs): { Bonus }
	local list: { Bonus } = {}
	for _, entry in entries do
		local effect = entry.effect
		if
			effect.trigger == "Always"
			and effect.action == "Stats"
			and effect.state == context.moveState
			and effect.state
		then
			local stats: Sheet = {}
			addScaled(stats, effect.stats, entry.count)
			table.insert(list, { itemId = entry.itemId, kind = effect.state, stats = stats })
		end
	end
	for _, buff in buffs.wave do
		if not isEmpty(buff.sheet) then
			table.insert(list, { itemId = buff.itemId, kind = "Wave", stats = table.clone(buff.sheet) })
		end
	end
	for _, buff in buffs.timed do
		table.insert(list, { itemId = buff.itemId, kind = "Timed", stats = table.clone(buff.sheet) })
	end
	for itemId, stats in buffs.currentWave do
		table.insert(list, { itemId = itemId, kind = "NextWave", stats = table.clone(stats) })
	end
	table.sort(list, function(a, b)
		if a.itemId ~= b.itemId then
			return a.itemId < b.itemId
		end
		return a.kind < b.kind
	end)
	return list
end

-- True if two sheets hold the same values (missing = 0).
function EffectRules.sameSheet(a: Sheet, b: Sheet): boolean
	for id, value in a do
		if math.abs(value - (b[id] or 0)) > 1e-9 then
			return false
		end
	end
	for id, value in b do
		if a[id] == nil and value ~= 0 then
			return false
		end
	end
	return true
end

return EffectRules
