--!strict
-- Rolls level-up cards (DESIGN.md section 9): up to `cardCount` different cards from every weapon and passive the
-- player can still take or raise, owned items `ownedWeight` times as likely; with full slots only upgrades are left.
-- When fewer items are left than cards, rewards ("Heal", "Embers") fill the gaps, so a maxed-out player picks a
-- reward. Also sums up what owned passives add to the player's stats, lists the evolutions a player may take and
-- picks the upgrade of an elite chest (WP9). Pure and unit tested
-- (tests/UpgradePool.spec.luau); used by UpgradeService.

local Shared = game:GetService("ReplicatedStorage").Shared
local Evolutions = require(Shared.Config.Evolutions)
local Passives = require(Shared.Config.Passives)
local Types = require(Shared.Net.Types)

export type Params = {
	weapons: { string }, -- weapon ids that can be given out (WeaponService.getImplemented), sorted
	passives: { string }, -- passive ids, sorted
	ownedWeapons: { [string]: number }, -- id -> level
	ownedPassives: { [string]: number },
	maxWeapons: number,
	maxPassives: number,
	maxLevel: number,
	cardCount: number,
	ownedWeight: number,
	rewards: { string }, -- reward ids, in the order they fill up missing cards
	avoid: { [string]: boolean }?, -- card ids to leave out while enough others are left (reroll)
	random: () -> number, -- 0 <= x < 1
}

type Candidate = { card: Types.UpgradeCard, weight: number }

local UpgradePool = {}

function UpgradePool.cardId(kind: string, itemId: string): string
	return `{kind}:{itemId}`
end

local function addCandidates(
	out: { Candidate },
	kind: "Weapon" | "Passive",
	ids: { string },
	owned: { [string]: number },
	maxSlots: number,
	params: Params
)
	local ownedCount = 0
	for _ in owned do
		ownedCount += 1
	end
	for _, itemId in ids do
		local level = owned[itemId]
		if level then
			if level < params.maxLevel then
				table.insert(out, {
					card = {
						id = UpgradePool.cardId(kind, itemId),
						kind = kind,
						itemId = itemId,
						level = level + 1,
						isNew = false,
					},
					weight = params.ownedWeight,
				})
			end
		elseif ownedCount < maxSlots then
			table.insert(out, {
				card = { id = UpgradePool.cardId(kind, itemId), kind = kind, itemId = itemId, level = 1, isNew = true },
				weight = 1,
			})
		end
	end
end

-- Removes and returns one candidate, picked by weight.
local function takeWeighted(candidates: { Candidate }, random: () -> number): Candidate
	local total = 0
	for _, candidate in candidates do
		total += candidate.weight
	end
	local roll = random() * total
	for index, candidate in candidates do
		roll -= candidate.weight
		if roll < 0 then
			return table.remove(candidates, index) :: Candidate
		end
	end
	return table.remove(candidates) :: Candidate
end

function UpgradePool.roll(params: Params): { Types.UpgradeCard }
	local candidates: { Candidate } = {}
	addCandidates(candidates, "Weapon", params.weapons, params.ownedWeapons, params.maxWeapons, params)
	addCandidates(candidates, "Passive", params.passives, params.ownedPassives, params.maxPassives, params)

	-- Fresh cards first; avoided ones (the cards before a reroll) only when nothing else is left.
	local fresh: { Candidate } = {}
	local avoided: { Candidate } = {}
	for _, candidate in candidates do
		local list = if params.avoid and params.avoid[candidate.card.id] then avoided else fresh
		table.insert(list, candidate)
	end

	local cards: { Types.UpgradeCard } = {}
	for _, pool in { fresh, avoided } do
		while #cards < params.cardCount and #pool > 0 do
			table.insert(cards, takeWeighted(pool, params.random).card)
		end
	end
	for _, rewardId in params.rewards do
		if #cards >= params.cardCount then
			break
		end
		table.insert(cards, {
			id = UpgradePool.cardId("Reward", rewardId),
			kind = "Reward",
			itemId = rewardId,
			level = 1,
			isNew = false,
		})
	end
	return cards
end

-- Stat bonuses of the owned passives by stat name (Config.Passives): "percent" passives as fractions
-- (Might 2 = { damage = 0.2 }), "flat" ones as absolute values (Armor 2 = { armor = 2 }).
function UpgradePool.passiveBonuses(ownedPassives: { [string]: number }): { [string]: number }
	local bonuses: { [string]: number } = {}
	for passiveId, level in ownedPassives do
		local passive = Passives[passiveId]
		if passive then
			bonuses[passive.stat] = (bonuses[passive.stat] or 0) + passive.perLevel * level
		end
	end
	return bonuses
end

-- One more level of a random owned weapon or passive below `maxLevel` (elite chests, DESIGN.md section 8), all
-- equally likely, as the card it would be; nil when everything owned is maxed. Ids are walked sorted, so the same
-- roll gives the same item.
function UpgradePool.chestUpgrade(
	ownedWeapons: { [string]: number },
	ownedPassives: { [string]: number },
	maxLevel: number,
	random: () -> number
): Types.UpgradeCard?
	local cards: { Types.UpgradeCard } = {}
	for _, entry in { { kind = "Weapon", owned = ownedWeapons }, { kind = "Passive", owned = ownedPassives } } do
		local ids = {}
		for id, level in entry.owned do
			if level < maxLevel then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		for _, id in ids do
			local kind = entry.kind :: "Weapon" | "Passive"
			table.insert(cards, {
				id = UpgradePool.cardId(kind, id),
				kind = kind,
				itemId = id,
				level = entry.owned[id] + 1,
				isNew = false,
			})
		end
	end
	if #cards == 0 then
		return nil
	end
	return cards[math.min(#cards, math.floor(random() * #cards) + 1)]
end

-- Evolution ids the player may take now (DESIGN.md section 6), sorted: the weapon at `maxLevel` and not evolved yet,
-- plus the passive at any level. `ownedWeapons` maps weapon id -> { level, evolution }.
function UpgradePool.evolutionsFor(
	ownedWeapons: { [string]: { level: number, evolution: string? } },
	ownedPassives: { [string]: number },
	maxLevel: number
): { string }
	local ids = {}
	for id, evolution in Evolutions do
		local weapon = ownedWeapons[evolution.weapon]
		if weapon and weapon.level >= maxLevel and not weapon.evolution and ownedPassives[evolution.passive] then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

return UpgradePool
