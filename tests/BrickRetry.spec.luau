--!strict
-- A broken native start weapon and its physical materials roll back with the wave checkpoint, without recycling credit.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Mutant")
local XP = require(f.S.ExperienceService)
local Enemy = require(f.S.EnemySim)
local Random = require(f.S.RandomService)
local old = Random.number
Random.number = function(channel, player)
	return if channel == "Combat" then 0.01 elseif channel == "Loot" then 0.99 else old(channel, player)
end
describe("Native Brick retry", function()
	it("restores the original Brick, clears break loot and does not immediately pay the collector", function()
		f.start("Brick")
		for _, w in f.Weapons.getWeapons(f.peer) do
			f.Weapons.removeWeapon(f.peer, w.uid)
		end
		local at = f.me.Character.HumanoidRootPart.Position
		assert(Enemy.spawn("Brute", at.X + 6, at.Z, 1000, 0, nil, nil, 0))
		local Shop = require(f.S.ShopService)
		local before = Shop.getShards(f.me)
		f.Weapons.setPaused(false)
		f.world.advance(0.08)
		expect(#f.Weapons.getWeapons(f.me)).toBe(0)
		expect(XP.getOrbCount()).toBe(14) --native two-player material factor, floor because Loot roll.99
		expect(Shop.getShards(f.me)).toBe(before)
		f.Weapons.setPaused(true)
		f.Run.setParticipantState(f.me, "Down")
		f.Run.setParticipantState(f.peer, "Down")
		f.world.advance(0.1)
		assert(f.Run.retryWave(f.peer))
		expect(#f.Weapons.getWeapons(f.me)).toBe(1)
		expect(f.Weapons.getWeapons(f.me)[1].id).toBe("Brick")
		expect(XP.getOrbCount()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
