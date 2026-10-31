-- End-to-end test of Robux purchases (Paket 16): game passes checked on join and bought in the session (VIP tag,
-- trail, attribute), the lobby store window, prompts only for set-up products, ProcessReceipt granting exactly once
-- and only after a save, the Server Ember Boost for everyone in the server, a bought revive, bonus shop rerolls, Ember
-- bonuses on the results and the debug buttons. MarketplaceService is simulated (tests/helpers/RobloxMock); real
-- prompts and test purchases need Studio with the Creator Hub ids in Config/Store.luau.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local MonetizationService = require(Services.MonetizationService)
local PlayerDataService = require(Services.PlayerDataService)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)

local IDS = {
	name = "Spec",
	gameId = 0,
	passes = { VIP = 101, DoubleEmbers = 102 },
	products = { Revive = 201, Rerolls = 202, Embers1 = 203, Embers2 = 204, Embers3 = 0, ServerBoost = 206 },
}
local Granted = Enum.ProductPurchaseDecision.PurchaseGranted
local NotYet = Enum.ProductPurchaseDecision.NotProcessedYet
local Economy = Config.Economy

local store = MemoryStore.new(ProfileTemplate.new())
PlayerDataService.useStore(store)
MonetizationService.useIds(IDS)
local fakeNow = 1000000
MonetizationService.setClock(function()
	return fakeNow
end)
world.ownedPasses["1:101"] = true -- the owner has VIP
world.ownedPasses["2:102"] = true -- the peer has Double Embers
world.robuxPrices[203] = 80

runScript(ServerScriptService.Server, "init.server.luau")
local RunDirector = require(Services.RunDirector)
local ShopService = require(Services.ShopService)
local SpawnDirector = require(Services.SpawnDirector)
local WeaponService = require(Services.WeaponService)

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local StoreController = require(Client.Controllers.StoreController)

local function keyOf(userId)
	return Config.Save.keyPrefix .. tostring(userId)
end

local function toasts(): { string }
	local texts = {}
	for _, object in world.gui("Notify"):GetDescendants() do
		if object.ClassName == "TextLabel" then
			table.insert(texts, object.Text)
		end
	end
	return texts
end

