--!strict
-- Native Hiking Stick tier facts and actual displacement milestones; intent/wall pushing alone cannot generate Range.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Entrepreneur")
local Steps = require(f.S.CharacterService.Steps)
describe("Native Hiking Stick", function()
	it("uses all four source tiers and their70/60/50/40step thresholds", function()
		local Compute = require(f.S.WeaponService.WeaponStats).compute
		for tier, period in { 70, 60, 50, 40 } do
			local stats = Compute(f.Config.Weapons.HikingStick, tier, {}, nil, f.Config.Player.minWeaponCooldown)
			expect(stats.stepEvery).toBe(period)
			expect(stats.stepRangeGain).toBe(1)
			expect(stats.damage).toBe(6 + 6 * tier)
		end
	end)
	it("counts13.5stud per native step and uses the wave's step milestones for every equipped copy", function()
		f.start("HikingStick")
		f.Weapons.removeWeapon(f.me, f.Weapons.getWeapons(f.me)[1].uid)
		assert(f.Weapons.addWeapon(f.me, "HikingStick", 4))
		local root = f.me.Character.HumanoidRootPart
		local origin = root.Position
		local peerRange = f.Stats.getStat(f.peer, "range")
		f.world.fireServerAs(f.me, "SetMovementIntent", true)
		f.world.advance(0.3)
		expect(Steps.getCount(f.me)).toBeNear(0)
		local frame = 0
		local function walk(steps)
			for _ = 1, steps * 9 do
				frame += 1
				local offset = if frame % 60 < 30 then frame % 30 * 1.5 else (30 - frame % 30) * 1.5
				root.Position = Vector3.new(origin.X + offset, origin.Y, origin.Z)
				f.world.advance(1 / 15)
			end
		end
		walk(35)
		local before = f.Stats.getStat(f.me, "range")
		assert(f.Weapons.addWeapon(f.me, "HikingStick", 4))
		walk(6)
		expect(Steps.getCount(f.me) > 40).toBe(true)
		expect(f.Stats.getStat(f.me, "range")).toBe(before + 2)
		expect(f.Stats.getStat(f.peer, "range")).toBe(peerRange)
		local walked = Steps.getCount(f.me)
		task.spawn(function()
			require(f.S.MapService).placeCharacter(f.me, "Arena", 1, 2)
		end)
		f.world.advance(0.2)
		expect(Steps.getCount(f.me)).toBeNear(walked)
		f.Run.setParticipantState(f.me, "Down")
		f.Run.setParticipantState(f.peer, "Down")
		f.world.advance(0.1)
		assert(f.Run.retryWave(f.peer))
		expect(Steps.getCount(f.me)).toBeNear(0)
		expect(f.Stats.getStat(f.me, "range")).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
