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
local DangerRules = require(Shared.Util.DangerRules)
local CharacterRules = require(Shared.Util.CharacterRules)
local CharacterEconomy = require(Shared.Util.CharacterEconomy)
local Classes = require(Shared.Config.Classes)
local NativeItems = require(Shared.Config.CharacterItemRules)
local Run = require(Shared.Config.Run)

-- One weapon the player carries.
export type OwnedWeapon = { id: string, tier: number, evolution: string? }

export type Params = {
	classId: string?, -- B10 frozen participant character
	weaponSlots: number?,
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
	unavailable: { [string]: boolean }?, -- Paket 13: weapon and item ids the player has not unlocked; never offered
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
function ShopRules.price(base: number, wave: number, factor: number?, affected: boolean?): number
	local rule = Shop.price
	local modifiers = if affected == false then 1 else (factor or 1) * CharacterEconomy.priceInflation(wave)
	local raw = (base + wave * rule.waveAdd + base * rule.waveFactor * wave) * rule.multiplier * modifiers
	return math.max(1, math.floor(raw + 1e-9))
end

-- Weapon Price modifies only the tier base before wave additions; Item Prices and endless inflation apply afterwards.
function ShopRules.weaponPrice(
	weaponId: string,
	tier: number,
	wave: number,
	factor: number?,
	classId: string?,
	affected: boolean?
): number
	local exact = Shop.weaponTierPrices[weaponId]
	local base = if exact then exact[tier] else (Shop.weaponPrices[weaponId] or 0) * (Shop.tierPriceFactors[tier] or 1)
	if affected ~= false then
		base *= 1 + CharacterRules.nativeAmount(classId, "weapons_price") / 100
	end
	return ShopRules.price(base, wave, factor, affected)
end

-- Price of an offer with the Item Prices factor: weapons by tier, items by their base price, both from the wave the
-- offer's price is based on (a locked offer keeps its wave).
function ShopRules.offerPrice(offer: Types.ShopOffer, factor: number?, classId: string?): number
	local value
	if offer.kind == "Weapon" then
		value = ShopRules.weaponPrice(offer.itemId, offer.tier, offer.priceWave, factor, classId)
	else
		local item = Items.byId[offer.itemId]
		local specific = if CharacterRules.nativeOverride(classId, "upgraded_baits", 0) > 0
				and offer.itemId == "BloodLure"
			then -1
			else 0
		value = ShopRules.price(if item then item.price else 0, offer.priceWave, (factor or 1) + specific)
	end
	return if CharacterRules.nativeOverride(classId, "hp_shop", 0) > 0 then CharacterEconomy.hpPrice(value) else value
end

-- Shards for selling a weapon of `tier` after wave `wave`: Config.Shop.sellShare plus `sellValue` percent (the Sell
-- Value stat) of its discounted price; native minimum/cap and endless price-stat rules apply.
function ShopRules.sellPrice(
	weaponId: string,
	tier: number,
	wave: number,
	sellValue: number?,
	factor: number?,
	classId: string?
): number
	local shopPrice = ShopRules.weaponPrice(weaponId, tier, wave, factor, classId)
	local recycleBasis =
		ShopRules.weaponPrice(weaponId, tier, wave, factor, classId, wave <= #Run.spawn.waves.lengthsSeconds)
	return CharacterEconomy.recyclingPrice(recycleBasis, shopPrice, sellValue or 0)
end

-- Price of the next reroll after `rerolls` rerolls in this shop (or level-up choice).
function ShopRules.rerollPrice(wave: number, rerolls: number): number
	local rule = Shop.reroll
	-- Brotato ItemService.get_reroll_price: in endless the increase grows with sqrt(1 + endless factor)
	local endless = math.sqrt(1 + DangerRules.endlessFactor(wave))
	local increase = math.max(1, math.floor(rule.increaseFactor * wave * endless))
	return math.floor(rule.firstFactor * wave) + increase * (rerolls + 1)
end

-- Weapon offers a shop after this wave holds at least, and whether that is also the most (`exact`: every other new
-- slot is an item, Brotato's shops 1-2).
function ShopRules.guaranteedWeapons(wave: number): (number, boolean)
	for _, entry in Shop.guaranteedWeapons do
		if wave <= entry.untilWave then
			return entry.count, entry.exact
		end
	end
	return 0, false
end

local function canTakeItem(itemId: string, ownedItems: { [string]: number }): boolean
	local item = Items.byId[itemId]
	return item ~= nil and (item.limit == nil or (ownedItems[itemId] or 0) < item.limit)
end

-- Normal native pools exclude explicit item identities/groups, never every item with a matching stat.
function ShopRules.itemAllowed(classId: string?, itemId: string, wave: number): boolean
	if not Items.byId[itemId] or Items.byId[itemId].available == false then
		return false
	end
	local class = classId and Classes[classId]
	local native = class and class.native
	if not native then
		return true
	end
	local original = NativeItems.nativeIds[itemId]
	if not original then
		return false
	end
	if wave >= #Run.spawn.waves.lengthsSeconds then
		return table.find(NativeItems.endlessBannedItems, original) == nil
	end
	if table.find(native.bannedItems, original) then
		return false
	end
	for _, group in native.bannedItemGroups do
		local ids = NativeItems.groups[group]
		assert(ids, `Unknown native item group {group}`)
		if table.find(ids, original) then
			return false
		end
	end
	return true
end

-- A random item of `tier` that is not taken and not at its limit; tries the tiers below, then above, if a tier has
-- nothing left. nil if no item is left at all.
function ShopRules.pickItem(
	tier: number,
	ownedItems: { [string]: number },
	taken: { [string]: boolean },
	random: () -> number,
	wantedTags: { string }?,
	classId: string?,
	wave: number?,
	backupTaken: { [string]: boolean }?
): string?
	local function matches(itemId: string): boolean
		if not ShopRules.itemAllowed(classId, itemId, wave or 1) then
			return false
		end
		if not wantedTags then
			return true
		end
		local native = classId and Classes[classId] and Classes[classId].nativeStartSelection
		local tags = if native then NativeItems.tags[itemId] else Items.byId[itemId].tags
		for _, tag in tags do
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
		-- The native same-tier backup removes limits/unavailable items, but not character bans or offer history.
		-- Keep this source exception: normal character exclusions do not become a new hard ban in an empty pool.
		if candidateTier == tier and not wantedTags and classId and Classes[classId] and Classes[classId].native then
			local blocked = backupTaken or taken
			for _, itemId in itemsByTier[candidateTier] or {} do
				if NativeItems.nativeIds[itemId] and not blocked[itemId] and canTakeItem(itemId, ownedItems) then
					table.insert(ids, itemId)
				end
			end
			if #ids > 0 then
				return ids[math.min(#ids, math.floor(random() * #ids) + 1)]
			end
		end
	end
	return nil
end

-- The item of an elite chest: tier rolled by wave and Luck, at least Config.Items.chestMinTier. `unavailable`
-- (Paket 13): item ids the player has not unlocked.
function ShopRules.chestItem(
	wave: number,
	luck: number,
	ownedItems: { [string]: number },
	random: () -> number,
	unavailable: { [string]: boolean }?,
	classId: string?
): string?
	local tier = math.max(Items.chestMinTier, StatMath.rollTier(wave, luck, random()))
	return ShopRules.pickItem(
		tier,
		ownedItems,
		if unavailable then table.clone(unavailable) else {},
		random,
		nil,
		classId,
		wave
	)
end

-- Whether buying a weapon of `tier` merges into an owned copy (every slot full, a copy of the same tier below the max
-- that is not evolved) and whether it cannot be bought at all (slots full, nothing to merge with).
function ShopRules.weaponStatus(
	weaponId: string,
	tier: number,
	ownedWeapons: { OwnedWeapon },
	maxWeapons: number,
	maxTier: number,
	classId: string?,
	weaponSlots: number?
): (boolean, boolean)
	if not CharacterRules.weaponAllowed(classId, weaponId, tier) then
		return false, true
	end
	if
		#ownedWeapons < maxWeapons
		and (not classId or CharacterRules.hasSlot(classId, weaponId, ownedWeapons, weaponSlots, tier))
	then
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

-- Chances of Brotato's weapon pool after `wave` with `distinct` different weapons owned: (owned, sameClass), the
-- second one cumulative (Config.Shop.weaponPool).
function ShopRules.weaponPoolChances(wave: number, distinct: number): (number, number)
	local rule = Shop.weaponPool
	local early = math.max(0, rule.bonusWaves + 1 - wave) / rule.bonusWaves
	local n = math.min(distinct, rule.maxWeapons)
	return rule.owned + early * rule.ownedWaveBonus + n * rule.ownedPerWeapon,
		rule.sameClass + early * rule.classWaveBonus + n * rule.classPerWeapon
end

-- Picks the weapon of one weapon slot from Brotato's pool: by one roll an owned weapon, a new one sharing a weapon
-- class (Config.WeaponClasses) with an owned one, or any new one; an empty pool falls back to any weapon of the tier.
-- `avoid` holds ids already in this shop or (while others are left) in the previous roll. nil if every weapon is
-- avoided.
local function pickWeapon(
	params: Params,
	avoid: { [string]: boolean },
	strict: { [string]: boolean },
	tier: number
): string?
	local ownedIds: { [string]: boolean } = {}
	local ownedTiers: { [string]: number } = {}
	local ownedClasses: { [string]: boolean } = {}
	local distinct = 0
	for _, owned in params.ownedWeapons do
		if not ownedIds[owned.id] then
			distinct += 1
		end
		ownedIds[owned.id] = true
		ownedTiers[owned.id] = math.max(ownedTiers[owned.id] or 0, owned.tier)
		local config = Weapons[owned.id]
		if config then
			for _, classId in config.classes do
				ownedClasses[classId] = true
			end
		end
	end
	local class = params.classId and Classes[params.classId]
	local function allowedDuplicateTier(weaponId: string): boolean
		local ownedTier = ownedTiers[weaponId]
		if class and class.noDuplicateWeapons and ownedTier then
			-- ItemService removes lower tiers and equal copies that no longer upgrade, even from its backup pool.
			return tier >= ownedTier and (tier > ownedTier or tier < params.maxTier)
		end
		return true
	end
	local function pool(filter: (string) -> boolean, skip: { [string]: boolean }): { string }
		local ids = {}
		for _, weaponId in params.weapons do
			if
				not skip[weaponId]
				and CharacterRules.weaponAllowed(params.classId, weaponId, tier)
				and allowedDuplicateTier(weaponId)
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
	local ownedChance, classChance = ShopRules.weaponPoolChances(params.wave, distinct)
	local wanted: (string) -> boolean
	if roll < ownedChance then
		wanted = function(weaponId)
			return ownedIds[weaponId] == true
		end
	elseif roll < classChance then
		wanted = function(weaponId)
			local config = Weapons[weaponId]
			if ownedIds[weaponId] or not config then
				return false
			end
			for _, classId in config.classes do
				if ownedClasses[classId] then
					return true
				end
			end
			return false
		end
	else
		wanted = function(weaponId)
			return not ownedIds[weaponId]
		end
	end
	local filters: { (string) -> boolean } = {
		wanted,
		function()
			return true
		end,
	}
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
	local merges, blocked = ShopRules.weaponStatus(
		weaponId,
		tier,
		params.ownedWeapons,
		params.maxWeapons,
		params.maxTier,
		params.classId,
		params.weaponSlots
	)
	local copies = copiesOf(weaponId, params.ownedWeapons)
	return {
		id = "",
		kind = "Weapon",
		itemId = weaponId,
		tier = tier,
		count = copies,
		isNew = copies == 0,
		price = ShopRules.weaponPrice(weaponId, tier, params.wave, params.priceFactor, params.classId),
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
	for id in params.unavailable or {} do -- Paket 13: not unlocked counts as taken, so it is never offered
		taken[id] = true
		avoid[id] = true
	end
	local weaponsLeft, exactWeapons = ShopRules.guaranteedWeapons(params.wave)
	local guaranteedBait = CharacterRules.nativeOverride(params.classId, "upgraded_baits", 0) > 0
	weaponsLeft = math.max(weaponsLeft, CharacterRules.nativeOverride(params.classId, "minimum_weapons_in_shop", 0))
	for _, offer in params.keep or {} do
		table.insert(offers, offer)
		taken[offer.itemId] = true
		avoid[offer.itemId] = true
		if offer.kind == "Weapon" then
			weaponsLeft -= 1 -- a locked weapon counts towards the guaranteed ones
		end
	end
	while #offers < Shop.slots do
		local forcedBait = guaranteedBait and (not exactWeapons or weaponsLeft <= 0)
		local wantWeapon = not forcedBait
			and (weaponsLeft > 0 or (not exactWeapons and params.random() < Shop.weaponChance))
		local offer: Types.ShopOffer? = nil
		local weaponTier = math.clamp(StatMath.rollTier(params.wave, params.luck, params.random()), 1, params.maxTier)
		local class = params.classId and Classes[params.classId]
		weaponTier = math.clamp(weaponTier, if class then class.minWeaponTier or 1 else 1, params.maxTier)
		local weaponId: string? = nil
		if wantWeapon then
			weaponId = pickWeapon(params, avoid, taken, weaponTier)
		end
		if forcedBait then
			offer = itemOffer("BloodLure", params)
			guaranteedBait = false
		elseif weaponId then
			offer = weaponOffer(weaponId, params, weaponTier)
			weaponsLeft -= 1
		else
			local tier = StatMath.rollTier(params.wave, params.luck, params.random())
			local class = params.classId and Classes[params.classId]
			local tags = class and class.wantedTags
			local itemId: string? = nil
			if tags and #tags > 0 and params.random() < Shop.wantedTagChance then
				itemId = ShopRules.pickItem(
					tier,
					params.ownedItems,
					avoid,
					params.random,
					tags,
					params.classId,
					params.wave
				) or ShopRules.pickItem(
					tier,
					params.ownedItems,
					taken,
					params.random,
					tags,
					params.classId,
					params.wave
				)
			end
			itemId = itemId
				or ShopRules.pickItem(
					tier,
					params.ownedItems,
					avoid,
					params.random,
					nil,
					params.classId,
					params.wave,
					params.unavailable or {}
				)
				or ShopRules.pickItem(
					tier,
					params.ownedItems,
					taken,
					params.random,
					nil,
					params.classId,
					params.wave,
					params.unavailable or {}
				)
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
		offer.price = ShopRules.offerPrice(offer, params.priceFactor, params.classId)
		offer.id = `{params.nextId()}:{offer.kind}:{offer.itemId}`
		table.insert(offers, offer)
	end
	return offers
end

return ShopRules
