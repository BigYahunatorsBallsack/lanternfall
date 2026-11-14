--!strict
-- Full native starts, source mechanics and personal challenge boundaries through production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Vagabond")
describe("Native Vagabond package", function()
	it("runs all30 original starts", function()
		f.starts(30)
	end)
	it("counts every equipped weapon for present sets and prevents duplicate families", function()
		f.start("Claw")
		expect(f.Stats.getStat(f.me, "armor")).toBe(-5)
		expect(f.Stats.getStat(f.me, "dodge")).toBe(-5)
		f.Stats.addStats(f.me, { luck = 10, harvesting = 10 })
		expect(f.Stats.getStat(f.me, "luck")).toBe(5)
		expect(f.Stats.getStat(f.me, "harvesting")).toBe(5)
		assert(f.Weapons.addWeapon(f.me, "Railgun", 1))
		assert(f.Weapons.addWeapon(f.me, "Torch", 1))
		expect(f.Weapons.addWeapon(f.me, "Claw", 2)).toBe(false)
		local Sets = require(f.Shared.Util.WeaponClasses)
		local counts = Sets.counts({ "Claw", "Railgun", "Torch" }, "Vagabond")
		for _, count in counts do
			expect(count).toBe(3)
		end
		expect(counts.Dread).toBe(nil)
		expect(f.Stats.getStat(f.me, "dodge")).toBe(1)
		local Rules = require(f.S.ShopService.ShopRules)
		local merge, blocked = Rules.weaponStatus("Claw", 1, { { id = "Claw", tier = 1 } }, 6, 4, "Vagabond")
		expect(merge).toBe(true)
		expect(blocked).toBe(false)
	end)
	it("requires six distinct simultaneous weapons rather than six copies", function()
		local A = require(f.Shared.Util.CharacterAccess)
		for _, w in f.Weapons.getWeapons(f.peer) do
			f.Weapons.removeWeapon(f.peer, w.uid)
		end
		for _, id in { "WatchmanPistol", "RattleRepeater", "ScatterBell", "ShrapnelOrgan", "WinterNeedle" } do
			assert(f.Weapons.addWeapon(f.peer, id, 1))
		end
		assert(f.Weapons.addWeapon(f.peer, "WatchmanPistol", 2))
		expect(A.characterUnlocked(f.Data.get(f.peer), "Vagabond")).toBe(false)
		for _, w in f.Weapons.getWeapons(f.peer) do
			if w.tier == 2 then
				f.Weapons.removeWeapon(f.peer, w.uid)
			end
		end
		assert(f.Weapons.addWeapon(f.peer, "GalvanicFork", 1))
		expect(A.characterUnlocked(f.Data.get(f.peer), "Vagabond")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
	it("filters lower and unupgradable duplicates from fallback shop pools while retaining same-tier merges", function()
		local Rules = require(f.S.ShopService.ShopRules)
		local function roll(wave, ownedTier, random)
			local nextId = 0
			return Rules.roll({
				classId = "Vagabond",
				wave = wave,
				luck = 0,
				weapons = { "Claw", "RitualDirk" },
				ownedWeapons = { { id = "Claw", tier = ownedTier } },
				maxWeapons = 6,
				maxTier = 4,
				ownedItems = {},
				nextId = function()
					nextId += 1
					return tostring(nextId)
				end,
				random = function()
					return random
				end,
			})
		end
		for _, offers in { roll(1, 2, 0.99), roll(20, 4, 0) } do
			local weapons = 0
			for _, offer in offers do
				if offer.kind == "Weapon" then
					weapons += 1
					expect(offer.itemId == "Claw").toBe(false)
				end
			end
			expect(weapons > 0).toBe(true)
		end
		local merge = false
		for _, offer in roll(3, 2, 0) do
			if offer.itemId == "Claw" then
				expect(offer.tier).toBe(2)
				expect(offer.merges).toBe(true)
				merge = true
			end
		end
		expect(merge).toBe(true)
	end)
end)
