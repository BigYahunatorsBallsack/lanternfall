--!strict
-- Shop formulas from Config.Shop and Config.Items as pure functions (DESIGN.md section 3, Brotato direction since B1):
-- prices by wave, reroll prices and the offers of one shop (weapons the player can still take or raise, owned ones
-- more likely, a minimum number of weapons in the first shops; items of a rarity rolled by wave and Luck, any number
-- of each up to its limit). Also rolls the item of an elite chest. Used by ShopService and UpgradeService; tested in
-- tests/ShopRules.spec.luau.

local Shared = game:GetService("ReplicatedStorage").Shared
local Items = require(Shared.Config.Items)
local Shop = require(Shared.Config.Shop)
local Types = require(Shared.Net.Types)
local StatMath = require(Shared.Util.StatMath)

export type Params = {
	wave: number, -- the wave that just ended
	luck: number, -- the player's Luck stat
	weapons: { string }, -- weapon ids that can be sold (WeaponService.getImplemented), sorted
	ownedWeapons: { [string]: number }, -- id -> level
	maxWeapons: number,
	maxLevel: number,
	ownedItems: { [string]: number }, -- id -> count
	keep: { Types.ShopOffer }?, -- offers that stay (not used before B3's lock); their items are not rolled again
	nextId: () -> string, -- unique prefix for each new offer id
	random: () -> number, -- 0 <= x < 1
}

type Candidate = { offer: Types.ShopOffer, weight: number }

local ShopRules = {}

-- Item ids by rarity tier, sorted, so the same rolls give the same items.
local itemsByTier: { { string } } = {}
for tier = 1, #Items.tiers do
	itemsByTier[tier] = {}
end
for _, item in Items.list do
	table.insert(itemsByTier[item.tier], item.id)
end
for _, ids in itemsByTier do
	table.sort(ids)
end

-- Price of something with base price `base` after wave `wave`: floor((base + wave * waveAdd + base * waveFactor *
-- wave) * multiplier), at least 1.
function ShopRules.price(base: number, wave: number): number
	local rule = Shop.price
	return math.max(1, math.floor((base + wave * rule.waveAdd + base * rule.waveFactor * wave) * rule.multiplier))
end

-- Price of the next reroll after `rerolls` rerolls in this shop (or level-up choice).
function ShopRules.rerollPrice(wave: number, rerolls: number): number
	local rule = Shop.reroll
	local increase = math.max(1, math.floor(rule.increaseFactor * wave))
	return math.floor(rule.firstFactor * wave) + increase * (rerolls + 1)
end

-- Weapon offers a shop after this wave holds at least.
function ShopRules.guaranteedWeapons(wave: number): number
	for _, entry in Shop.guaranteedWeapons do
		if wave <= entry.untilWave then
			return entry.count
		end
	end
	return 0
end

local function canTakeItem(itemId: string, ownedItems: { [string]: number }): boolean
	local item = Items.byId[itemId]
	return item ~= nil and (item.limit == nil or (ownedItems[itemId] or 0) < item.limit)
end

-- A random item of `tier` that is not taken and not at its limit; tries the tiers below, then above, if a tier has
-- nothing left. nil if no item is left at all.
function ShopRules.pickItem(
	tier: number,
	ownedItems: { [string]: number },
	taken: { [string]: boolean },
	random: () -> number
): string?
	local order = { tier }
	for lower = tier - 1, 1, -1 do
		table.insert(order, lower)
	end
	for higher = tier + 1, #itemsByTier do
		table.insert(order, higher)
	end
	for _, candidateTier in order do
		local ids = {}
		for _, itemId in itemsByTier[candidateTier] or {} do
			if not taken[itemId] and canTakeItem(itemId, ownedItems) then
				table.insert(ids, itemId)
			end
		end
		if #ids > 0 then
			return ids[math.min(#ids, math.floor(random() * #ids) + 1)]
		end
	end
	return nil
end

-- The item of an elite chest: tier rolled by wave and Luck, at least Config.Items.chestMinTier.
function ShopRules.chestItem(
	wave: number,
	luck: number,
	ownedItems: { [string]: number },
	random: () -> number
): string?
	local tier = math.max(Items.chestMinTier, StatMath.rollTier(wave, luck, random()))
	return ShopRules.pickItem(tier, ownedItems, {}, random)
end

local function weaponCandidates(params: Params, taken: { [string]: boolean }): { Candidate }
	local list: { Candidate } = {}
	local ownedCount = 0
	for _ in params.ownedWeapons do
		ownedCount += 1
	end
	for _, weaponId in params.weapons do
		local level = params.ownedWeapons[weaponId]
		local base = Shop.weaponPrices[weaponId]
		if not taken[weaponId] and base then
			local isNew = level == nil
			if (isNew and ownedCount < params.maxWeapons) or (level and level < params.maxLevel) then
				table.insert(list, {
					offer = {
						id = "",
						kind = "Weapon",
						itemId = weaponId,
						tier = 1,
						level = (level or 0) + 1,
						isNew = isNew,
						price = ShopRules.price(base, params.wave),
						sold = false,
					},
					weight = if isNew then 1 else Shop.ownedWeaponWeight,
				})
			end
		end
	end
	return list
end

-- Removes and returns one candidate, picked by weight.
local function takeWeighted(list: { Candidate }, random: () -> number): Candidate
	local total = 0
	for _, candidate in list do
		total += candidate.weight
	end
	local roll = random() * total
	for index, candidate in list do
		roll -= candidate.weight
		if roll < 0 then
			return table.remove(list, index) :: Candidate
		end
	end
	return table.remove(list) :: Candidate
end

local function itemOffer(itemId: string, params: Params): Types.ShopOffer
	local item = Items.byId[itemId]
	local owned = params.ownedItems[itemId] or 0
	return {
		id = "",
		kind = "Item",
		itemId = itemId,
		tier = item.tier,
		level = owned + 1,
		isNew = owned == 0,
		price = ShopRules.price(item.price, params.wave),
		sold = false,
	}
end

-- The offers of one shop: `keep` first, then new ones up to Config.Shop.slots. Fewer when nothing else is left.
function ShopRules.roll(params: Params): { Types.ShopOffer }
	local offers: { Types.ShopOffer } = {}
	local taken: { [string]: boolean } = {}
	for _, offer in params.keep or {} do
		table.insert(offers, offer)
		taken[offer.itemId] = true
	end
	local weapons = weaponCandidates(params, taken)
	local weaponsLeft = ShopRules.guaranteedWeapons(params.wave)
	while #offers < Shop.slots do
		local wantWeapon = weaponsLeft > 0 or params.random() < Shop.weaponChance
		local offer: Types.ShopOffer? = nil
		if wantWeapon and #weapons > 0 then
			offer = takeWeighted(weapons, params.random).offer
			weaponsLeft -= 1
		else
			local tier = StatMath.rollTier(params.wave, params.luck, params.random())
			local itemId = ShopRules.pickItem(tier, params.ownedItems, taken, params.random)
			if itemId then
				offer = itemOffer(itemId, params)
			elseif #weapons > 0 then
				offer = takeWeighted(weapons, params.random).offer
			end
		end
		if not offer then
			break
		end
		taken[offer.itemId] = true
		offer.id = `{params.nextId()}:{offer.kind}:{offer.itemId}`
		table.insert(offers, offer)
	end
	return offers
end

return ShopRules
