--!strict
-- Robux purchases (Paket 16, DESIGN.md section 12): the game passes and developer products, their ids per experience
-- and what each gives. Read by MonetizationService (server), StoreController (client) and Util/PurchaseRules. The
-- amounts (Embers per pack, boost length and bonus, VIP rerolls, reroll pack) live in Config.Economy.
--
-- Ids come from Creator Hub -> the experience -> Monetization (Passes, Developer Products). 0 = not created yet: the
-- store shows it as "not set up yet" and nobody can buy it. The Robux price is set in the Creator Hub; `price` here
-- is only shown until the server has read the real one.

local Economy = require(script.Parent.Economy)

-- What a developer product gives. Everything lands in the saved data first (Util/PurchaseRules.grant).
export type Grant = {
	embers: number?,
	revives: number?, -- revive tokens; one stands the player up right away while they are down
	rerolls: number?, -- shop reroll tokens
	serverBoost: boolean?, -- Ember Boost for everyone in the server (Economy.serverBoost)
}

export type Product = {
	key: string,
	name: string,
	text: string,
	price: number, -- Robux, reference only
	grant: Grant,
	inStore: boolean, -- listed in the lobby store window (Revive is bought where it is used)
}

export type Pass = {
	key: string,
	name: string,
	text: string,
	price: number, -- Robux, reference only
}

-- The ids of one experience. gameId 0 matches any experience (works before the universe id is known).
export type Ids = {
	name: string,
	gameId: number,
	passes: { [string]: number },
	products: { [string]: number },
}

local packs = Economy.emberPacks

local function packText(embers: number): string
	return `Adds {embers} Embers to your saved Embers`
end

return table.freeze({
	-- One entry per experience; the live experience gets its own entry later (with its gameId set).
	experiences = table.freeze({
		table.freeze({
			name = "Lanternfall Test",
			gameId = 0, -- Creator Hub -> experience -> "Copy Universe ID"; 0 = any experience
			passes = table.freeze({ VIP = 2061811127, DoubleEmbers = 2061966995 }),
			products = table.freeze({
				Revive = 3724781719,
				Rerolls = 3724781889,
				Embers1 = 3724782123, -- 1000 Embers
				Embers2 = 3724782230, -- 5000 Embers
				Embers3 = 3724782376, -- 15000 Embers
				ServerBoost = 3724782507,
			}),
		}),
	}) :: { Ids },

	passes = table.freeze({
		table.freeze({
			key = "VIP",
			name = "VIP",
			text = `VIP tag, Gilded Sunburst lantern and Gilded Trail, +{Economy.vipExtraRerolls} free shop reroll per run, `
				.. `+{math.round(Economy.bonuses.vip * 100)}% Embers`,
			price = Economy.prices.vip,
		}),
		table.freeze({
			key = "DoubleEmbers",
			name = "Double Embers",
			text = "Every run pays twice the Embers, forever",
			price = Economy.prices.doubleEmbers,
		}),
	}) :: { Pass },

	products = table.freeze({
		table.freeze({
			key = "Revive",
			name = "Revive",
			text = "Stand up right away while you are down (once per run, co-op)",
			price = Economy.prices.revive,
			grant = table.freeze({ revives = 1 }),
			inStore = false,
		}),
		table.freeze({
			key = "Rerolls",
			name = `{Economy.rerollPackAmount} Rerolls`,
			text = `{Economy.rerollPackAmount} free shop rerolls, kept until you use them`,
			price = Economy.prices.rerollPack,
			grant = table.freeze({ rerolls = Economy.rerollPackAmount }),
			inStore = true,
		}),
		table.freeze({
			key = "Embers1",
			name = `{packs[1].embers} Embers`,
			text = packText(packs[1].embers),
			price = packs[1].robux,
			grant = table.freeze({ embers = packs[1].embers }),
			inStore = true,
		}),
		table.freeze({
			key = "Embers2",
			name = `{packs[2].embers} Embers`,
			text = packText(packs[2].embers),
			price = packs[2].robux,
			grant = table.freeze({ embers = packs[2].embers }),
			inStore = true,
		}),
		table.freeze({
			key = "Embers3",
			name = `{packs[3].embers} Embers`,
			text = packText(packs[3].embers),
			price = packs[3].robux,
			grant = table.freeze({ embers = packs[3].embers }),
			inStore = true,
		}),
		table.freeze({
			key = "ServerBoost",
			name = "Server Ember Boost",
			text = `+{math.round(Economy.serverBoost.bonus * 100)}% Embers for everyone in this server for `
				.. `{math.round(Economy.serverBoost.durationSeconds / 60)} min, with your name on it`,
			price = Economy.prices.serverBoost,
			grant = table.freeze({ serverBoost = true }),
			inStore = true,
		}),
	}) :: { Product },

	receiptMemory = 100, -- PurchaseIds kept per profile (oldest dropped); Roblox retries a receipt for days at most
	receiptWaitSeconds = 30, -- ProcessReceipt waits this long for the profile to load and to save, else retries later
	passCheckAttempts = 3, -- UserOwnsGamePassAsync tries per pass when a player joins
	passRetrySeconds = 2,

	vip = table.freeze({
		attribute = "LanternfallVip", -- player attribute (chat tag on every client)
		tag = "VIP",
		color = table.freeze({ 245, 197, 66 }), -- RGB (no Color3 here: pure specs load Config)
		colorHex = "F5C542", -- the same color for the chat tag
		-- the VIP lantern and trail are cosmetics since Paket 17 (Config.Cosmetics, vip = true)
	}),

	texts = table.freeze({
		notSetUp = "This purchase is not set up yet",
		alreadyOwned = "You already own this",
		reviveNotNow = "Revive works while you are down in a co-op run",
		reviveUsed = "You already used a revive this run",
		reviveSaved = "Revive saved: it stands you up the next time you are down",
		noRerolls = "No bonus rerolls left",
		shopClosed = "Only in the shop",
		thanks = "Thank you! ", -- + what was bought
	}),
})
