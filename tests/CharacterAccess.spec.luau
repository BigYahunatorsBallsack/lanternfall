--!strict
-- Stable native weapon unlock conditions replace invented weapon locks while retaining saved wins and flags.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Util.CharacterAccess)
local Access = require(Shared.Config.CharacterWeaponAccess)

describe("Native weapon access", function()
	it("keeps original default weapons free and Claw locked without the required win", function()
		expect(Rules.weaponUnlocked(nil, "TithePalm")).toBe(true)
		expect(Rules.weaponUnlocked(nil, "WatchmanPistol")).toBe(true)
		expect(Rules.weaponUnlocked(nil, "Claw")).toBe(false)
		expect(Rules.weaponUnlocked(nil, "Unknown")).toBe(false)
	end)

	it("reads the original character win rather than unrelated legacy achievements", function()
		local data = { achievements = { Regular = true }, characterStats = {} }
		expect(Rules.weaponUnlocked(data, "Claw")).toBe(false)
		data.characterStats.Cryptid = { wins = 1 }
		expect(Rules.weaponUnlocked(data, "Claw")).toBe(true)
		expect(Rules.weaponUnlocked(data, "Chopper")).toBe(false)
		data.characterStats.ManyHands = { wins = 1 }
		expect(Rules.weaponUnlocked(data, "Chopper")).toBe(true)
	end)

	it("retains completed native challenge flags independently of current run stats", function()
		local data = { achievements = {}, characterStats = {} }
		expect(Access.VorpalSword.stat).toBe("critChance")
		expect(Access.VorpalSword.threshold).toBe(100)
		data.achievements[Rules.challengeKey(Access.VorpalSword.challengeId)] = true
		expect(Rules.weaponUnlocked(data, "VorpalSword")).toBe(true)
	end)

	it("records access for every current weapon and all required additional starting families", function()
		local count, locked = 0, 0
		for _, rule in Access do
			count += 1
			if not rule.free then
				locked += 1
				assert(rule.challengeId)
			end
		end
		expect(count).toBe(91)
		expect(locked).toBe(25)
		for id in Config.Weapons do
			assert(Access[id], id)
		end
	end)
	it("keeps native character access locked until its challenge or an explicit saved grant", function()
		expect(Rules.characterUnlocked(nil, "Brawler")).toBe(true)
		expect(Rules.characterUnlocked(nil, "Crazy")).toBe(true)
		expect(Rules.characterUnlocked(nil, "Ghost")).toBe(false)
		expect(Rules.characterUnlocked(nil, "Unknown")).toBe(false)
		local data = { achievements = {}, characterStats = {}, classes = {} }
		data.achievements[Rules.challengeKey("chal_hallucination")] = true
		expect(Rules.characterUnlocked(data, "Ghost")).toBe(true)
		table.clear(data.achievements)
		table.insert(data.classes, "Ghost")
		expect(Rules.characterUnlocked(data, "Ghost")).toBe(true)
	end)
end)
