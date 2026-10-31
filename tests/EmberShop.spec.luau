-- End-to-end test of the Ember shop (Paket 17): default and VIP cosmetics on the characters, the lobby window with its
-- tabs, buying a locked character and cosmetics with Embers (second press confirms), wearing and taking off cosmetics,
-- VIP-only cosmetics, refused intents, cosmetics after a respawn and the debug button. MarketplaceService is simulated
-- (tests/helpers/RobloxMock).

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local MemoryStore = require(Services.PlayerDataService.MemoryStore)
local MonetizationService = require(Services.MonetizationService)
local PlayerDataService = require(Services.PlayerDataService)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)

local Cosmetics = Config.Cosmetics
local Texts = Config.Progress.shopTexts
local MANY_HANDS = Config.Progress.characterPrices.ManyHands

PlayerDataService.useStore(MemoryStore.new(ProfileTemplate.new()))
MonetizationService.useIds({
	name = "Spec",
	gameId = 0,
	passes = { VIP = 101, DoubleEmbers = 102 },
	products = { Revive = 0, Rerolls = 0, Embers1 = 0, Embers2 = 0, Embers3 = 0, ServerBoost = 0 },
})
world.ownedPasses["2:101"] = true -- the peer has VIP

runScript(ServerScriptService.Server, "init.server.luau")

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local EmberShopController = require(Client.Controllers.EmberShopController)
local RunStateController = require(Client.Controllers.RunStateController)

