--!strict
-- Robux purchases (Paket 16, DESIGN.md sections 12 and 16): game passes VIP and Double Embers, developer products
-- Revive, Rerolls, Ember packs and Server Ember Boost (Config.Store, rules in Util/PurchaseRules). The client only asks
-- (RequestPurchase, UseBonusReroll); this service checks the request, shows Roblox's prompt and grants everything in
-- ProcessReceipt through PlayerDataService.processPurchase, which saves the PurchaseId with the grant before Roblox
-- hears "granted" (exactly once, also across servers). Game passes are checked when a player joins (cached in the
-- profile for when the check fails) and count right away after a purchase in the session.
--
-- What the purchases do: VIP gives a tag over the head and in the chat (player attribute), the VIP lantern and
-- golden trail (since Paket 17 cosmetics, CosmeticService listens to PerksChanged), a free shop reroll per run and +10 % Embers; Double Embers doubles a run's Embers (RunStatsService asks getEmberBonuses).
-- Revive tokens stand a down player up (ReviveService.standUp, once per run, co-op only), reroll tokens reroll the
-- shop for free (ShopService.rerollFree), Ember packs add Embers, the Server Ember Boost gives everyone in this server
-- (and who joins while it runs) +50 % Embers for 30 min; it is kept in each player's profile, so it goes along to the
-- run place. Sends StoreState to its player on every change (StoreController). Debug buttons through AdminService.
--
-- Not part of "Retry wave": a revive or reroll used in the lost wave stays used, bought tokens are never given back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local PurchaseRules = require(Shared.Util.PurchaseRules)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)

