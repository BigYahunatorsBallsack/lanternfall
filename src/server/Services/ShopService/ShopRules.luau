--!strict
-- Shop formulas from Config.Shop as pure functions (DESIGN.md section 3, Brotato direction since B1): prices by wave,
-- reroll prices and the offers of one shop (weapons and passives the player can still take or raise, owned ones more
-- likely, a minimum number of weapons in the first shops). Used by ShopService; tested in tests/ShopRules.spec.luau.

local Shared = game:GetService("ReplicatedStorage").Shared
local Shop = require(Shared.Config.Shop)
local Types = require(Shared.Net.Types)

export type Params = {
	wave: number, -- the wave that just ended
	weapons: { string }, -- weapon ids that can be sold (WeaponService.getImplemented), sorted
	passives: { string }, -- passive ids, sorted
	ownedWeapons: { [string]: number }, -- id -> level
	ownedPassives: { [string]: number },
	maxWeapons: number,
	maxPassives: number,
	maxLevel: number,
	keep: { Types.ShopOffer }?, -- offers that stay (not used before B3's lock); their items are not rolled again
	nextId: () -> string, -- unique prefix for each new offer id
	random: () -> number, -- 0 <= x < 1
}

type Candidate = { offer: Types.ShopOffer, weight: number }

local ShopRules = {}

-- Price of something with base price `base` after wave `wave`: floor((base + wave * waveAdd + base * waveFactor *
-- wave) * multiplier), at least 1.
function ShopRules.price(base: number, wave: number): number
	local rule = Shop.price
	return math.max(1, math.floor((base + wave * rule.waveAdd + base * rule.waveFactor * wave) * rule.multiplier))
end

-- Price of the next reroll after `rerolls` rerolls in this shop.
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

local function candidates(
	kind: "Weapon" | "Passive",
	ids: { string },
	owned: { [string]: number },
	maxSlots: number,
	params: Params,
	taken: { [string]: boolean }
): { Candidate }
	local list: { Candidate } = {}
	local ownedCount = 0
	for _ in owned do
		ownedCount += 1
	end
	for _, itemId in ids do
		local level = owned[itemId]
		local base = Shop.basePrices[itemId]
		if not taken[itemId] and base then
			local isNew = level == nil
			if (isNew and ownedCount < maxSlots) or (level and level < params.maxLevel) then
				table.insert(list, {
					offer = {
						id = "",
						kind = kind,
						itemId = itemId,
						level = (level or 0) + 1,
						isNew = isNew,
						price = ShopRules.price(base, params.wave),
						sold = false,
					},
					weight = if isNew then 1 else Shop.ownedItemWeight,
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

-- The offers of one shop: `keep` first, then new ones up to Config.Shop.slots. Fewer when nothing else is left.
function ShopRules.roll(params: Params): { Types.ShopOffer }
	local offers: { Types.ShopOffer } = {}
	local taken: { [string]: boolean } = {}
	for _, offer in params.keep or {} do
		table.insert(offers, offer)
		taken[offer.itemId] = true
	end
	local weapons = candidates("Weapon", params.weapons, params.ownedWeapons, params.maxWeapons, params, taken)
	local passives = candidates("Passive", params.passives, params.ownedPassives, params.maxPassives, params, taken)
	local weaponsLeft = ShopRules.guaranteedWeapons(params.wave)
	while #offers < Shop.slots and (#weapons > 0 or #passives > 0) do
		local wantWeapon = weaponsLeft > 0 or params.random() < Shop.weaponChance
		local pool = if (wantWeapon and #weapons > 0) or #passives == 0 then weapons else passives
		local offer = takeWeighted(pool, params.random).offer
		if offer.kind == "Weapon" then
			weaponsLeft -= 1
		end
		offer.id = `{params.nextId()}:{offer.kind}:{offer.itemId}`
		table.insert(offers, offer)
	end
	return offers
end

return ShopRules
