--!strict
-- Shop formulas from Config.Shop and Config.Items as pure functions (DESIGN.md section 3, Brotato direction since B1,
-- complete since B3): prices by wave (weapons also by tier), sell prices, reroll prices and the offers of one shop
-- (locked offers stay; weapons of a rolled tier from Brotato's pool: owned ones, same class, any; items of a rarity
-- rolled by wave and Luck, any number of each up to its limit; nothing from the previous roll again if anything else
-- is left), and whether a weapon offer merges or is blocked. Also rolls the item of an elite chest. Since B4 prices
-- take the Item Prices factor (Util/StatMath.priceFactor) and sell prices the Sell Value stat. Used by ShopService and
-- UpgradeService; tested in tests/ShopRules.spec.luau.

local Shared = game:GetService("ReplicatedStorage").Shared
local Items = require(Shared.Config.Items)
local Shop = require(Shared.Config.Shop)
local Weapons = require(Shared.Config.Weapons)
local Types = require(Shared.Net.Types)
local StatMath = require(Shared.Util.StatMath)
local CharacterRules = require(Shared.Util.CharacterRules)
local Classes = require(Shared.Config.Classes)

-- One weapon the player carries.
export type OwnedWeapon = { id: string, tier: number, evolution: string? }

export type Params = {
	classId: string?, -- B10 frozen participant character
	wave: number, -- the wave that just ended
	luck: number, -- the player's Luck stat
	weapons: { string }, -- weapon ids that can be sold (WeaponService.getImplemented), sorted
	ownedWeapons: { OwnedWeapon },
	maxWeapons: number,
	maxTier: number,
	ownedItems: { [string]: number }, -- id -> count
	priceFactor: number?, -- from the Item Prices stat (StatMath.priceFactor); 1 if nil
	keep: { Types.ShopOffer }?, -- locked offers; they stay first and their weapons and items are not rolled again
	previous: { [string]: boolean }?, -- weapon and item ids of the roll before (reroll); avoided while others are left
	nextId: () -> string, -- unique prefix for each new offer id
	random: () -> number, -- 0 <= x < 1
}

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
-- wave) * multiplier * factor), at least 1; `factor` from the Item Prices stat (Brotato's items_price_mult).
function ShopRules.price(base: number, wave: number, factor: number?): number
	local rule = Shop.price
	local raw = (base + wave * rule.waveAdd + base * rule.waveFactor * wave) * rule.multiplier * (factor or 1)
	return math.max(1, math.floor(raw + 1e-9))
end

-- Price of a weapon of `tier` after wave `wave`: its tier I base price times Config.Shop.tierPriceFactors[tier].
function ShopRules.weaponPrice(weaponId: string, tier: number, wave: number, factor: number?): number
	local exact = Shop.weaponTierPrices[weaponId]
	if exact then
		return ShopRules.price(exact[tier], wave, factor)
	end
	local base = Shop.weaponPrices[weaponId] or 0
	return ShopRules.price(base * (Shop.tierPriceFactors[tier] or 1), wave, factor)
end

-- Price of an offer with the Item Prices factor: weapons by tier, items by their base price, both from the wave the
-- offer's price is based on (a locked offer keeps its wave).
function ShopRules.offerPrice(offer: Types.ShopOffer, factor: number?): number
	if offer.kind == "Weapon" then
		return ShopRules.weaponPrice(offer.itemId, offer.tier, offer.priceWave, factor)
	end
	local item = Items.byId[offer.itemId]
	return ShopRules.price(if item then item.price else 0, offer.priceWave, factor)
end

-- Shards for selling a weapon of `tier` after wave `wave`: Config.Shop.sellShare plus `sellValue` percent (the Sell
-- Value stat) of its price without discounts, rounded down.
function ShopRules.sellPrice(weaponId: string, tier: number, wave: number, sellValue: number?): number
	local share = math.max(0, Shop.sellShare + (sellValue or 0) / 100)
	return math.floor(ShopRules.weaponPrice(weaponId, tier, wave) * share + 1e-9)
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
	random: () -> number,
	wantedTags: { string }?
): string?
	local function matches(itemId: string): boolean
		if not wantedTags then
			return true
		end
		for _, tag in Items.byId[itemId].tags do
			if table.find(wantedTags, tag) then
				return true
			end
		end
		return false
	end
	local order = { tier }
	if not wantedTags then
		for lower = tier - 1, 1, -1 do
			table.insert(order, lower)
		end
		for higher = tier + 1, #itemsByTier do
			table.insert(order, higher)
		end
	end
	for _, candidateTier in order do
		local ids = {}
		for _, itemId in itemsByTier[candidateTier] or {} do
			if not taken[itemId] and canTakeItem(itemId, ownedItems) and matches(itemId) then
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