local AnalyticsService = require(script.Parent.AnalyticsService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ReviveService = require(script.Parent.ReviveService)
local RunDirector = require(script.Parent.RunDirector)
local ShopService = require(script.Parent.ShopService)

local Store = Config.Store
local Economy = Config.Economy
local Texts = Store.texts
local LOG_PREFIX = "[Lanternfall] "
local DECORATION_NAME = "LanternfallVip"

local MonetizationService = {}

-- (player: Player, key: string): a developer product was granted now (not for a repeated receipt)
MonetizationService.Granted = Signal.new()
-- (player: Player): the player's pass perks were applied again (join, pass check, pass bought, debug); Paket 17
MonetizationService.PerksChanged = Signal.new()

local market: any = nil -- MarketplaceService, nil where it does not exist (tests without the mock)
local ids: any = nil -- Config.Store ids of this experience
local customIds: any = nil -- tests: useIds
local prices: { [string]: number } = {}
local checked: { [Player]: { [string]: boolean } } = {} -- pass ownership from Roblox (missing key = check failed)
local bought: { [Player]: { [string]: boolean } } = {} -- passes bought in this session
local fakePasses: { [Player]: boolean } = {} -- debug: owns every pass
local reviveUsed: { [Player]: boolean } = {}
local vipRerollsUsed: { [Player]: number } = {}
local fakeIndex: { [Player]: number } = {}
local fakeCounter = 0
local serverBoost = { endsAt = 0, by = "" } -- os.time()
local clock: () -> number = os.time

local function now(): number
	return clock()
end

local function present(player: Player): boolean
	return player.Parent == Players
end

local function notify(player: Player, text: string)
	Net.fireClient("Notify", player, text)
end

-- Passes ---------------------------------------------------------------------------------

-- Whether the player owns a pass: bought in this session, as Roblox said on join, else as the profile remembers.
function MonetizationService.owns(player: Player, key: string): boolean
	if fakePasses[player] then
		return true
	end
	if bought[player] and bought[player][key] then
		return true
	end
	local fromRoblox = checked[player] and checked[player][key]
	if fromRoblox ~= nil then
		return fromRoblox
	end
	local data = PlayerDataService.get(player)
	return data ~= nil and data.passCache[key] == true
end

local function ownedPasses(player: Player): { [string]: boolean }
	local owned = {}
	for _, pass in Store.passes do
		owned[pass.key] = MonetizationService.owns(player, pass.key)
	end
	return owned
end

local function vipRerollsLeft(player: Player): number
	if not MonetizationService.owns(player, "VIP") then
		return 0
	end
	return math.max(0, Economy.vipExtraRerolls - (vipRerollsUsed[player] or 0))
end

local function clearDecoration(character: Model)
	local existing = character:FindFirstChild(DECORATION_NAME)
	if existing then
		existing:Destroy()
	end
end

-- VIP tag over the head, seen by everyone (made on the server, so it replicates). The VIP lantern and trail are
-- cosmetics since Paket 17 (CosmeticService).
local function decorate(player: Player, character: Model?)
	if not character then
		return
	end
	local vip = MonetizationService.owns(player, "VIP")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not vip or not root then
		clearDecoration(character)
		return
	end
	if character:FindFirstChild(DECORATION_NAME) then
		return
	end
	local style = Store.vip
	local color = Color3.fromRGB(style.color[1], style.color[2], style.color[3])
	local folder = Instance.new("Folder")
	folder.Name = DECORATION_NAME

	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Adornee = character:FindFirstChild("Head") or root
	tag.Size = UDim2.fromOffset(56, 22)
	tag.StudsOffset = Vector3.new(0, 2.4, 0)
	tag.MaxDistance = 120
	tag.Parent = folder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = style.tag
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = tag

	folder.Parent = character
end

local function applyPerks(player: Player)
	player:SetAttribute(Store.vip.attribute, MonetizationService.owns(player, "VIP"))
	decorate(player, player.Character)
	MonetizationService.PerksChanged:Fire(player)
end

-- Store state ------------------------------------------------------------------------------

local function boostOf(player: Player): { secondsLeft: number, by: string, sentAt: number }?
	local data = PlayerDataService.get(player)
	local left = if data then data.boost.untilTime - now() else 0
	if not data or left <= 0 then
		return nil
	end
	return { secondsLeft = left, by = data.boost.by, sentAt = workspace:GetServerTimeNow() }
end

local function payload(player: Player): Types.StoreState
	local setUp = {}
	for _, key in PurchaseRules.keys() do
		setUp[key] = PurchaseRules.isSetUp(ids, key)
	end
	local data = PlayerDataService.get(player)
	return {
		setUp = setUp,
		prices = table.clone(prices),
		passes = ownedPasses(player),
		tokens = if data
			then { revives = data.tokens.revives, rerolls = data.tokens.rerolls }
			else { revives = 0, rerolls = 0 },
		vipRerolls = vipRerollsLeft(player),
		reviveUsed = reviveUsed[player] == true,
		boost = boostOf(player),
	}
end

local function send(player: Player)
	if present(player) then
		Net.fireClient("StoreState", player, payload(player))
	end
end

local function sendAll()
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

-- Server Ember Boost -------------------------------------------------------------------------

-- Gives the server's boost to a player whose own boost ends sooner (in their profile, so it travels with them).
local function shareBoost(player: Player): boolean
	local data = PlayerDataService.get(player)
	if not data or serverBoost.endsAt <= now() or data.boost.untilTime >= serverBoost.endsAt then
		return false
	end
	data.boost = { untilTime = serverBoost.endsAt, by = serverBoost.by }
	return true
end

-- Revive and rerolls ----------------------------------------------------------------------

-- Uses a revive token if the player has one and may stand up now. True if they stood up.
local function useRevive(player: Player): boolean
	local data = PlayerDataService.get(player)
	if not data or data.tokens.revives <= 0 or reviveUsed[player] or not ReviveService.canStandUp(player) then
		return false
	end
	if not ReviveService.standUp(player) then
		return false
	end
	data.tokens.revives -= 1
	reviveUsed[player] = true
	send(player)
	return true
end

local function useBonusReroll(player: Player)
	if not ShopService.isOpen(player) then
		notify(player, Texts.shopClosed)
		return
	end
	local data = PlayerDataService.get(player)
	local vip = vipRerollsLeft(player) > 0
	if not vip and not (data and data.tokens.rerolls > 0) then
		notify(player, Texts.noRerolls)
		send(player) -- the client may show rerolls that are gone
		return
	end
	if not ShopService.rerollFree(player) then
		return
	end
	if vip then
		vipRerollsUsed[player] = (vipRerollsUsed[player] or 0) + 1
	elseif data then
		data.tokens.rerolls -= 1
	end
	send(player)
end

-- Granting developer products --------------------------------------------------------------

local function thanksText(product: any): string
	local grant = product.grant
	if grant.embers then
		return `{Texts.thanks}+{grant.embers} Embers`
	elseif grant.rerolls then
		return `{Texts.thanks}+{grant.rerolls} shop rerolls`
	elseif grant.serverBoost then
		return `{Texts.thanks}Ember Boost started`
	end
	return `{Texts.thanks}{product.name}`
end

-- After a product was granted now: start or share the boost, use a revive right away, thank the player.
local function afterGrant(player: Player, key: string)
	local product = PurchaseRules.product(key) :: any
	if product.grant.serverBoost then
		for _, other in Players:GetPlayers() do
			shareBoost(other)
		end
		local minutes = math.round(Economy.serverBoost.durationSeconds / 60)
		Net.fireAllClients(
			"Notify",
			`{player.DisplayName} started an Ember Boost: +{math.round(Economy.serverBoost.bonus * 100)}% Embers `
				.. `for everyone for {minutes} min`
		)
		sendAll()
	elseif product.grant.revives then
		if not useRevive(player) then
			notify(player, Texts.reviveSaved)
		end
	end
	if not product.grant.serverBoost then
		notify(player, thanksText(product))
	end
	send(player)
	MonetizationService.Granted:Fire(player, key)
end

-- Grants product `key` for `purchaseId` once (yields until saved). "Granted" or "Retry" (PlayerDataService).
function MonetizationService.grant(player: Player, key: string, purchaseId: string): PlayerDataService.PurchaseResult
	local product = PurchaseRules.product(key)
	assert(product, `Unknown product {key}`)
	local result, applied = PlayerDataService.processPurchase(player, purchaseId, function(data)
		PurchaseRules.grant(data, product.grant)
		if product.grant.serverBoost then
			serverBoost.endsAt =
				PurchaseRules.extendBoost(serverBoost.endsAt, now(), Economy.serverBoost.durationSeconds)
			serverBoost.by = player.DisplayName
			data.boost = { untilTime = math.max(data.boost.untilTime, serverBoost.endsAt), by = serverBoost.by }
		end
	end)
	if applied then
		print(`{LOG_PREFIX}Purchase {key} granted to {player.Name} ({purchaseId})`)
		if product.grant.embers then
			AnalyticsService.embersEarned(player, "Purchase", product.grant.embers, key)
		end
		afterGrant(player, key)
	end
	return result
end

-- MarketplaceService.ProcessReceipt: Roblox calls it for every developer product purchase until it hears
-- PurchaseGranted, also after a crash and in other servers.
local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local key = PurchaseRules.productKey(ids, receipt.ProductId)
	if not key then
		warn(`{LOG_PREFIX}Receipt for unknown product {receipt.ProductId}; left for later`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox asks again when they join a server
	end
	local result = MonetizationService.grant(player, key, tostring(receipt.PurchaseId))
	return if result == "Granted"
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Requests -------------------------------------------------------------------------------

-- RequestPurchase: checks the key and shows Roblox's prompt (or uses a saved revive).
local function requestPurchase(player: Player, key: string)
	if PurchaseRules.pass(key) then
		if MonetizationService.owns(player, key) then
			notify(player, Texts.alreadyOwned)
		elseif not (market and PurchaseRules.isSetUp(ids, key)) then
			notify(player, Texts.notSetUp)
		else
			market:PromptGamePassPurchase(player, PurchaseRules.idOf(ids, key))
		end
		return
	end
	if key == "Revive" then
		if reviveUsed[player] then
			notify(player, Texts.reviveUsed)
			return
		elseif not ReviveService.canStandUp(player) then
			notify(player, Texts.reviveNotNow)
			return
		elseif useRevive(player) then
			return
		end
	end
	if not (market and PurchaseRules.isSetUp(ids, key)) then
		notify(player, Texts.notSetUp)
		return
	end
	market:PromptProductPurchase(player, PurchaseRules.idOf(ids, key))
end

local function onPassPurchased(player: Player, passId: number, purchased: boolean)
	local key = PurchaseRules.passKey(ids, passId)
	if not (purchased and key and present(player)) then
		return
	end
	bought[player] = bought[player] or {}
	bought[player][key] = true
	local data = PlayerDataService.get(player)
	if data then
		data.passCache[key] = true
	end
	print(`{LOG_PREFIX}Game pass {key} bought by {player.Name}`)
	notify(player, `{Texts.thanks}{(PurchaseRules.pass(key) :: any).name} is active`)
	applyPerks(player)
	send(player)
end

-- Writes what Roblox said about the passes into the profile's cache (once both are there).
local function rememberPasses(player: Player)
	local data = PlayerDataService.get(player)
	if data and checked[player] then
		for key, owned in checked[player] do
			data.passCache[key] = owned
		end
	end
end

-- Asks Roblox which passes the player owns (a few tries per pass). A pass whose check fails keeps the profile's value.
local function checkPasses(player: Player)
	local result: { [string]: boolean } = {}
	for _, pass in Store.passes do
		local id = PurchaseRules.idOf(ids, pass.key)
		if id == 0 then
			result[pass.key] = false
		elseif market then
			for attempt = 1, Store.passCheckAttempts do
				local ok, owned = pcall(market.UserOwnsGamePassAsync, market, player.UserId, id)
				if ok then
					result[pass.key] = owned == true
					break
				elseif attempt < Store.passCheckAttempts then
					task.wait(Store.passRetrySeconds)
				else
					warn(`{LOG_PREFIX}Could not check game pass {pass.key} of {player.Name}: {owned}`)
				end
			end
		end
	end
	if not present(player) then
		return
	end
	checked[player] = result
	rememberPasses(player)
	applyPerks(player)
	send(player)
end

local function readPrices()
	if not market then
		return
	end
	for _, key in PurchaseRules.keys() do
		local id = PurchaseRules.idOf(ids, key)
		if id ~= 0 then
			local infoType = if PurchaseRules.pass(key) then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(market.GetProductInfo, market, id, infoType)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" and info.PriceInRobux > 0 then
				prices[key] = info.PriceInRobux
			end
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------------

local function forget(player: Player)
	checked[player] = nil
	bought[player] = nil
	fakePasses[player] = nil
	reviveUsed[player] = nil
	vipRerollsUsed[player] = nil
	fakeIndex[player] = nil
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		decorate(player, character)
	end)
	task.spawn(checkPasses, player)
end

function MonetizationService.init()
	local ok, service = pcall(game.GetService, game, "MarketplaceService")
	market = if ok then service else nil
	ids = customIds or PurchaseRules.resolve(game.GameId, Store.experiences)
	for _, product in Store.products do
		prices[product.key] = product.price
	end
	for _, pass in Store.passes do
		prices[pass.key] = pass.price
	end

	if market then
		market.ProcessReceipt = processReceipt
		market.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(forget)
	PlayerDataService.Loaded:Connect(function(player)
		rememberPasses(player)
		shareBoost(player)
		applyPerks(player) -- the pass cache may know more than a failed check
		send(player)
	end)
	RunDirector.RunStarted:Connect(function(participants: { Player })
		for _, player in participants do
			reviveUsed[player] = nil
			vipRerollsUsed[player] = nil
			send(player)
		end
	end)
	RunDirector.SyncRequested:Connect(send)
	Net.onServer("RequestPurchase", requestPurchase)
	Net.onServer("UseBonusReroll", useBonusReroll)
end

function MonetizationService.start()
	readPrices()
	sendAll()
end

-- Queries and commands ---------------------------------------------------------------------

-- Ember bonuses of the player's passes and Ember Boost for a run that ends now (RunStatsService).
function MonetizationService.getEmberBonuses(player: Player): { PurchaseRules.Bonus }
	local data = PlayerDataService.get(player)
	local boostActive = data ~= nil and data.boost.untilTime > now()
	return PurchaseRules.emberBonuses(ownedPasses(player), boostActive)
end

-- The server's Ember Boost: when it ends (os.time) and who started it (tests).
function MonetizationService.getServerBoost(): (number, string)
	return serverBoost.endsAt, serverBoost.by
end

-- Debug button: the next developer product as if bought, through the real grant (with a made-up PurchaseId).
function MonetizationService.fakePurchase(player: Player): string
	local index = (fakeIndex[player] or 0) % #Store.products + 1
	fakeIndex[player] = index
	fakeCounter += 1
	local product = Store.products[index]
	local purchaseId = `debug-{player.UserId}-{now()}-{fakeCounter}`
	task.spawn(MonetizationService.grant, player, product.key, purchaseId)
	return product.name
end

-- Debug button: owns every pass (true) or what Roblox says (false) for this session; nothing is saved.
function MonetizationService.setFakePasses(player: Player, on: boolean)
	fakePasses[player] = on or nil
	applyPerks(player)
	send(player)
end

function MonetizationService.hasFakePasses(player: Player): boolean
	return fakePasses[player] == true
end

-- Tests: these ids instead of Config.Store's (a Config.Store.Ids table); call before init.
function MonetizationService.useIds(custom: any)
	customIds = custom
end

-- Tests: the clock for boosts (os.time by default).
function MonetizationService.setClock(custom: () -> number)
	clock = custom
end

return MonetizationService
