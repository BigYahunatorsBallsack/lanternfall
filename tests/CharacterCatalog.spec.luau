--!strict
-- Installed stable 1.2.0.1 character contracts; original facts do not imply completed runtime integration.
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.CharacterCatalog)
local Classes = require(Shared.Config.Classes)

describe("Stable original character catalog", function()
	it("contains every original character once and preserves existing profile ids", function()
		local count = 0
		local sets = { mainGame = 0, abyssalTerrors = 0, primalDread = 0 }
		local originals = {}
		for id, character in Catalog do
			count += 1
			sets[character.contentSet] += 1
			assert(not originals[character.originalId], character.originalId)
			originals[character.originalId] = true
			expect(character.id).toBe(id)
			expect(Classes[id].native).toBe(character)
		end
		expect(count).toBe(74)
		expect(sets.mainGame).toBe(50)
		expect(sets.abyssalTerrors).toBe(14)
		expect(sets.primalDread).toBe(10)
		expect(Catalog.SparkMage.originalId).toBe("character_mage")
		expect(Catalog.NightWatch.originalId).toBe("character_ranger")
	end)

	it("uses original HP and the installed damage modifier lists", function()
		expect(Catalog.WellRounded.stats.maxHp).toBe(5)
		expect(Catalog.Golem.stats.maxHp).toBe(20)
		expect(Catalog.CandleScholar.perLevel.maxHp).toBe(-2)
		expect(Catalog.MarbleHost.stats.fruitHeal).toBe(3)
		expect(Catalog.SoleConductor.gainMultipliers.rangedDamage).toBe(2)
		expect(Catalog.SoleConductor.gainMultipliers.meleeDamage).toBe(2)
		expect(Catalog.SoleConductor.setCountBonus).toBe(3)
		expect(Catalog.Ghost.stats.dodgeCap).toBe(90)
		expect(Catalog.Cryptid.stats.dodgeCap).toBe(70)
		expect(Catalog.Sailor.stats.dodgeCap).toBe(20)
		expect(Catalog.Soldier.canAttackWhileMoving).toBe(false)
	end)

	it("distinguishes fixed equipment from selectable equipment and converts zero-based tiers", function()
		expect(Catalog.Brawler.extraWeapons[1]).toBe("BrassKnuckles")
		expect(Catalog.Cyborg.extraWeapons[1]).toBe("Minigun")
		expect(Catalog.Cyborg.extraWeaponTiers.Minigun).toBe(3)
		expect(#Catalog.BeastMaster.startItemChoices).toBe(4)
		expect(#Catalog.BeastMaster.startItems).toBe(2)
		expect(Catalog.BeastMaster.maxWeapons).toBe(0)
		expect(Catalog.Baby.baseWeaponSlots).toBe(1)
		expect(Catalog.Baby.slotUpgradeAmount).toBe(1)
		expect(Catalog.Baby.maxWeaponSlots).toBe(24)
	end)

	it("keeps weapon-local damage, range and critical multiplier units distinct", function()
		expect(Catalog.Ghost.weaponClassStats.Spectral.baseDamage).toBe(10)
		expect(Catalog.Crazy.weaponClassStats.Keen.weaponRange).toBe(100)
		expect(Catalog.Diver.weaponClassStats.Keen.critDamage).toBe(200)
		expect(Catalog.Doctor.weaponClassStats.Remedy.attackSpeed).toBe(200)
	end)
end)
