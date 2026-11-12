--!strict
-- Wounded's original 33 starts, Tardigrade, one-hit behavior, personal unlock and item/upgrade exclusions through production code.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Wounded")
local Combat = require(f.S.CombatService)
local Access = require(f.Shared.Util.CharacterAccess)
local Records = require(f.S.PlayerDataService.ProfileRecords)
local Template = require(f.S.PlayerDataService.ProfileTemplate)
describe("Native Wounded package", function()
	it("equips all33 original alternatives with one guaranteed Tardigrade", function()
		expect(f.class.nativeCodeReady).toBe(true)
		f.starts(33, { MossWard = 1 })
		expect(f.Stats.getStat(f.me, "speed")).toBe(5)
		expect(f.Stats.getStat(f.me, "harvesting")).toBe(8)
	end)
	it("blocks one hit per wave, then loses all HP from the smallest unblocked hit", function()
		f.start("RitualDirk")
		f.Weapons.setPaused(true)
		local full = Combat.getHp(f.me)
		local taken, dodged, blocked = Combat.damagePlayer(f.me, 0.01)
		expect(taken).toBe(0)
		expect(dodged).toBe(false)
		expect(blocked).toBe(true)
		expect(Combat.getHp(f.me)).toBe(full)
		f.nextWave()
		f.Weapons.setPaused(true)
		local _, _, second = Combat.damagePlayer(f.me, 0.01)
		expect(second).toBe(true)
		f.world.advance(1)
		f.Stats.addStats(f.me, { armor = 1000, maxHp = 100 })
		local hp = Combat.getHp(f.me)
		expect(Combat.damagePlayer(f.me, 0.01)).toBe(hp)
		expect(f.Run.getParticipantState(f.me)).toBe("Down")
		expect(f.Run.getParticipantState(f.peer)).toBe("Alive")
	end)
	it("preserves native one-hit lethal self-damage while allowing shields to absorb it", function()
		f.start("RitualDirk")
		expect(Combat.drainPlayer(f.me, 0.01)).toBe(0)
		local hp = Combat.getHp(f.me)
		expect(Combat.drainPlayer(f.me, 0.01)).toBe(hp)
		expect(f.Run.getParticipantState(f.me)).toBe("Down")
	end)
	it("requires an actual completed native Nightmare win and preserves the unlock", function()
		local data = Template.new()
		data.stats.bestDanger = 6 -- legacy aggregates alone do not prove the native result
		expect(Access.characterUnlocked(data, "Wounded")).toBe(false)
		local function finish(extra)
			local run = {
				won = true,
				wave = 20,
				danger = 6,
				zoneId = 0,
				classId = "Baby",
				kills = 0,
				bossKills = 2,
				seconds = 1200,
			}
			for key, value in extra or {} do
				run[key] = value
			end
			Records.applyRun(data, run)
		end
		for _, extra in { { won = false }, { wave = 19 }, { firstNight = true }, { danger = 5 }, { zoneId = 99 } } do
			finish(extra)
			expect(Access.characterUnlocked(data, "Wounded")).toBe(false)
		end
		finish(nil)
		expect(Access.characterUnlocked(data, "Wounded")).toBe(true)
		finish({ won = false })
		expect(Access.characterUnlocked(data, "Wounded")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
	it(
		"filters original health-focused items and four upgrade stats before endless, without banning mixed damage items",
		function()
			local Shop = require(f.S.ShopService.ShopRules)
			for _, id in { "Vitality", "Armor", "BoneKnuckles", "MothWing" } do
				expect(Shop.itemAllowed("Wounded", id, 19)).toBe(false)
			end
			expect(Shop.itemAllowed("Wounded", "Might", 19)).toBe(true)
			expect(Shop.itemAllowed("Wounded", "Armor", 20)).toBe(true)
			local Pool = require(f.S.UpgradeService.UpgradePool)
			local function stats(wave)
				local result = {}
				for _, card in
					Pool.roll({
						classId = "Wounded",
						wave = wave,
						level = 2,
						luck = 0,
						cardCount = 99,
						random = function()
							return 0
						end,
					})
				do
					result[card.stat] = true
				end
				return result
			end
			local before, endless = stats(19), stats(20)
			for _, id in { "maxHp", "hpRegen", "lifeSteal", "armor" } do
				expect(before[id]).toBe(nil)
				expect(endless[id]).toBe(true)
			end
			expect(before.damage).toBe(true)
		end
	)
end)
