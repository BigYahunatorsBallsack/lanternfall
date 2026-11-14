--!strict
-- Original Whip/Jungle lifetime counter through real weapon hits; a test-only area override isolates this rule and does not claim a playable Jungle area.
local store
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded", function(server)
	local S = server.Services
	store = require(S.PlayerDataService.MemoryStore).new(require(S.PlayerDataService.ProfileTemplate).new())
	require(S.PlayerDataService).useStore(store)
end)
local Enemy = require(f.S.EnemySim)
local Combat = require(f.S.CombatService)
local Access = require(f.Shared.Util.CharacterAccess)
local Template = require(f.S.PlayerDataService.ProfileTemplate)
local Migrations = require(f.S.PlayerDataService.Migrations)
local zone = 0
f.Run.getNativeZoneId = function()
	return zone
end
local function start(id)
	f.start(id)
	f.Weapons.setPaused(true)
	for _, player in { f.me, f.peer } do
		Combat.protect(player, 10000)
	end
end
local function target(kind)
	local at = f.me.Character.HumanoidRootPart.Position
	return assert(Enemy.spawn(kind or "Brute", at.X + 12, at.Z, 0.001, 0, nil, nil, 0))
end
local function strike()
	f.Weapons.setPaused(false)
	f.world.advance(1.5, 1 / 60)
	f.Weapons.setPaused(true)
end
describe("Native Whip Jungle progress", function()
	it("adds a new counter without inventing historical Whip kills", function()
		local data = Template.new()
		data.schemaVersion = 14
		data.nativeCounts = { materialsCollected = 15, enemiesKilled = 20000, digSitesDug = 8, treesKilled = 9 }
		data.nativeZoneBest.Wildling = { ["2"] = 5 }
		Migrations.run(data, Template.SCHEMA_VERSION)
		expect(data.schemaVersion).toBe(15)
		expect(data.nativeCounts.whipJungleKills).toBe(0)
		expect(data.nativeCounts.enemiesKilled).toBe(20000)
		expect(data.nativeCounts.materialsCollected).toBe(15)
		expect(data.nativeCounts.digSitesDug).toBe(8)
		expect(data.nativeZoneBest.Wildling["2"]).toBe(5)
	end)
	it("does not count Whip kills outside the real Jungle id or kills with another weapon", function()
		start("Whip")
		local data = f.Data.get(f.me)
		data.achievements[Access.challengeKey("chal_whip_it")] = nil
		data.nativeCounts.whipJungleKills = 199
		zone = 0
		local id = target()
		strike()
		expect(Enemy.isAlive(id)).toBe(false)
		expect(data.nativeCounts.whipJungleKills).toBe(199)
		start("WatchmanPistol")
		zone = 2
		id = target()
		strike()
		expect(Enemy.isAlive(id)).toBe(false)
		expect(data.nativeCounts.whipJungleKills).toBe(199)
		expect(Access.weaponUnlocked(data, "Flail")).toBe(false)
	end)
	it("excludes trees, cleanup and unrelated damage while retaining the personal count", function()
		start("Whip")
		zone = 2
		local tree = target("Tree")
		strike()
		expect(Enemy.isAlive(tree)).toBe(false)
		local id = target()
		Enemy.damage(id, 10000, f.peer)
		target()
		Enemy.killAll()
		expect(f.Data.get(f.me).nativeCounts.whipJungleKills).toBe(199)
		expect(f.Data.get(f.peer).nativeCounts.whipJungleKills).toBe(0)
	end)
	it("credits the actual Whip hit even if its kill synchronously ends and clears the run", function()
		start("Whip")
		zone = 2
		local terminal = false
		Enemy.EnemyKilled:Connect(function(info)
			if not terminal and info.killer == f.me then
				terminal = true
				assert(f.Run.endRun("Victory"))
			end
		end)
		target()
		strike()
		expect(terminal).toBe(true)
		expect(f.Data.get(f.me).nativeCounts.whipJungleKills).toBe(200)
		expect(Access.weaponUnlocked(f.Data.get(f.me), "Flail")).toBe(true)
		expect(Access.weaponUnlocked(f.Data.get(f.peer), "Flail")).toBe(false)
		expect(#f.world.errors).toBe(0)
	end)
	it("saves the personally earned threshold and restores the weapon unlock in a new session", function()
		f.world.removePlayer(f.me)
		expect(store.saved["Player_1"].nativeCounts.whipJungleKills).toBe(200)
		local again = f.world.addPlayer("OwnerAgain", 1, true)
		f.world.advance(0.5)
		expect(f.Data.get(again).nativeCounts.whipJungleKills).toBe(200)
		expect(Access.weaponUnlocked(f.Data.get(again), "Flail")).toBe(true)
		expect(f.Data.get(f.peer).nativeCounts.whipJungleKills).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
