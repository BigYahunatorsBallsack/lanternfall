--!strict
-- Neutral Enigmacursor fires real delayed pillars; evolution variants and a playable Jungle area remain open.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Pillars = require(f.S.NativePillarService)
local C = require(f.Shared.Config.JungleWalkers).shootingRules
local Map = require(f.S.MapService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
Map.setMovementCheck(false)
for _, player in { f.me, f.peer } do
	require(f.S.CombatService).protect(player, 10000)
end
f.peer.Character.HumanoidRootPart.Position = Vector3.new(-90, 100, -60)
local function restart()
	f.start("WatchmanPistol")
	f.Weapons.setPaused(true)
	for _, player in { f.me, f.peer } do
		require(f.S.CombatService).protect(player, 10000)
	end
end
local function source()
	local at = Map.getRootPosition(f.me)
	return assert(Enemy.spawn("Enigmacursor", at.X + 35, at.Z, 100, 0, nil, nil, 0)), at
end
describe("Native neutral Jungle shooter", function()
	it("uses source pillar animation and two volleys before its long cooldown", function()
		local at = Map.getRootPosition(f.me)
		assert(Enemy.spawn("Enigmacursor", at.X + 35, at.Z, 100, 1, nil, nil, 0))
		local speeds = {}
		local connection = Enemy.NativePillar:Connect(function(_, _, _, _, _, speed)
			table.insert(speeds, speed)
		end)
		f.world.advance(0.3, 1 / 60)
		expect(#speeds).toBe(0)
		f.world.advance(0.7, 1 / 60)
		expect(#speeds).toBe(4)
		expect(speeds[1]).toBe(60)
		expect(speeds[2]).toBe(58)
		f.world.advance(2, 1 / 60)
		expect(#speeds).toBe(4)
		connection:Disconnect()
		expect(C.pillar.hitFrom).toBe(0.54)
		expect(C.pillar.hitUntil).toBe(0.68)
		expect(C.animationFireAt).toBe(0.4)
		expect(C.animationSeconds).toBe(0.4)
	end)
	it("preserves the source volley and owner after a real Charm conversion", function()
		restart()
		local at = Map.getRootPosition(f.me)
		local id = assert(Enemy.spawn("Enigmacursor", at.X + 35, at.Z, 100, 1, nil, nil, 0))
		Enemy.damage(id, 1, nil)
		assert(Enemy.tryCharm(f.me, id, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end))
		assert(Enemy.spawn("Brute", at.X, at.Z, 1000, 0, nil, nil, 0))
		local count = 0
		local connection = Enemy.NativePillar:Connect(function(source, _, _, _, _, _, _, owner)
			if source == id then
				expect(owner).toBe(f.me.UserId)
				count += 1
			end
		end)
		f.world.advance(1.2, 1 / 60)
		connection:Disconnect()
		expect(count).toBe(4)
		expect(#f.world.errors).toBe(0)
	end)
	it("does not hit early, stops at the first hit and persists after source deletion", function()
		restart()
		local id, at = source()
		local hits = 0
		local connection = Enemy.ShotHit:Connect(function(player, damage)
			if player == f.me then
				hits += 1
				expect(damage).toBe(5)
			end
		end)
		Enemy.NativePillar:Fire(id, at.X, at.Z, 1, 0, 0, 5, nil)
		Enemy.remove(id)
		f.world.advance(0.53, 1 / 60)
		expect(hits).toBe(0)
		f.world.advance(0.1, 1 / 60)
		expect(hits).toBe(1)
		f.world.advance(0.5, 1 / 60)
		expect(hits).toBe(1)
		expect(Pillars.getCount()).toBe(0)
		connection:Disconnect()
	end)
	it("keeps friendly pillars off players and damages a real hostile without personal kill credit", function()
		restart()
		local id, at = source()
		local target = assert(Enemy.spawn("Brute", at.X, at.Z, 0.001, 0, nil, nil, 0))
		local before = f.Data.get(f.me).nativeCounts.enemiesKilled
		Enemy.NativePillar:Fire(id, at.X, at.Z, 1, 0, 0, 999, f.me.UserId)
		f.world.advance(0.65, 1 / 60)
		expect(Enemy.isAlive(target)).toBe(false)
		expect(f.Data.get(f.me).nativeCounts.enemiesKilled).toBe(before)
		f.Run.endRun("Abandoned")
		expect(Pillars.getCount()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
