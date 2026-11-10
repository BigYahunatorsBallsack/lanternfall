--!strict
-- Boomerang attacks through the real Arsenal, preserves each attack until return and clears at wave/retry boundaries.
local current
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Lich", function(Server)
	local behavior = require(Server.Services.WeaponService.Behaviors.Boomerang)
	local originalFire = behavior.fire
	behavior.fire = function(weapon, ctx)
		current = weapon
		return originalFire(weapon, ctx)
	end
end)
local Enemy = require(f.S.EnemySim)
local Random = require(f.S.RandomService)
local oldRandom = Random.number
Random.number = function(channel, player)
	return if channel == "Combat" then 0.5 else oldRandom(channel, player)
end
local function prepare(tier)
	f.start("Boomerang")
	for _, player in { f.me, f.peer } do
		for _, w in f.Weapons.getWeapons(player) do
			f.Weapons.removeWeapon(player, w.uid)
		end
	end
	assert(f.Weapons.addWeapon(f.me, "Boomerang", tier))
	local p = f.me.Character.HumanoidRootPart.Position
	local id = assert(Enemy.spawn("Brute", p.X + 16, p.Z, 1000, 0, nil, nil, 0))
	local before = Enemy.getHealth(id)
	f.Weapons.setPaused(false)
	f.world.advance(0.1)
	return current, id, before
end
describe("Native Boomerang production combat", function()
	it("damages with every tier on both flight legs without piercing loss or an overlapping next attack", function()
		for tier, damage in { 6, 9, 12, 17 } do
			local weapon, id, before = prepare(tier)
			expect(#weapon.state.boomerangs).toBe(1)
			local serial = weapon.state.boomerangs[1].id
			f.world.advance(0.8)
			expect(weapon.state.boomerangs[1].id).toBe(serial)
			local elapsed = 0.9
			while #weapon.state.boomerangs > 0 and elapsed < 3 do
				f.world.advance(1 / 15)
				elapsed += 1 / 15
			end
			expect(#weapon.state.boomerangs).toBe(0)
			-- Lich's50% Melee gain penalty does not reduce unscaled base weapon damage.
			expect(before - Enemy.getHealth(id)).toBe(damage * 2)
			expect(weapon.damageDealt).toBe(damage * 2)
			f.Weapons.setPaused(true)
		end
	end)
	it("clears outstanding projectiles at the shop and restores an empty wave-start flight on retry", function()
		local weapon = prepare(1)
		expect(#weapon.state.boomerangs).toBe(1)
		f.Weapons.setPaused(true)
		f.Run.skipTo(require(f.Shared.Util.RunSchedule).wave(f.Run.getWave()).endsAt)
		expect(weapon.state.boomerangs).toBe(nil)
		f.world.advance(0.1)
		for _, p in { f.me, f.peer } do
			f.world.fireServerAs(p, "SetShopReady", true)
		end
		f.world.advance(1)
		local checkpointDamage = f.Weapons.getDamageStats(f.me).Boomerang.damage
		f.Run.setParticipantState(f.me, "Down")
		f.Run.setParticipantState(f.peer, "Down")
		f.world.advance(0.1)
		assert(f.Run.retryWave(f.peer))
		local tally = f.Weapons.getDamageStats(f.me)
		expect(tally.Boomerang.damage).toBe(checkpointDamage)
		expect(#f.world.errors).toBe(0)
	end)
end)
