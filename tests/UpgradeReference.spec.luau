--!strict
-- Wiki revision 7968 contracts for all primary upgrade amounts; checks the actual server card factory.
local Stats = require(game:GetService("ReplicatedStorage").Shared.Config.Stats)
local Pool = require(game:GetService("ServerScriptService").Server.Services.UpgradeService.UpgradePool)

-- Source: https://brotato.wiki.spellsandguns.com/index.php?title=Upgrades&oldid=7968
local expected = {
	maxHp = { 3, 6, 9, 12 },
	hpRegen = { 2, 3, 4, 5 },
	lifeSteal = { 1, 2, 3, 4 },
	damage = { 5, 8, 12, 16 },
	meleeDamage = { 2, 4, 6, 8 },
	rangedDamage = { 1, 2, 3, 4 },
	elementalDamage = { 1, 2, 3, 4 },
	attackSpeed = { 5, 10, 15, 20 },
	critChance = { 3, 5, 7, 9 },
	engineering = { 2, 3, 4, 5 },
	range = { 15, 30, 45, 60 },
	armor = { 1, 2, 3, 4 },
	dodge = { 3, 6, 9, 12 },
	speed = { 3, 6, 9, 12 },
	luck = { 5, 10, 15, 20 },
	harvesting = { 5, 8, 10, 12 },
}

describe("Original Brotato upgrade values", function()
	for id, amounts in expected do
		it(`offers all four original {id} amounts`, function()
			for tier, amount in amounts do
				local card = Pool.card(id, tier)
				expect(card.stat).toBe(id)
				expect(card.tier).toBe(tier)
				expect(card.amount).toBe(amount)
			end
		end)
	end
	it("contains exactly the 16 reference upgrade types and no secondary upgrades", function()
		local count = 0
		for _, stat in Stats.order do
			if stat.upgrade then
				count += 1
				expect(expected[stat.id] ~= nil).toBe(true)
				expect(#stat.upgrade).toBe(4)
			end
		end
		expect(count).toBe(16)
	end)
end)
