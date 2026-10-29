--!strict
-- Rolls level-up cards (DESIGN.md section 9, Brotato direction since B2): `cardCount` different primary stats
-- (Config.Stats), each with its own rarity tier: rolled like shop items with the level in place of the wave and Luck
-- raising it (Util/StatMath.rollTier), or fixed on some levels (Config.Run.levelUp.guaranteedTiers and
-- legendaryEvery). Also lists the evolutions a player may take (weapon at max level plus its item). Pure and unit
-- tested (tests/UpgradePool.spec.luau); used by UpgradeService.

local Shared = game:GetService("ReplicatedStorage").Shared
local Evolutions = require(Shared.Config.Evolutions)
local Items = require(Shared.Config.Items)
local Run = require(Shared.Config.Run)
local Stats = require(Shared.Config.Stats)
local Types = require(Shared.Net.Types)
local StatMath = require(Shared.Util.StatMath)

export type Params = {
	level: number, -- the team level this choice belongs to
	luck: number, -- the player's Luck stat
	cardCount: number,
	avoid: { [string]: boolean }?, -- stat ids to leave out while enough others are left (reroll)
	random: () -> number, -- 0 <= x < 1
}

local UpgradePool = {}

-- Stats that have level-up upgrades, in the order of Config.Stats.
local upgradeStats: { string } = {}
for _, stat in Stats.order do
	if stat.upgrade then
		table.insert(upgradeStats, stat.id)
	end
end

function UpgradePool.cardId(statId: string, tier: number): string
	return `Stat:{statId}:{tier}`
end

-- The tier every card of this level has, or nil when each card rolls its own.
function UpgradePool.guaranteedTier(level: number): number?
	local rule = Run.levelUp
	local every = rule.legendaryEvery
	if level >= every.fromLevel and (level - every.fromLevel) % every.every == 0 then
		return #Items.tiers -- the rarest
	end
	return rule.guaranteedTiers[level]
end

-- One card for `statId` at `tier`.
function UpgradePool.card(statId: string, tier: number): Types.UpgradeCard
	local values = Stats.byId[statId].upgrade :: { number }
	local clamped = math.clamp(tier, 1, #values)
	return { id = UpgradePool.cardId(statId, clamped), stat = statId, tier = clamped, amount = values[clamped] }
end

function UpgradePool.roll(params: Params): { Types.UpgradeCard }
	local fresh: { string } = {}
	local avoided: { string } = {}
	for _, statId in upgradeStats do
		table.insert(if params.avoid and params.avoid[statId] then avoided else fresh, statId)
	end
	local fixedTier = UpgradePool.guaranteedTier(params.level)
	local cards: { Types.UpgradeCard } = {}
	for _, pool in { fresh, avoided } do
		while #cards < params.cardCount and #pool > 0 do
			local index = math.min(#pool, math.floor(params.random() * #pool) + 1)
			local statId = table.remove(pool, index) :: string
			local tier = fixedTier or StatMath.rollTier(params.level, params.luck, params.random())
			table.insert(cards, UpgradePool.card(statId, tier))
		end
	end
	return cards
end

-- Evolution ids the player may take now (DESIGN.md section 6), sorted: a copy of the weapon at `maxTier` and not
-- evolved yet, plus at least one of the item. `ownedWeapons` lists the carried weapons, `ownedItems` item id -> count.
function UpgradePool.evolutionsFor(
	ownedWeapons: { { id: string, tier: number, evolution: string? } },
	ownedItems: { [string]: number },
	maxTier: number
): { string }
	local ids = {}
	for id, evolution in Evolutions do
		if (ownedItems[evolution.item] or 0) > 0 then
			for _, weapon in ownedWeapons do
				if weapon.id == evolution.weapon and weapon.tier >= maxTier and not weapon.evolution then
					table.insert(ids, id)
					break
				end
			end
		end
	end
	table.sort(ids)
	return ids
end

return UpgradePool
