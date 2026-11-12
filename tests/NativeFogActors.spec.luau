--!strict
-- Fog reads actual burn/charm snapshots and deployed pet/structure positions, including actors outside cosmetic particle culling.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
runScript(folderProxy("src/client", "Client"), "init.client.luau")
local Client = folderProxy("src/client", "Client")
local Enemy = require(f.S.EnemySim)
local Renderer = require(Client.Controllers.EnemyRenderer)
local StructureRenderer = require(Client.Controllers.StructureRenderer)
local Structures = require(f.S.StructureService)
f.start(f.class.startWeapons[1])
f.Weapons.setPaused(true)
for _, player in { f.me, f.peer } do
	require(f.S.CombatService).protect(player, 1000)
end
local function sources()
	local result = {}
	Renderer.visitFogSources(function(id, x, z, kind)
		result[kind .. id] = { x = x, z = z }
	end)
	return result
end
describe("Native fog actor sources", function()
	it("illuminates a burning actor beyond the cosmetic ember culling distance and stops when burning ends", function()
		local id = assert(Enemy.spawn("Brute", 500, 500, 100, 0, nil, nil, 0))
		Enemy.setBurning(id, true)
		f.world.advance(0.5)
		local light = sources()["fire" .. id]
		expect(light ~= nil).toBe(true)
		-- The mask shares the existing quantized/interpolated client position, not the next server simulation tick.
		local position = assert(Renderer.getPosition(id))
		expect(light.x).toBeNear(position.X)
		expect(light.z).toBeNear(position.Z)
		local _, onScreen = workspace.CurrentCamera:WorldToViewportPoint(position)
		expect(onScreen).toBe(false)
		Enemy.setBurning(id, false)
		f.world.advance(0.3)
		expect(sources()["fire" .. id]).toBe(nil)
		Enemy.killAll()
	end)
	it("adds independent support light to a charmed enemy and drops it on expiry", function()
		local id = assert(Enemy.spawn("Brute", 20, 20, 100, 0, nil, nil, 0))
		Enemy.damage(id, 1, nil)
		assert(Enemy.tryCharm(f.me, id, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end))
		f.world.advance(0.5)
		expect(sources()["structure" .. id] ~= nil).toBe(true)
		f.world.advance(9)
		expect(sources()["structure" .. id]).toBe(nil)
	end)
	it(
		"reads deployed structures and pets from the production renderer and clears their positions at run end",
		function()
			assert(f.Stats.addItem(f.me, "BrassSentry"))
			assert(f.Stats.addItem(f.me, "BonkDog"))
			f.nextWave()
			local positions = {}
			StructureRenderer.visitPositions(function(id, x, z)
				positions[id] = { x = x, z = z }
			end)
			local count = 0
			for _, row in Structures.getSnapshot() do
				count += 1
				expect(positions[row.id] ~= nil).toBe(true)
				expect(positions[row.id].x).toBeNear(row.x)
				expect(positions[row.id].z).toBeNear(row.z)
			end
			expect(count).toBe(2)
			assert(f.Run.endRun("Abandoned"))
			f.world.advance(0.2)
			local after = 0
			StructureRenderer.visitPositions(function()
				after += 1
			end)
			expect(after).toBe(0)
			expect(#f.world.errors).toBe(0)
		end
	)
end)
