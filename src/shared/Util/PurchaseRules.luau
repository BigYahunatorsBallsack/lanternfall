--!strict
-- Pure rules for Robux purchases (Paket 16, DESIGN.md sections 12 and 16): which ids this experience uses, which pass
-- or product an id is, what a product puts into the saved data, which PurchaseIds a profile remembers, when an Ember
-- Boost ends and the Ember bonuses of passes and boosts. Used by MonetizationService, ProfileRecords (via
-- Util/ProgressRules) and StoreController; unit-tested in tests/PurchaseRules.spec.luau.

local Config = require(script.Parent.Parent.Config)
local StoreConfig = require(script.Parent.Parent.Config.Store)

-- An Ember bonus on top of a run's Embers: `share` of them (0.5 = +50 %), shown as its own results line.
export type Bonus = { label: string, share: number }

export type Tokens = { revives: number, rerolls: number }

local Economy = Config.Economy

local PurchaseRules = {}

-- The ids of the experience `gameId`: the entry with that gameId, else the first entry with gameId 0, else nil.
function PurchaseRules.resolve(gameId: number?, experiences: { StoreConfig.Ids }): StoreConfig.Ids?
	if gameId and gameId ~= 0 then
		for _, experience in experiences do
			if experience.gameId == gameId then
				return experience
			end
		end
	end
	for _, experience in experiences do
		if experience.gameId == 0 then
			return experience
		end
	end
	return nil
end

function PurchaseRules.product(key: string): StoreConfig.Product?
	for _, product in Config.Store.products do
		if product.key == key then
			return product
		end
	end
	return nil
end

function PurchaseRules.pass(key: string): StoreConfig.Pass?
	for _, pass in Config.Store.passes do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

-- Every pass and product key, passes first (the RequestPurchase remote accepts exactly these).
function PurchaseRules.keys(): { string }
	local keys = {}
	for _, pass in Config.Store.passes do
		table.insert(keys, pass.key)
	end
	for _, product in Config.Store.products do
		table.insert(keys, product.key)
	end
	return keys
end

-- The Creator Hub id of a pass or product key, 0 if it is not set up (or no ids are known).
function PurchaseRules.idOf(ids: StoreConfig.Ids?, key: string): number
	if not ids then
		return 0
	end
	return ids.passes[key] or ids.products[key] or 0
end

function PurchaseRules.isSetUp(ids: StoreConfig.Ids?, key: string): boolean
	return PurchaseRules.idOf(ids, key) ~= 0
end

-- The product key of a developer product id (ProcessReceipt), nil if this experience does not sell it.
function PurchaseRules.productKey(ids: StoreConfig.Ids?, productId: number): string?
	if not ids or productId == 0 then
		return nil
	end
	for key, id in ids.products do
		if id == productId then
			return key
		end
	end
	return nil
end

-- The pass key of a game pass id, nil if this experience does not sell it.
function PurchaseRules.passKey(ids: StoreConfig.Ids?, passId: number): string?
	if not ids or passId == 0 then
		return nil
	end
	for key, id in ids.passes do
		if id == passId then
			return key
		end
	end
	return nil
end

function PurchaseRules.knows(receipts: { string }, purchaseId: string): boolean
	return table.find(receipts, purchaseId) ~= nil
end

-- Remembers a granted PurchaseId (in place), dropping the oldest beyond `memory`. False if it was already known.
function PurchaseRules.remember(receipts: { string }, purchaseId: string, memory: number): boolean
	if PurchaseRules.knows(receipts, purchaseId) then
		return false
	end
	table.insert(receipts, purchaseId)
	while #receipts > memory do
		table.remove(receipts, 1)
	end
	return true
end

-- Puts what a product gives into saved data (in place): Embers (also counted as bought) and tokens. The Server Ember
-- Boost is not in here: it needs the server's boost (MonetizationService). Counts the purchase.
function PurchaseRules.grant(data: any, grant: StoreConfig.Grant)
	local stats = data.stats
	local tokens = data.tokens
	if grant.embers then
		data.embers += grant.embers
		stats.embersBought += grant.embers
	end
	if grant.revives then
		tokens.revives += grant.revives
	end
	if grant.rerolls then
		tokens.rerolls += grant.rerolls
	end
	stats.purchases += 1
end

-- When a boost ends after one more purchase: a running boost gets longer, otherwise it starts now.
function PurchaseRules.extendBoost(currentEnd: number, now: number, durationSeconds: number): number
	return math.max(currentEnd, now) + durationSeconds
end

-- The Ember bonuses of a player's passes and an active Ember Boost, in results order. They add up (all three = +160 %)
-- and are counted from the run's Embers after the danger and party bonuses (Util/ProgressRules.runEmbers).
function PurchaseRules.emberBonuses(passes: { [string]: boolean }, boostActive: boolean): { Bonus }
	local bonuses: { Bonus } = {}
	if passes.DoubleEmbers then
		table.insert(bonuses, { label = "Double Embers", share = Economy.bonuses.doubleEmbersMultiplier - 1 })
	end
	if passes.VIP then
		table.insert(bonuses, { label = "VIP", share = Economy.bonuses.vip })
	end
	if boostActive then
		table.insert(bonuses, { label = "Ember Boost", share = Economy.serverBoost.bonus })
	end
	return bonuses
end

-- Free shop rerolls a player can still use: the VIP reroll of this run first, then tokens.
function PurchaseRules.bonusRerolls(vipLeft: number, tokens: Tokens): number
	return math.max(0, vipLeft) + math.max(0, tokens.rerolls)
end

return PurchaseRules
