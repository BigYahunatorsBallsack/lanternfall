--!strict
-- Ember shop rules as pure functions (Paket 17): what a locked character or a cosmetic costs, whether a player owns
-- it or can buy it, buying it (in place on the saved data) and which cosmetic a slot shows. Shared, so the server
-- (EmberShopService, CosmeticService) and the lobby window (EmberShopController) use the same rules. Tested in
-- tests/EmberShopRules.spec.luau.

local Config = require(script.Parent.Parent.Config)
local CosmeticsConfig = require(script.Parent.Parent.Config.Cosmetics)
local ProgressRules = require(script.Parent.ProgressRules)

local Cosmetics = Config.Cosmetics

export type Kind = "Character" | "Cosmetic"
export type Reason = "notForSale" | "alreadyOwned" | "notEnough" | "vipOnly" | "rewardOnly"

-- What the rules read and change of the saved data (ProfileTemplate.Data has more).
export type Wallet = {
	embers: number,
	achievements: { [string]: boolean },
	classes: { string }, -- characters bought (and the old default list)
	cosmetics: { owned: { string }, equipped: { [string]: string } },
}

local EmberShopRules = {}

EmberShopRules.KINDS = table.freeze({ "Character", "Cosmetic" }) :: { string }

local byId: { [string]: CosmeticsConfig.Cosmetic } = {}
local bySlot: { [string]: { CosmeticsConfig.Cosmetic } } = { Lantern = Cosmetics.lanterns, Trail = Cosmetics.trails }
local ids: { string } = {}
for _, list in bySlot do
	for _, entry in list do
		byId[entry.id] = entry
		table.insert(ids, entry.id)
	end
end
table.sort(ids)

function EmberShopRules.cosmetic(id: string): CosmeticsConfig.Cosmetic?
	return byId[id]
end

-- Every cosmetic of a slot in Config order ({} for an unknown slot).
function EmberShopRules.list(slot: string): { CosmeticsConfig.Cosmetic }
	return bySlot[slot] or {}
end

-- Every cosmetic id, sorted (remote validation).
function EmberShopRules.ids(): { string }
	return ids
end

-- Embers a locked character costs; nil if it can not be bought.
function EmberShopRules.characterPrice(classId: string): number?
	return Config.Progress.characterPrices[classId]
end

function EmberShopRules.ownsCosmetic(id: string, owned: { string }, vip: boolean): boolean
	local entry = byId[id]
	if not entry then
		return false
	elseif entry.vip then
		return vip
	elseif entry.reward then -- Paket 18: earned, e.g. on day 7 of the login streak
		return table.find(owned, id) ~= nil
	end
	return entry.price <= 0 or table.find(owned, id) ~= nil
end

-- Whether a character is unlocked (achievement done or bought).
function EmberShopRules.ownsCharacter(classId: string, wallet: Wallet): boolean
	return ProgressRules.isUnlocked("characters", classId, wallet.achievements, wallet.classes)
end

-- Its price in Embers, or nil and why it can not be bought (notForSale, alreadyOwned, vipOnly, rewardOnly, notEnough;
-- with notEnough the price is returned too).
function EmberShopRules.price(kind: string, id: string, wallet: Wallet, vip: boolean): (number?, Reason?)
	local price: number?
	if kind == "Character" then
		price = EmberShopRules.characterPrice(id)
		if not (price and Config.Classes[id] and Config.Classes[id].available) then
			return nil, "notForSale"
		elseif EmberShopRules.ownsCharacter(id, wallet) then
			return nil, "alreadyOwned"
		end
	elseif kind == "Cosmetic" then
		local entry = byId[id]
		if not entry then
			return nil, "notForSale"
		elseif EmberShopRules.ownsCosmetic(id, wallet.cosmetics.owned, vip) then
			return nil, "alreadyOwned"
		elseif entry.vip then
			return nil, "vipOnly"
		elseif entry.reward then
			return nil, "rewardOnly"
		end
		price = entry.price
	else
		return nil, "notForSale"
	end
	local cost = price :: number
	if wallet.embers < cost then
		return cost, "notEnough"
	end
	return cost, nil
end

-- Buys it (in place): takes the Embers and adds it to the owned list. Returns the price paid, or nil and the reason.
function EmberShopRules.buy(kind: string, id: string, wallet: Wallet, vip: boolean): (number?, Reason?)
	local price, reason = EmberShopRules.price(kind, id, wallet, vip)
	if reason or not price then
		return nil, reason
	end
	wallet.embers -= price
	if kind == "Character" then
		table.insert(wallet.classes, id)
	else
		table.insert(wallet.cosmetics.owned, id)
	end
	return price, nil
end

-- Whether the player may put this into the slot (Config.Cosmetics.none takes it off).
function EmberShopRules.canEquip(slot: string, id: string, owned: { string }, vip: boolean): boolean
	if not bySlot[slot] then
		return false
	elseif id == Cosmetics.none then
		return true
	end
	local entry = byId[id]
	return entry ~= nil and entry.slot == slot and EmberShopRules.ownsCosmetic(id, owned, vip)
end

-- The cosmetic id a slot shows, or nil for nothing: the picked one while it is still owned (a VIP entry after the
-- pass is gone falls back), else the slot's default (VIP players get their VIP entry).
function EmberShopRules.shown(slot: string, equipped: { [string]: string }, owned: { string }, vip: boolean): string?
	local picked = equipped[slot]
	if picked == Cosmetics.none then
		return nil
	elseif picked and EmberShopRules.canEquip(slot, picked, owned, vip) then
		return picked
	end
	local default = if vip then Cosmetics.vipDefaults[slot] or Cosmetics.defaults[slot] else Cosmetics.defaults[slot]
	return if default and EmberShopRules.ownsCosmetic(default, owned, vip) then default else nil
end

return EmberShopRules
