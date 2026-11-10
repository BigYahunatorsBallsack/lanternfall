--!strict
-- Original Renegade starts, actual owner weapon sheets, distinct common items and personal challenge completion.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Data = require(S.PlayerDataService)
local Access = require(Shared.Util.CharacterAccess)
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
local class = Config.Classes.Renegade
class.available = true -- isolated fixture; production still requires genuine uploaded original artwork
for _, id in class.startWeapons do
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
	assert(Run.selectClass(me, "Renegade"))
	assert(Weapons.selectStartWeapon(me, "Renegade", id))
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	require(S.SpawnDirector).setPaused(true)
	Weapons.setPaused(true)
	require(S.EnemySim).killAll()
end
local function commonItems()
	local items = {}
	for _, item in Config.Items.list do
		if
			item.tier == 1
			and not item.stats.damage
			and not item.stats.explosionDamage
			and (not item.effects or #item.effects == 0)
		then
			table.insert(items, item.id)
		end
	end
	assert(#items >= 10, "fixture requires ten distinct common items without damage effects")
	return items
end
describe("Native Renegade", function()
	it("runs all twenty-three starts with source projectile counts, accuracy and piercing", function()
		expect(#class.startWeapons).toBe(23)
		for _, id in class.startWeapons do
			start(id)
			local selected = Weapons.getWeapons(me)
			expect(#selected).toBe(1)
			expect(selected[1].id).toBe(id)
			expect(selected[1].tier).toBe(class.startWeaponTiers[id])
			expect(next(Stats.getItemCounts(me))).toBe(nil)
			expect(Stats.getStat(me, "damage")).toBe(-80)
			expect(Stats.getStat(me, "accuracy")).toBe(-50)
			local actual = require(S.WeaponService.WeaponStats).compute(
				Config.Weapons[id],
				selected[1].tier,
				Weapons.getStructureStats(me),
				nil,
				0
			)
			local base = require(S.WeaponService.WeaponStats).compute(
				Config.Weapons[id],
				selected[1].tier,
				{ nativePackage = 1 },
				nil,
				0
			)
			expect(actual.count).toBe(base.count + 2)
			expect(actual.nativeAccuracy).toBeNear(base.nativeAccuracy - 0.5)
			expect(actual.nativeSpread).toBeNear(base.nativeSpread + 0.2)
			expect(actual.pierce).toBe(base.pierce + 1)
		end
	end)
	it("counts each common item once and applies the reduced damage gain only to its owner", function()
		start("WatchmanPistol")
		local items = commonItems()
		for index = 1, 10 do
			assert(Stats.addItem(me, items[index]))
			world.advance(0.1)
			expect(Stats.getStat(me, "damage")).toBeNear(-80 + index * 2)
		end
		assert(Stats.addItem(me, items[1]))
		world.advance(0.1)
		expect(Stats.getStat(me, "damage")).toBeNear(-60)
		expect(Stats.getStat(peer, "damage")).toBe(0)
		assert(Stats.addStats(me, { damage = 10, explosionDamage = 10 }))
		expect(Stats.getStat(me, "damage")).toBeNear(-58)
		expect(Stats.getStat(me, "explosionDamage")).toBeNear(2)
	end)
	it("unlocks personally at ten different common items and excludes duplicates", function()
		start("WatchmanPistol")
		local data = Data.get(peer)
		data.achievements[Access.challengeKey(require(Shared.Config.CharacterUnlocks).Renegade.challengeId)] = nil
		local items = commonItems()
		for index = 1, 9 do
			assert(Stats.addItem(peer, items[index]))
		end
		assert(Stats.addItem(peer, items[1]))
		world.advance(0.2)
		expect(Access.characterUnlocked(data, "Renegade")).toBe(false)
		assert(Stats.addItem(peer, items[10]))
		world.advance(0.2)
		expect(Access.characterUnlocked(data, "Renegade")).toBe(true)
		expect(#world.errors).toBe(0)
	end)
end)
