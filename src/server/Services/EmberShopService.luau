--!strict
-- Ember shop (Paket 17, DESIGN.md section 10): buys locked characters and cosmetics with saved Embers and puts owned
-- cosmetics into their slot. The client only sends intents (BuyWithEmbers, EquipCosmetic); prices and ownership come
-- from Util/EmberShopRules, VIP from MonetizationService. Afterwards PlayerDataService.refresh sends the lobby record
-- (and fires Changed, so the lobby re-checks characters) and CosmeticService rebuilds the look. Called by nobody;
-- AdminService adds Embers for tests (addEmbers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local EmberShopRules = require(Shared.Util.EmberShopRules)
local Net = require(Shared.Net)

local CosmeticService = require(script.Parent.CosmeticService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LOG_PREFIX = "[Lanternfall] "

local Texts = Config.Progress.shopTexts

local EmberShopService = {}

local function notify(player: Player, text: string)
	Net.fireClient("Notify", player, text)
end

local function nameOf(kind: string, id: string): string
	if kind == "Character" then
		return Config.Classes[id].displayName
	end
	return (EmberShopRules.cosmetic(id) :: any).name
end

local function buy(player: Player, kind: string, id: string)
	local data = PlayerDataService.get(player)
	if not data then
		notify(player, Texts.notLoaded)
		return
	end
	local vip = MonetizationService.owns(player, "VIP")
	local price, reason = EmberShopRules.buy(kind, id, data :: any, vip)
	if reason or not price then
		notify(player, Texts[reason or "notForSale"])
		return
	end
	local cosmetic = EmberShopRules.cosmetic(id)
	if kind == "Cosmetic" and cosmetic then
		data.cosmetics.equipped[cosmetic.slot] = id -- wear what you just bought
		CosmeticService.refresh(player)
	end
	print(`{LOG_PREFIX}{player.Name} bought {kind} {id} for {price} Embers`)
	notify(player, Texts.bought .. nameOf(kind, id))
	PlayerDataService.refresh(player)
end

local function equip(player: Player, slot: string, id: string)
	local data = PlayerDataService.get(player)
	if not data then
		notify(player, Texts.notLoaded)
		return
	end
	local vip = MonetizationService.owns(player, "VIP")
	if not EmberShopRules.canEquip(slot, id, data.cosmetics.owned, vip) then
		local cosmetic = EmberShopRules.cosmetic(id)
		notify(player, if cosmetic and cosmetic.vip then Texts.vipOnly else Texts.notForSale)
		return
	end
	data.cosmetics.equipped[slot] = id
	CosmeticService.refresh(player)
	PlayerDataService.refresh(player)
end

function EmberShopService.init()
	Net.onServer("BuyWithEmbers", buy)
	Net.onServer("EquipCosmetic", equip)
end

-- Debug button: adds Embers to the saved Embers (not counted as earned). False if the data is not loaded.
function EmberShopService.addEmbers(player: Player, amount: number): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	data.embers += amount
	PlayerDataService.refresh(player)
	return true
end

return EmberShopService
