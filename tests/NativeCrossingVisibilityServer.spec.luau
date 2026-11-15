--!strict
-- Test-only source-family promotion exercises EnemySim snapshot production; production registration remains gated.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded", function()
	local Shared = game:GetService("ReplicatedStorage").Shared
	local data = require(Shared.Config.JungleWalkers)
	table.remove(data.implemented)
	table.remove(data.implemented)
end, function(Shared)
	-- Add source rows before frozen production configuration is built; only this test process changes the list.
	local data = require(Shared.Config.JungleWalkers)
	table.insert(data.implemented, "Oviraptor")
	table.insert(data.implemented, "Iguanodon")
end)
local Enemy = require(f.S.EnemySim)
local Snapshot = require(f.Shared.Net.Snapshot)
local Kinds = require(f.Shared.Util.EnemyKinds)
local XP = require(f.S.ExperienceService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.StructureService).setPaused(true)
require(f.S.MapService).setMovementCheck(false)
require(f.S.CombatService).protect(f.me, 10000)
require(f.S.CombatService).protect(f.peer, 10000)
local seen = {}
local previousWatch = f.world.netWatch
f.world.netWatch = function(name, player, packet)
	if previousWatch then
		previousWatch(name, player, packet)
	end
	if name ~= "EnemySnapshot" or player ~= f.me then
		return
	end
	local c = Snapshot.newColumns()
	local n = Snapshot.decodeInto(packet, c, 1)
	for i = 1, n do
		seen[c.ids[i]] = c.statuses[i]
	end
end
local ovi, iguana
describe("Source crossing snapshot producer", function()
	it("sends a living hidden Oviraptor with original growth and disabled hurt area", function()
		Enemy.killAll()
		expect(Kinds.get("Oviraptor").nativeCrossing ~= nil).toBe(true)
		ovi = assert(Enemy.spawn("Oviraptor", 60, 0, 2, 3, nil, nil, 1, 10))
		expect(Enemy.getMaxHealth(ovi)).toBeNear((4 + 5 * 9) * 2)
		f.world.advance(0.2)
		expect(seen[ovi] ~= nil).toBe(true)
		expect(bit32.btest(seen[ovi], Snapshot.STATUS_HIDDEN)).toBe(true)
		expect(Enemy.queryRadius(assert(Enemy.getPosition(ovi)), 1, {})).toBe(0)
	end)
	it("clears the visibility flag when the source warning expires", function()
		f.world.advance(0.5)
		expect(bit32.btest(seen[ovi], Snapshot.STATUS_HIDDEN)).toBe(false)
		expect(Enemy.queryRadius(assert(Enemy.getPosition(ovi)), 1, {})).toBe(1)
	end)
	it("uses Iguanodon's longer warning in the actual service", function()
		Enemy.killAll()
		iguana = assert(Enemy.spawn("Iguanodon", 60, 0, 1, 0, nil, nil, 1, 10))
		expect(Enemy.getMaxHealth(iguana)).toBeNear(16 + 8 * 9)
		f.world.advance(0.6)
		expect(bit32.btest(seen[iguana], Snapshot.STATUS_HIDDEN)).toBe(true)
		f.world.advance(1.2)
		expect(bit32.btest(seen[iguana], Snapshot.STATUS_HIDDEN)).toBe(false)
	end)
	it("lets the actual actor leave without kill events or material drops", function()
		local kills = 0
		local connection = Enemy.EnemyKilled:Connect(function(info)
			if info.id == iguana then
				kills += 1
			end
		end)
		local materials = XP.getMaterialsOnFloor()
		f.world.advance(12)
		connection:Disconnect()
		expect(Enemy.isAlive(iguana)).toBe(false)
		expect(kills).toBe(0)
		expect(XP.getMaterialsOnFloor()).toBe(materials)
		expect(#f.world.errors).toBe(0)
		expect(f.Run.getNativeZoneId()).toBe(0)
		f.world.netWatch = previousWatch
	end)
end)
