--!strict
-- Native player and common enemy body masks exclude each other; actual EnemySim must not push actors away using damage circles.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
f.start("WatchmanPistol")
local Map = require(f.S.MapService)
Map.setMovementCheck(false)
require(f.S.CombatService).protect(f.me, 10000)
local at = assert(Map.getRootPosition(f.me))
f.peer.Character.HumanoidRootPart.Position = at + Vector3.new(-80, 0, 80)
describe("Native player/enemy body mask", function()
	it("permits coincident stationary actor origins without artificial player-circle push-out", function()
		local id = assert(Enemy.spawn("Shadeling", at.X, at.Z, 1000, 1, nil, nil, 0, 1))
		f.world.advance(0.1)
		local position = assert(Enemy.getPosition(id))
		expect(position.X).toBeNear(at.X)
		expect(position.Z).toBeNear(at.Z)
		Enemy.remove(id)
	end)
	it("retains actual legacy contact damage despite separate player hurt and root positions", function()
		local contact = 0
		local connection = Enemy.Contact:Connect(function(player, damage)
			if player == f.me then
				contact = damage
			end
		end)
		local id = assert(Enemy.spawn("Spitter", at.X + 1, at.Z, 1000, 1, nil, nil, 0, 11))
		f.world.advance(0.1)
		expect(contact).toBeNear(7)
		connection:Disconnect()
		Enemy.remove(id)
	end)
end)
