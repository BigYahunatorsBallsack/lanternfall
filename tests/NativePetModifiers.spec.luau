--!strict
-- Original supporting items reach actual owner sheets and pet/weapon computations without altering intrinsic burn scaling.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Pets = require(f.Shared.Config.Pets)
local Rules = require(f.S.StructureService.PetRules)
local Damage = require(f.Shared.Util.NativeWeaponDamage)
local WeaponStats = require(f.S.WeaponService.WeaponStats)
local OfferText = require(folderProxy("src/client", "Client").UI.OfferText)
describe("Native pet supporting modifiers", function()
	it("supplies the three original items without opening their artwork gates", function()
		for _, id in { "Nail", "FrozenHeart", "PileOfBooks" } do
			local item = assert(f.Config.Items.byId[id], id)
			expect(item.available).toBe(false)
			expect(item.limit).toBe(1)
		end
		expect(f.Config.Items.byId.Nail.stats.engineering).toBe(5)
		expect(f.Config.Items.byId.FrozenHeart.stats.burnSpeed).toBe(-100)
		expect(f.Config.Items.byId.PileOfBooks.price).toBe(60)
	end)
	it("applies additional scaling after Beast Master, including originally empty Lootworm scaling", function()
		local sheet = {
			maxHp = 50,
			meleeDamage = 10,
			rangedDamage = 20,
			elementalDamage = 30,
			engineering = 40,
			weaponScalingEngineering = 20,
			weaponScalingElemental = 10,
		}
		expect(Rules.compute(Pets.kinds.CatlingGun.weapon, sheet, true).damage).toBe(81)
		expect(Rules.compute(Pets.kinds.Ratzilla.weapon, sheet, true).damage).toBe(30)
		expect(Rules.compute(Pets.kinds.Lootworm.weapon, sheet, true).damage).toBe(12)
		expect(Rules.burnDamage(Pets.kinds.Blazemander.ranged.burning, sheet, true)).toBe(53)
		expect(#Pets.kinds.Lootworm.weapon.scaling).toBe(0)
	end)
	it("allows structure pets to inherit crit stats only with the original unlock effect", function()
		local sheet = { critChance = 50, critDamage = 50 }
		local weapon = Pets.kinds.BotOMine.weapon
		expect(Rules.compute(weapon, sheet).critChance).toBe(weapon.critChance)
		sheet.structuresCanCrit = 1
		expect(Rules.compute(weapon, sheet).critChance).toBe(weapon.critChance + 0.5)
		expect(Rules.compute(weapon, sheet).critDamage).toBe(weapon.critDamage + 0.5)
	end)
	it("grants real item modifiers to one owner and keeps normal weapon damage and shop previews aligned", function()
		f.start("WatchmanPistol")
		for _, id in { "Nail", "FrozenHeart", "PileOfBooks" } do
			assert(f.Stats.addItem(f.me, id), id)
		end
		f.world.advance(0.1)
		local sheet = f.Weapons.getStructureStats(f.me)
		expect(sheet.weaponScalingEngineering).toBe(20)
		expect(sheet.weaponScalingElemental).toBe(10)
		expect(sheet.structuresCanCrit).toBe(1)
		expect(f.Weapons.getStructureStats(f.peer).structuresCanCrit or 0).toBe(0)
		local scaling = Damage.scaling({ rangedDamage = 1 }, sheet)
		expect(scaling.engineering).toBe(0.2)
		expect(scaling.elementalDamage).toBe(0.1)
		local weapon = f.Config.Weapons.WatchmanPistol
		local stats = WeaponStats.compute(weapon, 1, sheet, nil, f.Config.Player.minWeaponCooldown)
		local preview = OfferText.stats("WatchmanPistol", 1, sheet)
		expect(stats.damage).toBe(preview.damage)
		expect(stats.nativeElemental).toBe(1)
		expect(#f.world.errors).toBe(0)
	end)
	it("counts real additional scaling entries for the six-weapon pet unlock challenges", function()
		local access = require(f.Shared.Util.CharacterAccess)
		local rule = require(f.Shared.Config.PetAccess).items.BotOMine
		for _, weapon in f.Weapons.getWeapons(f.me) do
			assert(f.Weapons.removeWeapon(f.me, weapon.uid))
		end
		f.Data.get(f.me).achievements[access.challengeKey(rule.challengeId)] = nil
		for _ = 1, 5 do
			assert(f.Weapons.addWeapon(f.me, "WatchmanPistol"))
		end
		expect(access.petUnlocked(f.Data.get(f.me), "BotOMine")).toBe(false)
		assert(f.Weapons.addWeapon(f.me, "WatchmanPistol"))
		expect(access.petUnlocked(f.Data.get(f.me), "BotOMine")).toBe(true)
	end)
	it("also applies the real item scaling to an ordinary item explosion exactly once", function()
		for _, player in { f.me, f.peer } do
			for _, weapon in f.Weapons.getWeapons(player) do
				assert(f.Weapons.removeWeapon(player, weapon.uid))
			end
		end
		local enemy = require(f.S.EnemySim)
		enemy.killAll()
		local id = assert(enemy.spawn("Brute", 70, 0, 100, 0, nil, nil, 0))
		local hp = enemy.getHealth(id)
		f.Weapons.explodeAt(f.me, enemy.getPosition(id), 10, {}, 1)
		f.Weapons.setPaused(false)
		f.world.advance(0.1, 1 / 60)
		expect(enemy.getHealth(id)).toBe(hp - 12) -- 10 + .2 * 8 Engineering + .1 * 8 Elemental
		expect(#f.world.errors).toBe(0)
	end)
	it("truncates item-explosion flat damage before adding Damage and Explosion Damage percentages", function()
		local explosions = require(f.S.WeaponService.CharacterExplosion)
		local result = explosions.computeItemEffect(
			3,
			{ engineering = 0.6 },
			1,
			{ engineering = 1, damage = 50, explosionDamage = 50 }
		)
		expect(result.damage).toBe(6)
	end)
	it("applies the same item scaling to native on-hurt and consumable character explosions", function()
		local explosions = require(f.S.WeaponService.CharacterExplosion)
		local definitions = require(f.Shared.Config.CharacterExplosions).bySource
		local sheet =
			{ engineering = 8, elementalDamage = 8, weaponScalingEngineering = 20, weaponScalingElemental = 10 }
		local glutton =
			explosions.compute(definitions["res://items/characters/glutton/glutton_explosion_stats.tres"], sheet)
		local bull = explosions.compute(definitions["res://items/characters/bull/bull_explosion_stats.tres"], sheet)
		expect(glutton.damage).toBe(12)
		expect(glutton.elemental).toBe(true)
		expect(bull.damage).toBe(56)
	end)
	it("includes the modifiers once in every Carbon Bow variant and its elemental hit identity", function()
		local weapon = f.Config.Weapons.CarbonBow
		local sheet = { meleeDamage = 30, rangedDamage = 40, engineering = 10, elementalDamage = 20 }
		local before = WeaponStats.compute(weapon, weapon.minTier, sheet, nil, f.Config.Player.minWeaponCooldown)
		sheet.weaponScalingEngineering, sheet.weaponScalingElemental = 20, 10
		local after = WeaponStats.compute(weapon, weapon.minTier, sheet, nil, f.Config.Player.minWeaponCooldown)
		local carbon = require(f.S.WeaponService.CarbonArrows)
		for index, suffix in { "Melee", "Ranged", "Elemental", "Engineering" } do
			expect(after["carbonDamage" .. suffix]).toBe(before["carbonDamage" .. suffix] + 4)
			local shot = carbon.take({ stats = after, state = { nextCarbon = index } }, after, function()
				return 0
			end)
			expect(shot.nativeElemental).toBe(1)
		end
	end)
	it("shows original modifier text instead of blank hidden-stat effects", function()
		local text = require(f.Shared.Util.EffectText)
		expect(text.line(f.Config.Items.byId.Nail.effects[1])).toBe(
			"Weapon and pet damage additionally scales with 20% Engineering"
		)
		expect(text.line(f.Config.Items.byId.FrozenHeart.effects[1])).toBe(
			"Weapon and pet damage additionally scales with 10% Elemental Damage"
		)
		expect(text.line(f.Config.Items.byId.PileOfBooks.effects[1])).toBe("Your structures can crit")
	end)
end)
