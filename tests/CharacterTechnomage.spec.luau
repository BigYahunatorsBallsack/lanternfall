--!strict
-- Technomage's complete equipment choices, source-count conversions, XP costs and personal unlock.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Data, Structures, Experience =
	require(S.PlayerDataService), require(S.StructureService), require(S.ExperienceService)
local Access = require(Shared.Util.CharacterAccess)
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
local techno = Config.Classes.Technomage
techno.available = true -- only this isolated fixture bypasses original artwork
for _, id in techno.startWeapons do
	assert(Config.Weapons[id], id).available = true
end
Data.unlockAll(me)
Run.setHoldWaves(true)
local function start(id)
	if Run.isOngoing() then
		Run.endRun("Abandoned")
	end
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
	end
	assert(Run.selectClass(me, "Technomage"))
	assert(Weapons.selectStartWeapon(me, "Technomage", id))
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	require(S.SpawnDirector).setPaused(true)
	Weapons.setPaused(true)
	require(S.EnemySim).killAll()
end
describe("Native Technomage", function()
	it("runs all twelve starts with two guaranteed Turrets and +75% level cost", function()
		for _, id in techno.startWeapons do
			start(id)
			expect(#Weapons.getWeapons(me)).toBe(1)
			expect(Weapons.getWeapons(me)[1].id).toBe(id)
			expect(Stats.getItemCounts(me).BrassSentry).toBe(2)
			expect(Experience.getProgress(me).needed).toBe(28)
			expect(Experience.getProgress(peer).needed).toBe(16)
		end
	end)
	it(
		"converts equipped source count to Elemental Damage and permanent Elemental Damage to structure speed",
		function()
			start("Awl")
			expect(Structures.sourceCount(me)).toBe(3)
			expect(Stats.getStat(me, "elementalDamage")).toBe(6)
			expect(Stats.getStat(me, "structureAttackSpeed")).toBe(0)
			assert(Stats.addStats(me, { elementalDamage = 4, meleeDamage = 10, rangedDamage = 10 }))
			expect(Stats.getStat(me, "elementalDamage")).toBe(10)
			expect(Stats.getStat(me, "structureAttackSpeed")).toBe(20)
			expect(Stats.getStat(me, "meleeDamage")).toBe(0)
			expect(Stats.getStat(me, "rangedDamage")).toBe(0)
			Weapons.NativeMineRequested:Fire(me, Vector3.new(2, 0, 2))
			world.advance(0.2)
			expect(Stats.getStat(me, "elementalDamage")).toBe(10)
			expect(Stats.getStat(peer, "elementalDamage")).toBe(0)
		end
	)
	it("unlocks only when both personal conditions are met simultaneously, excluding loose mines", function()
		local data = Data.get(peer)
		local key = Access.challengeKey(require(Shared.Config.CharacterUnlocks).Technomage.challengeId)
		data.achievements[key] = nil
		expect(Access.characterUnlocked(data, "Technomage")).toBe(false)
		assert(Stats.addStats(peer, { elementalDamage = 10 }))
		Weapons.NativeMineRequested:Fire(peer, Vector3.new(1, 0, 1))
		world.advance(0.2)
		expect(Access.characterUnlocked(data, "Technomage")).toBe(false)
		for _ = 1, 3 do
			assert(Stats.addItem(peer, "BrassSentry"))
		end
		world.advance(0.2)
		expect(Access.characterUnlocked(data, "Technomage")).toBe(true)
		expect(#world.errors).toBe(0)
	end)
end)
