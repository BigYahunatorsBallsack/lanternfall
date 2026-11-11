--!strict
-- Server pet-start validation and all four Beast Master starts use production class, stats and run services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("BeastMaster")
local Pets = require(f.S.StartPetService)
local Options = require(f.Shared.Util.DangerRules)
local function lobby()
	if f.Run.isOngoing() then
		f.Run.endRun("Abandoned")
	end
	if f.Run.getPhase() == "Ended" then
		f.world.advance(f.Config.Run.flow.resultsSeconds + 0.5)
	end
	assert(f.Run.selectClass(f.me, "BeastMaster"))
end
describe("Native start pet selection", function()
	it("exposes the four original item choices without adding weapons or changing the art gate", function()
		expect(#f.class.startPets).toBe(4)
		expect(f.class.startPets[1]).toBe("BonkDog")
		expect(f.class.maxWeapons).toBe(0)
		expect(#f.class.startWeapons).toBe(0)
		expect(f.originalAvailable).toBe(false)
	end)
	it("rejects forged item, weapon, character and in-run selections and isolates players", function()
		lobby()
		local rule = require(f.Shared.Config.PetAccess).items.BonkDog
		local key = require(f.Shared.Util.CharacterAccess).challengeKey(rule.challengeId)
		f.Data.get(f.me).achievements[key] = nil
		expect(Pets.selectStartPet(f.me, "BeastMaster", "BonkDog")).toBe(false)
		f.Data.get(f.me).achievements[key] = true
		expect(Pets.selectStartPet(f.me, "BeastMaster", "Ratzilla")).toBe(false)
		expect(Pets.selectStartPet(f.me, "BeastMaster", "WatchmanPistol")).toBe(false)
		expect(Pets.selectStartPet(f.me, "NightWatch", "BonkDog")).toBe(false)
		expect(Pets.selectStartPet(f.peer, "BeastMaster", "BonkDog")).toBe(false)
		expect(f.Weapons.selectStartWeapon(f.me, "BeastMaster", "WatchmanPistol")).toBe(false)
		f.world.fireServerAs(f.me, "SelectStartPet", "BeastMaster", "CatlingGun")
		expect(Pets.getStartPet(f.me, "BeastMaster")).toBe("CatlingGun")
		expect(Pets.getStartPet(f.peer, "BeastMaster")).toBe(nil)
	end)
	it("grants the selected pet plus one Lootworm and Ratzilla for every original start", function()
		for _, id in f.class.startPets do
			lobby()
			assert(Pets.selectStartPet(f.me, "BeastMaster", id))
			assert(f.Run.launch({ f.me, f.peer }, Options.defaultOptions()))
			f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
			require(f.S.SpawnDirector).setPaused(true)
			expect(#f.Weapons.getWeapons(f.me)).toBe(0)
			expect(#f.Weapons.getWeapons(f.peer)).toBe(2) -- peer retains the unpromoted legacy Ranger package
			expect(f.Weapons.getWeapons(f.peer)[2].id).toBe("WatchmanPistol")
			local items = f.Stats.getItemCounts(f.me)
			expect(items.Lootworm).toBe(1)
			expect(items.Ratzilla).toBe(1)
			expect(items[id]).toBe(1)
			local count = 0
			for _, amount in items do
				count += amount
			end
			expect(count).toBe(3)
			expect(f.Stats.getStat(f.me, "luck")).toBe(10)
			expect(f.Stats.getStat(f.me, "speed")).toBe(6)
			expect(Pets.selectStartPet(f.me, "BeastMaster", "BonkDog")).toBe(false)
		end
	end)
	it("counts permanent pet copies and Jellyshield effects without depending on visible deployments", function()
		local structures = require(f.S.StructureService)
		expect(structures.petSourceCount(f.me)).toBe(3)
		expect(structures.sourceCount(f.me)).toBe(1) -- last start is Bot-O-Mine, both pet and structure
		assert(f.Stats.addItem(f.me, "Ratzilla"))
		assert(f.Stats.addItem(f.me, "RuneMine"))
		expect(structures.petSourceCount(f.me)).toBe(4)
		expect(f.Stats.getStat(f.me, "speed")).toBe(8)
		assert(f.Stats.addStats(f.me, { jellyshieldCount = 2 }))
		expect(structures.petSourceCount(f.me)).toBe(6)
		expect(f.Stats.getStat(f.me, "speed")).toBe(12)
		require(f.S.StructureService.PetActors).clear()
		expect(structures.petSourceCount(f.me)).toBe(6)
		expect(f.Stats.getStat(f.me, "speed")).toBe(12)
	end)
end)
