--!strict
-- Real Lootworm pickups preserve bag/pet/common multiplication, personal object events and the existing cooperative rotation.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local XP = require(f.S.ExperienceService)
local Map = require(f.S.MapService)
local y = f.Config.Map.arena.center.Y
local collected, objects = {}, {}
XP.OrbsCollected:Connect(function(player, amount)
	collected[player] = (collected[player] or 0) + amount
end)
XP.OrbsPickedUp:Connect(function(player, amount)
	objects[player] = (objects[player] or 0) + amount
end)
local function start()
	f.start("WatchmanPistol")
	f.Weapons.setPaused(true)
	Map.setMovementCheck(false)
	f.me.Character.HumanoidRootPart.Position = Vector3.new(70, y, 70)
	f.peer.Character.HumanoidRootPart.Position = Vector3.new(-70, y, -70)
	XP.setPaused(false)
	table.clear(collected)
	table.clear(objects)
end
local function dropOne(at)
	local random = require(f.S.RandomService)
	local original = random.number
	-- Two-player material rounding can create a second object; keep exactly one physical gold for this fixture.
	random.number = function(stream, player)
		return if stream == "Loot" then 0.999 else original(stream, player)
	end
	XP.dropMaterials(at, 1, 0)
	random.number = original
end
describe("Native pet material pickup integration", function()
	it("combines bag x2, Lootworm x2 and common pickup x2 with one personal object event", function()
		start()
		f.Stats.addStats(f.me, { doubleShards = 100 })
		local random = require(f.S.RandomService)
		local original = random.number
		XP.addToBag(1)
		dropOne(Vector3.new(0, y, 0))
		random.number = function(stream, player)
			return if stream == "Loot" then 0 else original(stream, player)
		end
		local id = assert(XP.nearestMaterial(Vector3.new(0, y, 0)))
		local at = assert(XP.getMaterialPosition(id))
		local boosted, states = 0, 0
		local shop = require(f.S.ShopService)
		local shardsBefore = shop.getShards(f.me)
		f.world.netWatch = function(name, player, event)
			if name == "XpOrbs" and player == f.me and event.boosted then
				boosted = event.boosted[2]
			end
			if name == "ShopState" and player == f.me then
				states += 1
			end
		end
		local bonus = XP.stepPetMaterials(f.me, 5000, at, 1 / 60)
		local repeated = XP.stepPetMaterials(f.me, 5000, at, 1 / 60)
		random.number = original
		expect(bonus).toBe(2)
		expect(repeated).toBe(0)
		expect(XP.getOrbCount()).toBe(0)
		expect(collected[f.me]).toBe(4)
		expect(collected[f.peer]).toBe(4)
		expect(objects[f.me]).toBe(1)
		expect(objects[f.peer]).toBe(nil)
		expect(states).toBe(0)
		expect(shop.getShards(f.me)).toBe(shardsBefore + 4)
		XP.setPaused(true)
		f.world.advance(f.Config.Shop.materialSyncSeconds + 0.1, 1 / 60)
		f.world.netWatch = nil
		expect(boosted).toBe(8)
		expect(states).toBe(1)
	end)
	it("keeps pet-attracted gold until a player physically touches it and releases abandoned claims", function()
		start()
		dropOne(Vector3.new(10, y, 0))
		local id = assert(XP.nearestMaterial(Vector3.new(10, y, 0)))
		local at = assert(XP.getMaterialPosition(id))
		XP.stepPetMaterials(f.me, 5001, at + Vector3.new(9, 0, 0), 1 / 60)
		f.me.Character.HumanoidRootPart.Position = at - Vector3.new(10, 0, 0)
		f.world.advance(0.1, 1 / 60)
		expect(XP.getOrbCount()).toBe(1)
		f.me.Character.HumanoidRootPart.Position = at
		f.world.advance(0.1, 1 / 60)
		expect(XP.getOrbCount()).toBe(0)
		expect(objects[f.me]).toBe(1)
		XP.releasePetMaterials(5001)
		expect(#f.world.errors).toBe(0)
	end)
end)
