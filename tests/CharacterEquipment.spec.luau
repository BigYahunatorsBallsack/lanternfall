--!strict
-- Authoritative acquisition and promotion paths must enforce the same character rules as shop offers.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Server = game:GetService("ServerScriptService").Server
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
runScript(Server, "init.server.luau")
local S = Server.Services
local Run = require(S.RunDirector)
local Weapons = require(S.WeaponService)
local Stats = require(S.StatService)
local Experience = require(S.ExperienceService)
local ShopRules = require(S.ShopService.ShopRules)
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
require(S.PlayerDataService).unlockAll(me)
world.fireServerAs(me, "SelectClass", "ManyHands")
world.advance(0.3)
assert(Run.setReady(me, true))
world.advance(3.5)
Run.setHoldWaves(true)
require(S.SpawnDirector).setPaused(true)
Weapons.setPaused(true)
require(S.EnemySim).killAll()
local class = Config.Classes.ManyHands

local function withRules(fields, check)
	local old = {}
	for key, value in fields do
		old[key] = class[key]
		class[key] = value
	end
	local ok, err = pcall(check)
	for key in fields do
		class[key] = old[key]
	end
	assert(ok, err)
end

describe("Character equipment service rules", function()
	it("blocks direct grants, upgrades and merges above the character tier", function()
		withRules({ maxWeaponTier = 2 }, function()
			local ok = Weapons.addWeapon(me, "RitualDirk", 3)
			expect(ok).toBe(false)
			local a, _, first = Weapons.addWeapon(me, "RitualDirk", 2)
			local b = Weapons.addWeapon(me, "RitualDirk", 2)
			assert(a and b and first)
			expect(Weapons.raiseTier(me, first)).toBe(false)
			expect(Weapons.merge(me, first)).toBe(false)
			local _, blocked = ShopRules.weaponStatus("RitualDirk", 3, Weapons.getWeapons(me), 12, 4, "ManyHands")
			expect(blocked).toBe(true)
		end)
	end)

	it("rejects extra copies while permitting a purchase that merges immediately", function()
		withRules({ noDuplicateWeapons = true }, function()
			expect(Weapons.addWeapon(me, "BrassKnuckles", 1)).toBe(false)
			local merges, blocked =
				ShopRules.weaponStatus("BrassKnuckles", 1, Weapons.getWeapons(me), 12, 4, "ManyHands")
			expect(merges).toBe(true)
			expect(blocked).toBe(false)
		end)
	end)

	it("changes slots only when the slot upgrade is granted, independently of reaching a level", function()
		for _, weapon in Weapons.getWeapons(me) do
			Weapons.removeWeapon(me, weapon.uid)
		end
		withRules({ baseWeaponSlots = 1, slotUpgradeAmount = 1, maxWeaponSlots = 24 }, function()
			expect(Weapons.getMaxWeapons(me)).toBe(1)
			assert(Weapons.addWeapon(me, "RitualDirk", 1))
			expect(Weapons.addWeapon(me, "BrassKnuckles", 1)).toBe(false)
			assert(Experience.grantLevel())
			expect(Weapons.getMaxWeapons(me)).toBe(1)
			assert(Stats.addUpgrade(me, "weaponSlots", 1))
			expect(Weapons.getMaxWeapons(me)).toBe(2)
			expect(Weapons.addWeapon(me, "BrassKnuckles", 1)).toBe(true)
		end)
	end)

	it("rejects equipment on all direct grant paths for a weaponless character", function()
		withRules({ maxWeapons = 0 }, function()
			expect(Weapons.addWeapon(me, "RitualDirk", 1)).toBe(false)
			local merges, blocked = ShopRules.weaponStatus("RitualDirk", 1, {}, 0, 4, "ManyHands")
			expect(merges).toBe(false)
			expect(blocked).toBe(true)
		end)
	end)
end)
