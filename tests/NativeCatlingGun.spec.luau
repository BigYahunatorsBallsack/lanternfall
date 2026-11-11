--!strict
-- Catling Gun uses native independent gun timers, real enemy targets and actual player/pet boost rules.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Pets = require(f.Shared.Config.Pets)
local Cat = require(f.S.StructureService.PetCat)
local Enemy = require(f.S.EnemySim)
local Shots = require(f.S.StructureService.Projectiles)
local y = f.Config.Map.arena.center.Y
f.start("WatchmanPistol")
local function actor()
	local o = { pet = Pets.kinds.CatlingGun, owner = f.me, position = Vector3.new(0, y, 0), beastMaster = false }
	Cat.init(o, {})
	return o
end
local function cadence(boosted)
	Enemy.killAll()
	assert(Enemy.spawn("Brute", 20, 0, 100, 0, nil, nil, 0))
	local o, events, frame = actor(), {}, 0
	local original = Shots.launchPet
	Shots.launchPet = function(_, at)
		table.insert(events, { frame = frame, at = at })
	end
	for n = 1, 111 do
		frame = n
		Cat.step(o, { attackSpeed = 1000, structureAttackSpeed = 1000 }, boosted)
	end
	Shots.launchPet = original
	return o, events
end
describe("Native Catling Gun", function()
	it("composes both original muzzle hierarchies including the250-point viewport offset", function()
		local o = actor()
		local left, right = Cat.muzzle(o, "left"), Cat.muzzle(o, "right")
		expect(left.X).toBeNear(2.60062615826293)
		expect(left.Z).toBeNear(-2.0765155300213896)
		expect(right.X).toBeNear(10.185304524869537)
		expect(right.Z).toBeNear(-0.6737624825634434)
	end)
	it("fires the right gun first when only its selected target passes the native maximum range", function()
		Enemy.killAll()
		assert(Enemy.spawn("Brute", 12, 0, 100, 0, nil, nil, 0))
		local o, count, sideX = actor(), 0, 0
		local original = Shots.launchPet
		Shots.launchPet = function(_, at)
			count += 1
			sideX = at.X
		end
		local sheet = { range = -1000 }
		for _ = 1, 55 do
			Cat.step(o, sheet, false)
		end
		Shots.launchPet = original
		expect(count).toBe(1)
		expect(sideX > 10).toBe(true)
		expect(o.catRightFrames).toBe(55)
		expect(o.catLeftFrames).toBe(27.5)
	end)
	it("alternates guns after55 initial frames with28-frame half-cooldowns", function()
		local _, events = cadence(false)
		expect(#events).toBe(3)
		expect(events[1].frame).toBe(55)
		expect(events[2].frame).toBe(83)
		expect(events[3].frame).toBe(111)
		expect(events[1].at.X < events[2].at.X).toBe(true)
	end)
	it("keeps the initial cooldown and halves subsequent delays while boosted", function()
		local _, events = cadence(true)
		expect(#events).toBe(5)
		expect(events[1].frame).toBe(55)
		expect(events[2].frame).toBe(69)
		expect(events[3].frame).toBe(83)
	end)
	it("keeps the fixed400-point detection zone even with bonus Range", function()
		Enemy.killAll()
		assert(Enemy.spawn("Brute", 60, 0, 100, 0, nil, nil, 0))
		local o, count = actor(), 0
		local original = Shots.launchPet
		Shots.launchPet = function()
			count += 1
		end
		for _ = 1, 100 do
			Cat.step(o, { range = 1000 }, false)
		end
		expect(count).toBe(0)
		assert(Enemy.spawn("Brute", 20, 0, 100, 0, nil, nil, 0))
		Cat.step(o, { range = 1000 }, false)
		Shots.launchPet = original
		expect(count).toBe(1)
	end)
	it("accepts players and other pets but excludes other Catling Guns and structures", function()
		local o = actor()
		f.me.Character.HumanoidRootPart.Position = Vector3.new(70, y, 70)
		f.peer.Character.HumanoidRootPart.Position = Vector3.new(-70, y, -70)
		expect(Cat.boosted(o, { o })).toBe(false)
		expect(Cat.boosted(o, { o, actor() })).toBe(false)
		local rat = { pet = Pets.kinds.Ratzilla, position = Vector3.new(0, y, 0) }
		expect(Cat.boosted(o, { o, rat })).toBe(true)
		expect(Cat.boosted(o, { o, { position = o.position } })).toBe(false)
		f.peer.Character.HumanoidRootPart.Position = Vector3.new(0, y, 0)
		expect(Cat.boosted(o, { o })).toBe(true)
	end)
	it("uses native wandering margins and retains a target until arrival", function()
		local o = actor()
		local bounds = { center = Vector3.new(0, y, 0), halfX = 50, halfZ = 30 }
		local target = Cat.goal(o, bounds, {}, function()
			return 1
		end)
		expect(target.X).toBeNear(37.5)
		expect(target.Z).toBeNear(17.5)
		local held = Cat.goal(o, bounds, {}, function()
			error("Target must persist")
		end)
		expect(held).toBe(target)
		o.position = target
		local nextTarget = Cat.goal(o, bounds, {}, function()
			return 0
		end)
		expect(nextTarget.X).toBeNear(-37.5)
		expect(nextTarget.Z).toBeNear(-17.5)
		local trapped, rolls = actor(), 0
		local pushed = Cat.goal(trapped, bounds, { { x = 0, z = 0, radius = 5 } }, function()
			rolls += 1
			return 0.5
		end)
		expect(rolls).toBe(18) -- first sample, eight rejected checks, then the final sample is pushed out
		expect(pushed.X).toBeNear(5.8)
		expect(pushed.Z).toBeNear(0)
	end)
end)
