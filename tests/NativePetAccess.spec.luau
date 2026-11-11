--!strict
-- Original five-item prerequisite chain: personal six-scaling-weapon challenges and completed-wave floor material value.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("ManyHands")
local PetAccess = require(f.Shared.Config.PetAccess)
local Access = require(f.Shared.Util.CharacterAccess)
local XP = require(f.S.ExperienceService)
local function clearFlags(player)
	local data = f.Data.get(player)
	data.achievements[Access.challengeKey(PetAccess.character.challengeId)] = nil
	for _, rule in PetAccess.items do
		if rule.challengeId then
			data.achievements[Access.challengeKey(rule.challengeId)] = nil
		end
	end
end
f.start(f.class.startWeapons[1])
f.Weapons.setPaused(true)
XP.setPaused(true)
clearFlags(f.me)
clearFlags(f.peer)
describe("Native pet access", function()
	it("does not confuse the aggregate Beast Master challenge with three owned pet types", function()
		for _, id in { "Ratzilla", "BonkDog", "BotOMine" } do
			assert(f.Stats.addItem(f.me, id))
		end
		expect(Access.characterUnlocked(f.Data.get(f.me), "BeastMaster")).toBe(false)
		expect(Access.petUnlocked(f.Data.get(f.me), "Ratzilla")).toBe(true)
	end)
	it("requires six simultaneously equipped scaling weapons and never uses a teammate's inventory", function()
		local starts = {
			{ "BonkDog", "BrassKnuckles" },
			{ "CatlingGun", "WatchmanPistol" },
			{ "Blazemander", "SparkBolt" },
			{ "BotOMine", "RuneAwl" },
		}
		for _, row in starts do
			local petId, weaponId = row[1], row[2]
			for _, weapon in f.Weapons.getWeapons(f.me) do
				assert(f.Weapons.removeWeapon(f.me, weapon.uid))
			end
			for _ = 1, 5 do
				assert(f.Weapons.addWeapon(f.me, weaponId))
			end
			expect(Access.petUnlocked(f.Data.get(f.me), petId)).toBe(false)
			assert(f.Weapons.addWeapon(f.me, weaponId))
			expect(Access.petUnlocked(f.Data.get(f.me), petId)).toBe(true)
			expect(Access.petUnlocked(f.Data.get(f.peer), petId)).toBe(false)
		end
		expect(Access.characterUnlocked(f.Data.get(f.me), "BeastMaster")).toBe(false)
	end)
	it(
		"unlocks Lootworm from floor value at a completed wave, then persists the Beast Master prerequisite flag",
		function()
			f.me.Character.HumanoidRootPart.Position = Vector3.new(70, 0, 70)
			f.peer.Character.HumanoidRootPart.Position = Vector3.new(-70, 0, -70)
			XP.setPaused(false)
			XP.dropMaterials(Vector3.new(0, f.Config.Map.arena.center.Y, 0), 20, 0)
			expect(XP.getMaterialsOnFloor() >= 20).toBe(true)
			expect(Access.petUnlocked(f.Data.get(f.me), "Lootworm")).toBe(false)
			f.Run.skipTo(require(f.Shared.Util.RunSchedule).wave(f.Run.getWave()).endsAt)
			f.world.advance(0.1)
			expect(Access.petUnlocked(f.Data.get(f.me), "Lootworm")).toBe(true)
			expect(Access.characterUnlocked(f.Data.get(f.me), "BeastMaster")).toBe(true)
			expect(Access.characterUnlocked(f.Data.get(f.peer), "BeastMaster")).toBe(false)
			expect(f.Data.get(f.me).achievements[Access.challengeKey(PetAccess.character.challengeId)]).toBe(true)
		end
	)
end)
