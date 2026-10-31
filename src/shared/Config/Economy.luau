--!strict
-- Ember sources, bonuses and reference prices (DESIGN.md sections 10-12). Read by Util/ProgressRules, Config.Store,
-- Util/PurchaseRules and MonetizationService. Product/pass ids from the Creator Hub are in Config.Store (Paket 16).

return table.freeze({
	embers = table.freeze({
		perMinuteSurvived = 10,
		perElite = 15,
		bossKill = 150,
		dailyQuestMin = 50,
		dailyQuestMax = 100,
	}),
	bonuses = table.freeze({
		party = 0.1, -- playing with friends
		group = 0.05, -- member of the Roblox group
		vip = 0.1,
		doubleEmbersMultiplier = 2,
	}),
	classUnlockEmbers = 2500,
	serverBoost = table.freeze({ durationSeconds = 1800, bonus = 0.5 }),
	vipExtraRerolls = 1,
	-- Robux prices, reference only; the real price is set in the Creator Hub.
	prices = table.freeze({
		vip = 249,
		doubleEmbers = 399,
		classUnlock = 199,
		revive = 49,
		rerollPack = 25,
		serverBoost = 149,
	}),
	rerollPackAmount = 3,
	emberPacks = table.freeze({
		table.freeze({ robux = 79, embers = 1000 }),
		table.freeze({ robux = 349, embers = 5000 }),
		table.freeze({ robux = 899, embers = 15000 }),
	}),
})