local function hasToast(prefix: string): boolean
	for _, object in world.gui("Notify"):GetDescendants() do
		if object.ClassName == "TextLabel" and string.sub(object.Text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function contains(text: string, part: string): boolean
	return string.find(text, part, 1, true) ~= nil
end

local function cosmetics(player)
	return player.Character:FindFirstChild("LanternfallCosmetics")
end

local function row(id: string): TextButton
	local button = EmberShopController.getRow(id)
	assert(button, `no row {id}`)
	return button
end

describe("Ember shop", function()
	it("gives everyone the brass lantern and VIP players the VIP lantern and trail", function()
		local mine = cosmetics(me)
		expect(mine:GetAttribute("Lantern")).toBe(Cosmetics.defaults.Lantern)
		expect(mine:GetAttribute("Trail")).toBe("")
		local lantern = mine:FindFirstChild("Lantern")
		expect(lantern ~= nil).toBe(true)
		local core = lantern:FindFirstChild("Core")
		expect(core:FindFirstChild("PointLight") ~= nil).toBe(true)
		expect(core.CanCollide).toBe(false)
		expect(core.Massless).toBe(true)
		expect(core:FindFirstChildOfClass("WeldConstraint").Part0).toBe(me.Character.HumanoidRootPart)
		expect(mine:FindFirstChild("Trail")).toBe(nil)

		local theirs = cosmetics(peer)
		expect(theirs:GetAttribute("Lantern")).toBe(Cosmetics.vipDefaults.Lantern)
		expect(theirs:GetAttribute("Trail")).toBe(Cosmetics.vipDefaults.Trail)
		expect(theirs:FindFirstChild("Trail").ClassName).toBe("Trail")
		-- the VIP tag stays with the pass, the trail is a cosmetic now
		local vip = peer.Character:FindFirstChild("LanternfallVip")
		expect(vip:FindFirstChild("VipTag") ~= nil).toBe(true)
		expect(vip:FindFirstChild("VipTrail")).toBe(nil)
	end)

	it("shows the price on locked characters and opens the window next to the store", function()
		expect(contains(world.gui("Lobby", "ManyHands").Text, `or {MANY_HANDS} Embers`)).toBe(true)
		world.click(world.gui("Lobby", "OpenStore"))
		world.click(world.gui("Lobby", "OpenEmberShop"))
		expect(world.gui("Lobby", "EmberShop").Visible).toBe(true)
		expect(world.gui("Lobby", "Store").Visible).toBe(false) -- one window at a time
		expect(world.gui("Lobby", "EmberShopEmbers").Text).toBe("You have 0 Embers")
		local text = row("ManyHands").Text
		expect(contains(text, `Many Hands · {MANY_HANDS} Embers · you need {MANY_HANDS} more`)).toBe(true)
		expect(contains(text, "or free: Reach wave 10")).toBe(true)
	end)

	it("refuses a buy without enough Embers", function()
		world.fireServerAs(me, "BuyWithEmbers", "Character", "ManyHands")
		world.advance(0.3)
		expect(hasToast(Texts.notEnough)).toBe(true)
		expect(table.find(PlayerDataService.get(me).classes, "ManyHands")).toBe(nil)
	end)

	it("buys a locked character after a second press", function()
		world.fireServerAs(me, "DebugCommand", "AddEmbers")
		world.advance(0.3)
		local data = PlayerDataService.get(me)
		expect(data.embers).toBe(Config.Admin.addEmbers)
		expect(world.gui("Lobby", "EmberShopEmbers").Text).toBe(`You have {Config.Admin.addEmbers} Embers`)
		world.click(row("ManyHands"))
		expect(contains(row("ManyHands").Text, "Press again to buy")).toBe(true)
		world.advance(0.1)
		expect(data.embers).toBe(Config.Admin.addEmbers) -- nothing bought yet
		world.click(row("ManyHands"))
		world.advance(0.3)
		expect(data.embers).toBe(Config.Admin.addEmbers - MANY_HANDS)
		expect(hasToast(Texts.bought .. "Many Hands")).toBe(true)
		expect(contains(row("ManyHands").Text, "Many Hands · UNLOCKED")).toBe(true)
		expect(world.gui("Lobby", "ManyHands").Text).toBe("Many Hands")
		world.click(world.gui("Lobby", "ManyHands"))
		world.advance(0.3)
		expect(RunStateController.getLocalPlayer().classId).toBe("ManyHands")
	end)

	it("forgets an unconfirmed buy after a few seconds", function()
		world.fireServerAs(me, "DebugCommand", "AddEmbers")
		world.advance(0.3)
		EmberShopController.showTab("LANTERNS")
		local jade = Cosmetics.lanterns[2]
		world.click(row(jade.id))
		expect(contains(row(jade.id).Text, "Press again")).toBe(true)
		world.advance(3.5)
		expect(contains(row(jade.id).Text, `{jade.price} Embers · press to buy`)).toBe(true)
	end)

	it("buys a lantern, wears it at once and switches back", function()
		local data = PlayerDataService.get(me)
		local jade = Cosmetics.lanterns[2]
		local before = data.embers
		world.click(row(jade.id))
		world.click(row(jade.id))
		world.advance(0.3)
		expect(data.embers).toBe(before - jade.price)
		expect(table.find(data.cosmetics.owned, jade.id) ~= nil).toBe(true)
		expect(data.cosmetics.equipped.Lantern).toBe(jade.id)
		expect(cosmetics(me):GetAttribute("Lantern")).toBe(jade.id)
		expect(contains(row(jade.id).Text, "WEARING")).toBe(true)

		world.click(row(Cosmetics.defaults.Lantern))
		world.advance(0.3)
		expect(cosmetics(me):GetAttribute("Lantern")).toBe(Cosmetics.defaults.Lantern)
		expect(contains(row(jade.id).Text, "OWNED · press to wear")).toBe(true)

		world.click(row(Cosmetics.none))
		world.advance(0.3)
		expect(cosmetics(me):GetAttribute("Lantern")).toBe("")
		expect(cosmetics(me):FindFirstChild("Lantern")).toBe(nil)
		expect(contains(row(Cosmetics.none).Text, "No lantern · WEARING")).toBe(true)
	end)

	it("buys a trail", function()
		world.fireServerAs(me, "DebugCommand", "AddEmbers")
		world.advance(0.3)
		EmberShopController.showTab("TRAILS")
		local trail = Cosmetics.trails[1]
		world.click(row(trail.id))
		world.click(row(trail.id))
		world.advance(0.3)
		expect(cosmetics(me):GetAttribute("Trail")).toBe(trail.id)
		expect(cosmetics(me):FindFirstChild("Trail").ClassName).toBe("Trail")
		expect(me.Character.HumanoidRootPart:FindFirstChild("CosmeticTrailTop") ~= nil).toBe(true)
	end)

	it("keeps VIP cosmetics for the VIP pass", function()
		local vipTrail = Cosmetics.vipDefaults.Trail
		expect(contains(row(vipTrail).Text, "comes with the VIP pass")).toBe(true)
		local before = #world.prompts
		world.click(row(vipTrail))
		world.advance(0.3)
		expect(#world.prompts).toBe(before + 1)
		expect(world.prompts[#world.prompts].kind).toBe("Pass")
		world.advance(1)
		world.fireServerAs(me, "BuyWithEmbers", "Cosmetic", vipTrail)
		world.advance(0.3)
		expect(hasToast(Texts.vipOnly)).toBe(true)
		world.advance(1)
		world.fireServerAs(me, "EquipCosmetic", "Trail", vipTrail)
		world.advance(0.3)
		expect(cosmetics(me):GetAttribute("Trail")).toBe(Cosmetics.trails[1].id)

		world.fireServerAs(me, "DebugCommand", "ToggleFakePasses")
		world.advance(0.3)
		expect(contains(row(vipTrail).Text, "VIP · press to wear")).toBe(true)
		world.click(row(vipTrail))
		world.advance(0.3)
		expect(cosmetics(me):GetAttribute("Trail")).toBe(vipTrail)
		-- the pass is gone again: the trail falls back to nothing, the picked lantern (none) stays
		world.fireServerAs(me, "DebugCommand", "ToggleFakePasses")
		world.advance(0.3)
		expect(cosmetics(me):GetAttribute("Trail")).toBe("")
		expect(cosmetics(me):GetAttribute("Lantern")).toBe("")
	end)

	it("refuses cosmetics the player does not own or for the wrong slot", function()
		local data = PlayerDataService.get(me)
		local void = Cosmetics.lanterns[5]
		world.advance(1)
		world.fireServerAs(me, "EquipCosmetic", "Lantern", void.id)
		world.advance(0.3)
		expect(data.cosmetics.equipped.Lantern).toBe(Cosmetics.none)
		world.advance(1)
		world.fireServerAs(me, "EquipCosmetic", "Lantern", Cosmetics.trails[1].id)
		world.advance(0.3)
		expect(data.cosmetics.equipped.Lantern).toBe(Cosmetics.none)
		world.fireServerAs(me, "BuyWithEmbers", "Weapon", "MortarLantern") -- fails validation, nothing happens
		world.fireServerAs(me, "BuyWithEmbers", "Character", "BladeWarden")
		world.advance(0.3)
		expect(hasToast(Texts.notForSale)).toBe(true)
	end)

	it("lists locked weapons and items with their achievement", function()
		EmberShopController.showTab("UNLOCKS")
		local mortar = row("MortarLantern")
		expect(contains(mortar.Text, "Mortar Lantern (weapon) · LOCKED")).toBe(true)
		expect(contains(mortar.Text, "Kill 5 champions")).toBe(true)
		expect(contains(row("LanternCodex").Text, "(item) · LOCKED")).toBe(true)
		world.click(world.gui("Lobby", "CloseEmberShop"))
		expect(world.gui("Lobby", "EmberShop").Visible).toBe(false)
	end)

	it("puts the cosmetics back on after a respawn", function()
		local data = PlayerDataService.get(me)
		data.cosmetics.equipped.Lantern = Cosmetics.lanterns[2].id
		world.spawnCharacter(me)
		world.advance(0.3)
		expect(cosmetics(me):GetAttribute("Lantern")).toBe(Cosmetics.lanterns[2].id)
		expect(cosmetics(me):GetAttribute("Trail")).toBe("")
	end)

	it("finished without any runtime error", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n\n"))
		end
	end)
end)
