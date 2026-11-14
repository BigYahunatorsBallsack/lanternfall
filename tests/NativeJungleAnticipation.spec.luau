--!strict
-- Native anticipation uses validated input direction, including walls; the horizontal variant keeps the original target's z.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Movement = require(f.S.CharacterService.Movement)
local World = require(f.S.EnemySim.World)
local Kinds = require(f.Shared.Util.EnemyKinds)
local Sim = f.Config.Simulation
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
local function world(name)
	local w = World.new({
		cellSize = Sim.spatialHashCellSize,
		maxEnemies = 140,
		playerRadius = Sim.playerRadius,
		contactMargin = 0,
		separationStiffness = Sim.separationStiffness,
		separationPasses = Sim.separationPasses,
		obstacleSteerMargin = Sim.obstacleSteerMargin,
		keepDistanceTolerance = Sim.keepDistanceTolerance,
		minX = -1000,
		maxX = 1000,
		minZ = -1000,
		maxZ = 1000,
		obstacles = {},
	})
	local kind = table.clone(assert(Kinds.get(name)))
	kind.speed, kind.speedMax = 10, 10
	local id = assert(w:spawn(kind, 0, 0, 1000, 0))
	return w, id
end
describe("Native Jungle anticipation", function()
	it("derives full input speed on the server even when physical movement is blocked", function()
		f.me.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		f.world.fireServerAs(f.me, "SetMovementIntent", true, Vector3.new(0.6, 0, 0.8))
		local input = Movement.getInput(f.me)
		expect(input.X).toBeNear(f.Config.Player.moveSpeed * 1.05 * 0.6)
		expect(input.Z).toBeNear(f.Config.Player.moveSpeed * 1.05 * 0.8)
		expect(Movement.getInput(f.peer).Magnitude).toBe(0)
	end)
	it("rejects malformed or contradictory directions and preserves legacy boolean clients", function()
		for _, direction in { Vector3.new(2, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0 / 0, 0, 0), Vector3.zero } do
			f.world.fireServerAs(f.me, "SetMovementIntent", true, direction)
		end
		local input = Movement.getInput(f.me)
		expect(input.X).toBeNear(f.Config.Player.moveSpeed * 1.05 * 0.6)
		f.world.fireServerAs(f.me, "SetMovementIntent", false, Vector3.new(1, 0, 0))
		expect(Movement.getInput(f.me).X).toBeNear(input.X)
		f.world.fireServerAs(f.me, "SetMovementIntent", false)
		expect(Movement.isMoving(f.me)).toBe(false)
	end)
	it("updates direction while walking continuously through the existing client controller", function()
		local controller = require(folderProxy("src/client", "Client").Controllers.MovementIntentController)
		controller.init()
		f.me.Character.Humanoid.MoveDirection = Vector3.new(1, 0, 0)
		f.world.advance(0.1)
		expect(Movement.getInput(f.me).X).toBeNear(f.Config.Player.moveSpeed * 1.05)
		f.me.Character.Humanoid.MoveDirection = Vector3.new(0, 0, 1)
		f.world.advance(0.1)
		expect(Movement.getInput(f.me).Z).toBeNear(f.Config.Player.moveSpeed * 1.05)
		expect(Movement.getInput(f.me).X).toBeNear(0)
		f.me.Character.Humanoid.MoveDirection = Vector3.zero
		f.world.advance(0.1)
	end)
	it("keeps intended speed separate from knockback and aligned across world transfers", function()
		local w, id = world("BabyPterosaur")
		w:step(0.1, { 30 }, { 0 }, 1)
		w:knock(id, 0, 100)
		w:step(0.1, { 30 }, { 0 }, 1)
		local x, z = w:getMoveInput(id)
		expect(math.sqrt(x * x + z * z)).toBeNear(10)
		local destination = world("BabyPterosaur")
		destination:clear()
		expect(w:transferTo(destination, id)).toBe(true)
		local otherX, otherZ = destination:getMoveInput(id)
		expect(otherX).toBeNear(x)
		expect(otherZ).toBeNear(z)
	end)
	it("leads both axes for Baby Pterosaur and only x for Graciliceratops", function()
		local w, id = world("BabyPterosaur")
		w:step(0.1, { 30 }, { 0 }, 1, nil, nil, nil, { 0 }, { 20 })
		local at = w:getPosition(id)
		expect(at).toBeNear(30 / math.sqrt(30 ^ 2 + 6 ^ 2))
		local _, z = w:getPosition(id)
		expect(z).toBeNear(6 / math.sqrt(30 ^ 2 + 6 ^ 2))
		w, id = world("Graciliceratops")
		w:step(0.1, { 30 }, { 0 }, 1, nil, nil, nil, { 0 }, { 20 })
		local x
		x, z = w:getPosition(id)
		expect(x).toBeNear(1)
		expect(z).toBeNear(0)
	end)
	it("chooses the nearest current target before applying anticipation", function()
		local w, id = world("BabyPterosaur")
		w:step(0.1, { 30, 40 }, { 0, 0 }, 2, nil, nil, nil, { 0, 0 }, { 2000, 0 })
		local _, z = w:getPosition(id)
		expect(z > 0.9).toBe(true)
	end)
end)