local function hasToast(prefix: string): boolean
	for _, text in toasts() do
		if string.sub(text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function contains(text: string, part: string): boolean
	return string.find(text, part, 1, true) ~= nil
end

local function lastPrompt()
	return world.prompts[#world.prompts]
end

local function startRun()
	world.fireServerAs(me, "SetReady", true)
	world.fireServerAs(peer, "SetReady", true)
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	expect(RunDirector.getPhase()).toBe("Running")
	SpawnDirector.setPaused(true)
	WeaponService.setPaused(true)
	RunDirector.setHoldWaves(true)
end

describe("store", function()
	it("checks game passes on join and gives VIP its tag and trail", function()
		expect(me:GetAttribute(Config.Store.vip.attribute)).toBe(true)
		expect(peer:GetAttribute(Config.Store.vip.attribute)).toBe(false)
		local decoration = me.Character:FindFirstChild("LanternfallVip")
		expect(decoration ~= nil).toBe(true)
		expect(decoration:FindFirstChild("VipTag") ~= nil).toBe(true)
		expect(decoration:FindFirstChild("VipTrail") ~= nil).toBe(true)
		expect(peer.Character:FindFirstChild("LanternfallVip")).toBe(nil)
		expect(MonetizationService.owns(peer, "DoubleEmbers")).toBe(true)
		expect(PlayerDataService.get(me).passCache.VIP).toBe(true)
		local state = StoreController.get()
		expect(state.passes.VIP).toBe(true)
		expect(state.passes.DoubleEmbers).toBe(false)
		expect(state.vipRerolls).toBe(Economy.vipExtraRerolls)
	end)

	it("lists passes and products with their price in the lobby store", function()
		world.click(world.gui("Lobby", "OpenStore"))
		expect(world.gui("Lobby", "Store").Visible).toBe(true)
		expect(contains(StoreController.getRow("VIP").Text, "VIP · OWNED")).toBe(true)
		expect(contains(StoreController.getRow("DoubleEmbers").Text, `R$ {Economy.prices.doubleEmbers}`)).toBe(true)
		expect(contains(StoreController.getRow("Embers1").Text, "R$ 80")).toBe(true) -- the price Roblox reports
		expect(contains(StoreController.getRow("Embers3").Text, "not set up yet")).toBe(true)
		expect(StoreController.getRow("Revive")).toBe(nil) -- bought where it is used
		expect(world.gui("Lobby", "Tokens").Text).toBe("Saved: 0 revives · 0 shop rerolls")
		world.click(world.gui("Lobby", "CloseStore"))
		expect(world.gui("Lobby", "Store").Visible).toBe(false)
	end)

	it("prompts only for products and passes that are set up and not owned", function()
		local before = #world.prompts
		world.click(StoreController.getRow("Embers3"))
		world.fireServerAs(me, "RequestPurchase", "Embers3")
		world.advance(0.1)
		expect(#world.prompts).toBe(before)
		expect(hasToast(Config.Store.texts.notSetUp)).toBe(true)
		world.fireServerAs(me, "RequestPurchase", "VIP")
		world.advance(0.1)
		expect(#world.prompts).toBe(before)
		expect(hasToast(Config.Store.texts.alreadyOwned)).toBe(true)
		world.advance(1)
		world.click(StoreController.getRow("Embers1"))
		world.advance(0.1)
		expect(lastPrompt().kind).toBe("Product")
		expect(lastPrompt().id).toBe(203)
		expect(lastPrompt().player).toBe(me)
		world.advance(1)
		world.fireServerAs(peer, "RequestPurchase", "VIP")
		world.advance(0.1)
		expect(lastPrompt().kind).toBe("Pass")
		expect(lastPrompt().id).toBe(101)
		-- a revive only while down in a running co-op wave
		world.advance(1)
		local count = #world.prompts
		world.fireServerAs(me, "RequestPurchase", "Revive")
		world.advance(0.1)
		expect(#world.prompts).toBe(count)
		expect(hasToast(Config.Store.texts.reviveNotNow)).toBe(true)
	end)

	it("grants a developer product once, and only after it is saved", function()
		local data = PlayerDataService.get(me)
		local embers = data.embers
		local outcome = world.buyProduct(me, 203, "purchase-1")
		world.advance(0.2)
		expect(outcome.decision).toBe(Granted)
		expect(data.embers).toBe(embers + Economy.emberPacks[1].embers)
		expect(data.stats.embersBought).toBe(Economy.emberPacks[1].embers)
		local saved = store:peek(keyOf(1))
		expect(saved.embers).toBe(data.embers)
		expect(table.find(saved.receipts, "purchase-1") ~= nil).toBe(true)
		expect(hasToast(`Thank you! +{Economy.emberPacks[1].embers} Embers`)).toBe(true)
		expect(contains(world.gui("Lobby", "Record").Text, `{data.embers} Embers`)).toBe(true)
		-- Roblox asks again (e.g. after a timeout): granted, but nothing twice
		local again = world.buyProduct(me, 203, "purchase-1")
		world.advance(0.2)
		expect(again.decision).toBe(Granted)
		expect(data.embers).toBe(embers + Economy.emberPacks[1].embers)
	end)

	it("says not yet while the save fails and grants nothing twice on the retry", function()
		local data = PlayerDataService.get(me)
		store:setFailing(true)
		local outcome = world.buyProduct(me, 202, "purchase-2")
		world.advance(1)
		expect(outcome.decision).toBe(nil) -- still waiting for the save
		expect(data.tokens.rerolls).toBe(Economy.rerollPackAmount)
		world.advance(Config.Store.receiptWaitSeconds)
		expect(outcome.decision).toBe(NotYet)
		store:setFailing(false)
		local retry = world.buyProduct(me, 202, "purchase-2")
		world.advance(0.2)
		expect(retry.decision).toBe(Granted)
		expect(data.tokens.rerolls).toBe(Economy.rerollPackAmount)
		expect(table.find(store:peek(keyOf(1)).receipts, "purchase-2") ~= nil).toBe(true)
		expect(world.gui("Lobby", "Tokens").Text).toBe(`Saved: 0 revives · {Economy.rerollPackAmount} shop rerolls`)
	end)

	it("leaves receipts of absent players and unknown products for later", function()
		local absent = world.buyProduct({ UserId = 999 }, 203, "purchase-3")
		local unknown = world.buyProduct(me, 999, "purchase-4")
		world.advance(0.2)
		expect(absent.decision).toBe(NotYet)
		expect(unknown.decision).toBe(NotYet)
	end)

	it("counts a game pass bought in the session right away", function()
		world.market.PromptGamePassPurchaseFinished:Fire(peer, 101, true)
		world.advance(0.2)
		expect(MonetizationService.owns(peer, "VIP")).toBe(true)
		expect(peer:GetAttribute(Config.Store.vip.attribute)).toBe(true)
		expect(peer.Character:FindFirstChild("LanternfallVip") ~= nil).toBe(true)
		expect(PlayerDataService.get(peer).passCache.VIP).toBe(true)
		-- a cancelled prompt changes nothing
		world.market.PromptGamePassPurchaseFinished:Fire(me, 102, false)
		world.advance(0.2)
		expect(MonetizationService.owns(me, "DoubleEmbers")).toBe(false)
	end)

	it("gives the Server Ember Boost to everyone here and to who joins while it runs", function()
		local outcome = world.buyProduct(peer, 206, "purchase-5")
		world.advance(0.2)
		expect(outcome.decision).toBe(Granted)
		local duration = Economy.serverBoost.durationSeconds
		expect(PlayerDataService.get(peer).boost.untilTime).toBe(fakeNow + duration)
		expect(PlayerDataService.get(me).boost.untilTime).toBe(fakeNow + duration)
		expect(PlayerDataService.get(me).boost.by).toBe("Peer")
		expect(hasToast("Peer started an Ember Boost")).toBe(true)
		local label = world.gui("Lobby", "EmberBoost")
		expect(label.Visible).toBe(true)
		expect(contains(label.Text, `{math.round(duration / 60)} min left · by Peer`)).toBe(true)
		local third = world.addPlayer("Third", 3, false)
		world.advance(0.5)
		expect(PlayerDataService.get(third).boost.untilTime).toBe(fakeNow + duration)
		world.removePlayer(third)
		-- a second boost makes it longer
		world.buyProduct(me, 206, "purchase-6")
		world.advance(0.2)
		expect((MonetizationService.getServerBoost())).toBe(fakeNow + 2 * duration)
		expect(PlayerDataService.get(peer).boost.untilTime).toBe(fakeNow + 2 * duration)
	end)

	it("stands a down player up with a bought revive, once per run", function()
		startRun()
		RunDirector.setParticipantState(me, "Down")
		world.advance(0.3)
		local screen = world.gui("StoreRevive")
		expect(screen.Enabled).toBe(true)
		local button = world.gui("StoreRevive", "BuyRevive")
		expect(button.Text).toBe(`REVIVE NOW · R$ {Economy.prices.revive}`)
		world.click(button)
		world.advance(0.1)
		expect(lastPrompt().id).toBe(201)
		world.buyProduct(me, 201, "purchase-7")
		world.advance(0.3)
		expect(RunDirector.getParticipantState(me)).toBe("Alive")
		expect(PlayerDataService.get(me).tokens.revives).toBe(0)
		expect(StoreController.get().reviveUsed).toBe(true)
		expect(screen.Enabled).toBe(false)
		-- once per run
		world.advance(1)
		RunDirector.setParticipantState(me, "Down")
		world.advance(0.3)
		expect(screen.Enabled).toBe(false)
		local count = #world.prompts
		world.fireServerAs(me, "RequestPurchase", "Revive")
		world.advance(0.1)
		expect(#world.prompts).toBe(count)
		expect(hasToast(Config.Store.texts.reviveUsed)).toBe(true)
		RunDirector.setParticipantState(me, "Alive")
		world.advance(0.3)
	end)

	it("rerolls the shop for free with the VIP reroll first, then tokens", function()
		local data = PlayerDataService.get(me)
		world.advance(1)
		world.fireServerAs(me, "UseBonusReroll")
		world.advance(0.1)
		expect(hasToast(Config.Store.texts.shopClosed)).toBe(true)
		world.fireServerAs(me, "DebugCommand", "SkipWave")
		world.advance(2)
		expect(ShopService.isOpen(me)).toBe(true)
		local bonus = world.gui("Shop", "BonusReroll")
		expect(bonus.Text).toBe(`Bonus reroll ({Economy.vipExtraRerolls + Economy.rerollPackAmount})`)
		local shards = ShopService.getShards(me)
		local firstId = ShopService.getOffers(me)[1].id
		world.fireServerAs(me, "UseBonusReroll")
		world.advance(0.2)
		expect(ShopService.getOffers(me)[1].id ~= firstId).toBe(true)
		expect(ShopService.getShards(me)).toBe(shards)
		expect(StoreController.get().vipRerolls).toBe(0)
		expect(data.tokens.rerolls).toBe(Economy.rerollPackAmount)
		world.fireServerAs(me, "UseBonusReroll")
		world.advance(0.2)
		expect(data.tokens.rerolls).toBe(Economy.rerollPackAmount - 1)
		expect(bonus.Text).toBe(`Bonus reroll ({Economy.rerollPackAmount - 1})`)
		-- without bonus rerolls the button sells the pack
		data.tokens.rerolls = 0
		PlayerDataService.sync(me)
		world.fireServerAs(me, "UseBonusReroll")
		world.advance(0.2)
		expect(hasToast(Config.Store.texts.noRerolls)).toBe(true)
		expect(bonus.Text).toBe(`+{Economy.rerollPackAmount} rerolls · R$ {Economy.prices.rerollPack}`)
	end)

	it("adds pass and boost bonuses to a run's Embers", function()
		world.fireServerAs(me, "SetShopReady", true)
		world.fireServerAs(peer, "SetShopReady", true)
		world.advance(3)
		expect(RunDirector.getPhase()).toBe("Running")
		expect(RunDirector.skipTo(130)).toBe(true) -- two minutes of Embers to add bonuses to
		world.advance(0.2)
		RunDirector.endRun("Victory")
		world.advance(0.5)
		local text = world.gui("Results", "Rewards").Text
		expect(contains(text, "VIP (+10%)")).toBe(true)
		expect(contains(text, "Ember Boost (+50%)")).toBe(true)
		expect(contains(text, "Double Embers")).toBe(false) -- the owner does not have it
		world.advance(Config.Run.flow.resultsSeconds + 1)
	end)

	it("uses a saved revive without a prompt in the next run", function()
		PlayerDataService.get(me).tokens.revives = 1
		startRun()
		expect(StoreController.get().reviveUsed).toBe(false)
		RunDirector.setParticipantState(me, "Down")
		world.advance(0.3)
		expect(world.gui("StoreRevive", "BuyRevive").Text).toBe("USE REVIVE (1)")
		local count = #world.prompts
		world.click(world.gui("StoreRevive", "BuyRevive"))
		world.advance(0.3)
		expect(#world.prompts).toBe(count)
		expect(RunDirector.getParticipantState(me)).toBe("Alive")
		expect(PlayerDataService.get(me).tokens.revives).toBe(0)
		RunDirector.endRun("Abandoned")
		world.advance(Config.Run.flow.resultsSeconds + 1)
	end)

	it("fakes purchases and passes with the debug buttons", function()
		local data = PlayerDataService.get(peer)
		local revives = data.tokens.revives
		world.fireServerAs(peer, "DebugCommand", "FakePurchase") -- first product: Revive (kept, nobody is down)
		world.advance(0.3)
		expect(data.tokens.revives).toBe(revives + 1)
		local embers = data.embers
		world.fireServerAs(peer, "DebugCommand", "FakePurchase") -- Rerolls
		world.advance(1.1)
		world.fireServerAs(peer, "DebugCommand", "FakePurchase") -- Embers1
		world.advance(0.3)
		expect(data.embers).toBe(embers + Economy.emberPacks[1].embers)
		world.fireServerAs(me, "DebugCommand", "ToggleFakePasses")
		world.advance(0.3)
		expect(MonetizationService.owns(me, "DoubleEmbers")).toBe(true)
		world.advance(1)
		world.fireServerAs(me, "DebugCommand", "ToggleFakePasses")
		world.advance(0.3)
		expect(MonetizationService.owns(me, "DoubleEmbers")).toBe(false)
		expect(MonetizationService.owns(me, "VIP")).toBe(true)
	end)

	it("finished without any runtime error", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n\n"))
		end
	end)
end)
