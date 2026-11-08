--!strict
-- Explicit source item groups, personal exclusions and the native wave-20 boundary across shop/crate pools.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Ids = require(Shared.Config.CharacterItemRules)
local Rules = require(game:GetService("ServerScriptService").Server.Services.ShopService.ShopRules)

describe("Native character item pools", function()
	it("identifies all current items using the installed original item identities", function()
		for _, item in Config.Items.list do
			assert(Ids.nativeIds[item.id], item.id)
		end
		expect(Ids.nativeIds.FlintShard).toBe("item_lens")
		expect(Ids.nativeIds.TitanArms).toBe("item_big_arms")
	end)

	it("uses Brawler's explicit Lens group instead of banning every ranged-damage item", function()
		expect(Rules.itemAllowed("Brawler", "FlintShard", 1)).toBe(false)
		expect(Rules.itemAllowed("Brawler", "TitanArms", 1)).toBe(true)
		expect(Rules.itemAllowed("Crazy", "FlintShard", 1)).toBe(true)
		for seed = 0, 20 do
			local item = Rules.pickItem(1, {}, {}, function()
				return seed / 21
			end, nil, "Brawler", 1)
			expect(item == "FlintShard").toBe(false)
		end
	end)

	it("applies Ghost's explicit exclusions and lifts character bans at wave twenty", function()
		expect(Rules.itemAllowed("Ghost", "Armor", 19)).toBe(false)
		expect(Rules.itemAllowed("Ghost", "SmokeMantle", 19)).toBe(false)
		expect(Rules.itemAllowed("Ghost", "Armor", 20)).toBe(true)
		expect(Rules.itemAllowed("Brawler", "FlintShard", 20)).toBe(true)
		expect(Rules.itemAllowed("Crazy", "TitheBox", 20)).toBe(false)
	end)
	it("preserves the native same-tier backup exception when the normal pool is empty", function()
		local taken = {}
		for _, item in Config.Items.list do
			taken[item.id] = true
		end
		taken.FlintShard = nil
		expect(Rules.pickItem(1, {}, taken, function()
			return 0
		end, nil, "Brawler", 1)).toBe("FlintShard")
	end)
	it("matches native wanted tags using original item tags rather than runtime stat aliases", function()
		for seed = 0, 20 do
			local item = Rules.pickItem(1, {}, {}, function()
				return seed / 21
			end, { "stat_dodge" }, "Ghost", 1)
			assert(item, "The native tier-I Dodge preference must have an eligible item")
			expect(table.find(Ids.tags[item], "stat_dodge") ~= nil).toBe(true)
			expect(Rules.itemAllowed("Ghost", item, 1)).toBe(true)
		end
	end)
end)