-- Whether buying a weapon of `tier` merges into an owned copy (every slot full, a copy of the same tier below the max
-- that is not evolved) and whether it cannot be bought at all (slots full, nothing to merge with).
function ShopRules.weaponStatus(
	weaponId: string,
	tier: number,
	ownedWeapons: { OwnedWeapon },
	maxWeapons: number,
	maxTier: number,
	classId: string?
): (boolean, boolean)
	if not CharacterRules.weaponAllowed(classId, weaponId) then
		return false, true
	end
	if #ownedWeapons < maxWeapons and (not classId or CharacterRules.hasSlot(classId, weaponId, ownedWeapons)) then
		return false, false
	end
	for _, owned in ownedWeapons do
		if owned.id == weaponId and owned.tier == tier and tier < maxTier and not owned.evolution then
			return true, false
		end
	end
	return false, true
end

local function copiesOf(weaponId: string, ownedWeapons: { OwnedWeapon }): number
	local count = 0
	for _, owned in ownedWeapons do
		if owned.id == weaponId then
			count += 1
		end
	end
	return count
end

-- Picks the weapon of one weapon slot from Brotato's pool: owned ones, else ones sharing a weapon class
-- (Config.WeaponClasses, since B5; before Melee/Ranged/Elemental) with an owned one,
-- else any; a pool with nothing left falls through to the next. `avoid` holds ids already in this shop or (while
-- others are left) in the previous roll. nil if every weapon is avoided.
local function pickWeapon(
	params: Params,
	avoid: { [string]: boolean },
	strict: { [string]: boolean },
	tier: number
): string?
	local ownedIds: { [string]: boolean } = {}
	local ownedClasses: { [string]: boolean } = {}
	for _, owned in params.ownedWeapons do
		ownedIds[owned.id] = true
		local config = Weapons[owned.id]
		if config then
			for _, classId in config.classes do
				ownedClasses[classId] = true
			end
		end
	end
	local function pool(filter: (string) -> boolean, skip: { [string]: boolean }): { string }
		local ids = {}
		for _, weaponId in params.weapons do
			if
				not skip[weaponId]
				and CharacterRules.weaponAllowed(params.classId, weaponId)
				and Shop.weaponPrices[weaponId]
				and (Weapons[weaponId].minTier or 1) <= tier
				and filter(weaponId)
			then
				table.insert(ids, weaponId)
			end
		end
		return ids
	end
	local roll = params.random()
	local rule = Shop.weaponPool
	local filters: { (string) -> boolean } = {}
	if roll < rule.owned then
		table.insert(filters, function(weaponId)
			return ownedIds[weaponId] == true
		end)
	end
	if roll < rule.owned + rule.sameClass then
		table.insert(filters, function(weaponId)
			local config = Weapons[weaponId]
			if config then
				for _, classId in config.classes do
					if ownedClasses[classId] then
						return true
					end
				end
			end
			return false
		end)
	end
	table.insert(filters, function()
		return true
	end)
	for _, skip in { avoid, strict } do
		for _, filter in filters do
			local ids = pool(filter, skip)
			if #ids > 0 then
				return ids[math.min(#ids, math.floor(params.random() * #ids) + 1)]
			end
		end
	end
	return nil
end

local function weaponOffer(weaponId: string, params: Params, tier: number): Types.ShopOffer
	local merges, blocked =
		ShopRules.weaponStatus(weaponId, tier, params.ownedWeapons, params.maxWeapons, params.maxTier, params.classId)
	local copies = copiesOf(weaponId, params.ownedWeapons)
	return {
		id = "",
		kind = "Weapon",
		itemId = weaponId,
		tier = tier,
		count = copies,
		isNew = copies == 0,
		price = ShopRules.weaponPrice(weaponId, tier, params.wave, params.priceFactor),
		priceWave = params.wave,
		sold = false,
		locked = false,
		merges = merges,
		blocked = blocked,
	}
end

local function itemOffer(itemId: string, params: Params): Types.ShopOffer
	local item = Items.byId[itemId]
	local owned = params.ownedItems[itemId] or 0
	return {
		id = "",
		kind = "Item",
		itemId = itemId,
		tier = item.tier,
		count = owned + 1,
		isNew = owned == 0,
		price = ShopRules.price(item.price, params.wave, params.priceFactor),
		priceWave = params.wave,
		sold = false,
		locked = false,
		merges = false,
		blocked = false,
	}
end

-- The offers of one shop: `keep` first, then new ones up to Config.Shop.slots. Fewer when nothing else is left.
function ShopRules.roll(params: Params): { Types.ShopOffer }
	local offers: { Types.ShopOffer } = {}
	local taken: { [string]: boolean } = {} -- in this shop
	local avoid: { [string]: boolean } = {} -- in this shop or the previous roll
	for itemId in params.previous or {} do
		avoid[itemId] = true
	end
	local weaponsLeft = ShopRules.guaranteedWeapons(params.wave)
	for _, offer in params.keep or {} do
		table.insert(offers, offer)
		taken[offer.itemId] = true
		avoid[offer.itemId] = true
		if offer.kind == "Weapon" then
			weaponsLeft -= 1 -- a locked weapon counts towards the guaranteed ones
		end
	end
	while #offers < Shop.slots do
		local wantWeapon = weaponsLeft > 0 or params.random() < Shop.weaponChance
		local offer: Types.ShopOffer? = nil
		local weaponTier = math.clamp(StatMath.rollTier(params.wave, params.luck, params.random()), 1, params.maxTier)
		local weaponId = if wantWeapon then pickWeapon(params, avoid, taken, weaponTier) else nil
		if weaponId then
			offer = weaponOffer(weaponId, params, weaponTier)
			weaponsLeft -= 1
		else
			local tier = StatMath.rollTier(params.wave, params.luck, params.random())
			local class = params.classId and Classes[params.classId]
			local tags = class and class.wantedTags
			local itemId: string? = nil
			if tags and #tags > 0 and params.random() < Shop.wantedTagChance then
				itemId = ShopRules.pickItem(tier, params.ownedItems, avoid, params.random, tags)
					or ShopRules.pickItem(tier, params.ownedItems, taken, params.random, tags)
			end
			itemId = itemId
				or ShopRules.pickItem(tier, params.ownedItems, avoid, params.random)
				or ShopRules.pickItem(tier, params.ownedItems, taken, params.random)
			if itemId then
				offer = itemOffer(itemId, params)
			else
				weaponId = pickWeapon(params, avoid, taken, weaponTier)
				if weaponId then
					offer = weaponOffer(weaponId, params, weaponTier)
				end
			end
		end
		if not offer then
			break
		end
		taken[offer.itemId] = true
		avoid[offer.itemId] = true
		offer.id = `{params.nextId()}:{offer.kind}:{offer.itemId}`
		table.insert(offers, offer)
	end
	return offers
end

return ShopRules
