--!strict
-- Wildling's personal lifetime unlock, original starts and tier cap through production services.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Enemy, Data = require(S.EnemySim), require(S.PlayerDataService)
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
local originalAvailability = Config.Classes.Wildling.available
Config.Classes.Wildling.available = true
Config.Weapons.Flail.available = true
Run.setHoldWaves(true)
require(S.SpawnDirector).setPaused(true)
require(S.ExperienceService).setPaused(true)
Weapons.setPaused(true)
local function start(class, id)
	if Run.isOngoing() then
		Run.endRun("Abandoned")
	end
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
	end
	assert(Run.selectClass(me, class))
	if id then
		assert(Weapons.selectStartWeapon(me, class, id))
	end
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	Enemy.killAll()
end
describe("Native Wildling package", function()
	it("migrates the new lifetime counter without altering existing material totals or grants", function()
		local data = require(S.PlayerDataService.ProfileTemplate).new()
		data.schemaVersion = 10
		data.nativeCounts = { materialsCollected = 456 }
		data.achievements.Existing = true
		require(S.PlayerDataService.Migrations).run(data, 11)
		expect(data.nativeCounts.materialsCollected).toBe(456)
		expect(data.nativeCounts.enemiesKilled).toBe(0)
		expect(data.achievements.Existing).toBe(true)
	end)
	it("requires 10000 credited enemy kills and excludes trees, cleanup and teammate kills", function()
		expect(Config.Classes.Wildling.nativeCodeReady == true).toBe(false)
		expect(originalAvailability).toBe(false)
		expect(Run.selectClass(me, "Wildling")).toBe(false)
		start("NightWatch")
		Data.get(me).nativeCounts.enemiesKilled = 9999
		local function kill(kind, owner)
			local id = assert(Enemy.spawn(kind, 15, 0, 1, 1, nil, nil, 0))
			Enemy.damage(id, 1000, owner)
		end
		kill("Tree", me)
		kill("Shadeling", peer)
		local id = assert(Enemy.spawn("Shadeling", 15, 0, 1, 1, nil, nil, 0))
		Enemy.killAll()
		expect(Enemy.getHealth(id)).toBe(0)
		expect(Data.isUnlocked(me, "characters", "Wildling")).toBe(false)
		kill("Shadeling", me)
		expect(Data.isUnlocked(me, "characters", "Wildling")).toBe(true)
		expect(Data.isUnlocked(peer, "characters", "Wildling")).toBe(false)
	end)
	it("starts with every original choice plus one Stick and applies lifesteal only to Primitive weapons", function()
		Data.unlockAll(me)
		for _, id in require(Shared.Config.CharacterCatalog).Wildling.startWeapons do
			start("Wildling", id)
			local weapons = Weapons.getWeapons(me)
			expect(#weapons).toBe(2)
			expect(weapons[1].id).toBe(id)
			expect(weapons[2].id).toBe("Stick")
			expect(weapons[2].stats.lifeSteal).toBeNear(0.3)
			expect(Stats.getStat(me, "lifeSteal")).toBe(0)
		end
		expect(Stats.getStat(peer, "lifeSteal")).toBe(0)
	end)
	it("damages real targets with the new Flail at both permitted tiers", function()
		for tier = 1, 2 do
			start("Wildling", "Flail")
			for _, weapon in Weapons.getWeapons(me) do
				Weapons.removeWeapon(me, weapon.uid)
			end
			assert(Weapons.addWeapon(me, "Flail", tier))
			local position = me.Character.HumanoidRootPart.Position
			local enemy = assert(Enemy.spawn("Brute", position.X + 10, position.Z, 100, 1, nil, nil, 0))
			local hp = Enemy.getHealth(enemy)
			Weapons.setPaused(false)
			world.advance(1.5)
			Weapons.setPaused(true)
			expect(Enemy.getHealth(enemy) < hp).toBe(true)
		end
	end)
	it("rejects tier III and IV grants and stops merges at tier II", function()
		expect(Weapons.addWeapon(me, "Stick", 3)).toBe(false)
		expect(Weapons.addWeapon(me, "Stick", 4)).toBe(false)
		expect(Weapons.addWeapon(me, "Stick", 2)).toBe(true)
		expect(Weapons.addWeapon(me, "Stick", 2)).toBe(true)
		local list = Weapons.getWeapons(me)
		expect(Weapons.merge(me, list[#list].uid)).toBe(false)
		expect(#world.errors).toBe(0)
	end)
end)
