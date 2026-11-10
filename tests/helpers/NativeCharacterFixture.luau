--!strict
-- Shared production-service fixture for native character package tests; artwork/unlock overrides exist only here.
return function(classId: string, beforeServer: ((any) -> ())?)
	local world = loadHelper("tests/helpers/RobloxMock.luau")
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Config = require(Shared.Config)
	local Server = game:GetService("ServerScriptService").Server
	if beforeServer then
		beforeServer(Server)
	end
	runScript(Server, "init.server.luau")
	local S = Server.Services
	local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
	local Data = require(S.PlayerDataService)
	local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
	world.advance(0.5)
	local public = Config.Classes[classId]
	local wasLegacy = public.pendingNative ~= nil
	local originalName, originalAvailable = public.displayName, public.available
	local class = public.pendingNative or public
	if wasLegacy then
		assert(
			require(Shared.Util.CharacterArtwork).promote(
				public,
				class,
				{ image = "rbxassetid://123", height = 0.9, ground = 0.04, center = 0.5, nativeVersion = "1.2.0.1" }
			)
		)
		class = public
	end
	class.available = true
	for _, id in class.startWeapons do
		assert(Config.Weapons[id], id).available = true
	end
	Data.unlockAll(me)
	Run.setHoldWaves(true)
	Weapons.setPaused(true)
	require(S.StructureService).setPaused(true)
	require(S.SpawnDirector).setPaused(true)
	local fixture = {
		world = world,
		Shared = Shared,
		Config = Config,
		S = S,
		Run = Run,
		Stats = Stats,
		Weapons = Weapons,
		Data = Data,
		me = me,
		peer = peer,
		class = class,
		wasLegacy = wasLegacy,
		originalName = originalName,
		originalAvailable = originalAvailable,
	}
	function fixture.start(id: string)
		if Run.isOngoing() then
			Run.endRun("Abandoned")
		end
		if Run.getPhase() == "Ended" then
			world.advance(Config.Run.flow.resultsSeconds + 0.1)
		end
		assert(Run.selectClass(me, classId))
		assert(Weapons.selectStartWeapon(me, classId, id))
		assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		require(S.SpawnDirector).setPaused(true)
		require(S.EnemySim).killAll()
	end
	function fixture.starts(count: number, expectedItems: { [string]: number }?)
		expect(#class.startWeapons).toBe(count)
		for _, id in class.startWeapons do
			fixture.start(id)
			local selected = Weapons.getWeapons(me)
			expect(#selected).toBe(1)
			expect(selected[1].id).toBe(id)
			expect(selected[1].tier).toBe(class.startWeaponTiers[id])
			local items = Stats.getItemCounts(me)
			for ident, amount in expectedItems or {} do
				expect(items[ident]).toBe(amount)
			end
			for ident, amount in items do
				expect(amount).toBe((expectedItems or {})[ident])
			end
		end
	end
	function fixture.nextWave()
		Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
		world.advance(0.1)
		for _, player in { me, peer } do
			world.fireServerAs(player, "SetShopReady", true)
		end
		world.advance(1)
		require(S.SpawnDirector).setPaused(true)
		require(S.EnemySim).killAll()
	end
	return fixture
end
