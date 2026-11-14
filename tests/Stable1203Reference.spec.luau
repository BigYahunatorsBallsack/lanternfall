--!strict
-- Stable1.2.0.3 removes Caveman's Boomerang start and exempts pet weapons from Soldier's movement restriction; no new ready character is claimed.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Soldier")
local Catalog = require(f.Shared.Config.CharacterCatalog)
describe("Stable1.2.0.3 reference", function()
	it("keeps Caveman's eight melee starts without Boomerang", function()
		expect(#Catalog.Caveman.startWeapons).toBe(8)
		expect(table.find(Catalog.Caveman.startWeapons, "Boomerang")).toBe(nil)
	end)
	it("allows real Catling Gun projectiles to damage enemies while their Soldier owner is moving", function()
		f.start("WatchmanPistol")
		local Enemy = require(f.S.EnemySim)
		local Shots = require(f.S.StructureService.Projectiles)
		local Cat = require(f.S.StructureService.PetCat)
		local Movement = require(f.S.CharacterService.Movement)
		local root = f.me.Character.HumanoidRootPart
		root.AssemblyLinearVelocity = Vector3.new(1, 0, 0)
		f.world.fireServerAs(f.me, "SetMovementIntent", true, Vector3.new(1, 0, 0))
		expect(Movement.isMoving(f.me)).toBe(true)
		local at = Vector3.new(root.Position.X, f.Config.Map.arena.center.Y, root.Position.Z)
		local id = assert(Enemy.spawn("BroodEgg", at.X + 15, at.Z, 1000, 0, nil, nil, 0))
		local pet =
			{ pet = require(f.Shared.Config.Pets).kinds.CatlingGun, owner = f.me, position = at, beastMaster = false }
		local sheet = f.Stats.getSheet(f.me)
		Cat.init(pet, sheet)
		local hp = Enemy.getHealth(id)
		for _ = 1, 120 do
			Cat.step(pet, sheet, false)
			Shots.step(1 / 60)
		end
		expect(Enemy.getHealth(id) < hp).toBe(true)
		expect(Movement.isMoving(f.me)).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
