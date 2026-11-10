--!strict
-- Complete native starting choices, personal package rules and original unlock challenge in production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Lucky")
describe("Native Lucky package", function()
	it("runs all25 starts with no extra equipment", function()
		f.starts(25)
	end)
	it("uses original initial Luck, Luck gains, attack speed and XP", function()
		f.start("BrassKnuckles")
		expect(f.Stats.getStat(f.me, "luck")).toBe(125)
		expect(f.Stats.getStat(f.me, "attackSpeed")).toBe(-60)
		expect(f.Stats.getStat(f.me, "xpGain")).toBe(-50)
		f.Stats.addStats(f.me, { luck = 4 })
		expect(f.Stats.getStat(f.me, "luck")).toBe(130)
		expect(f.Stats.getStat(f.peer, "luck")).toBe(0)
	end)
	it("strikes once per personal material object using75% chance and15% Luck", function()
		f.start("BrassKnuckles")
		for _, w in f.Weapons.getWeapons(f.me) do
			f.Weapons.removeWeapon(f.me, w.uid)
		end
		local E = require(f.S.EnemySim)
		local p = f.me.Character.HumanoidRootPart.Position
		local id = assert(E.spawn("Brute", p.X + 30, p.Z, 1000, 0, nil, nil, 0))
		local R = require(f.S.RandomService)
		local old = R.number
		R.number = function(channel, player)
			return if channel == "Combat" then 0 else old(channel, player)
		end
		f.Weapons.setPaused(false)
		local before = E.getHealth(id)
		require(f.S.ExperienceService).OrbsPickedUp:Fire(f.me, 2)
		f.world.advance(0.1)
		expect(before - E.getHealth(id)).toBe(36)
		R.number = function(channel, player)
			return if channel == "Combat" then 0.75 else old(channel, player)
		end
		before = E.getHealth(id)
		require(f.S.ExperienceService).OrbsPickedUp:Fire(f.me, 1)
		f.world.advance(0.1)
		expect(E.getHealth(id)).toBe(before)
		R.number = old
	end)
	it("unlocks at300 personal material objects", function()
		local A = require(f.Shared.Util.CharacterAccess)
		f.Data.get(f.peer).nativeCounts.materialsCollected = 298
		f.Data.observeNativeMaterials(f.peer, 1)
		expect(A.characterUnlocked(f.Data.get(f.peer), "Lucky")).toBe(false)
		f.Data.observeNativeMaterials(f.peer, 1)
		expect(A.characterUnlocked(f.Data.get(f.peer), "Lucky")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
