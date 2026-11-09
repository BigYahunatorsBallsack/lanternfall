--!strict
-- Artificer's full native start choices, local stats and one-explosion Fireworks unlock through real services.
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
local originalAvailability = Config.Classes.Artificer.available
Config.Classes.Artificer.available = true
Config.Weapons.StickyGrenade.available = true
require(S.SpawnDirector).setPaused(true)
require(S.ExperienceService).setPaused(true)
require(S.LootService).setDropsPaused(true)
Run.setHoldWaves(true)
local function protect()
	Enemy.killAll()
	require(S.CombatService).protect(me, 10000)
	require(S.CombatService).protect(peer, 10000)
	peer.Character.HumanoidRootPart.Position = Vector3.new(200, 0, 200)
end
local function start(id)
	if Run.isOngoing() then
		Run.endRun("Abandoned")
	end
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
	end
	assert(Run.selectClass(me, "Artificer"))
	assert(Weapons.selectStartWeapon(me, "Artificer", id))
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	protect()
end
local function spawn(player, kind, hp, x, z)
	local at = player.Character.HumanoidRootPart.Position
	return assert(Enemy.spawn(kind, at.X + (x or 10), at.Z + (z or 0), hp or 100, 1, nil, nil, 0))
end
local function blast(player, count)
	Enemy.killAll()
	for i = 1, count do
		spawn(player, "Shadeling", 0.1, (i % 5) * 0.1, math.floor(i / 5) * 0.1)
	end
	local position = player.Character.HumanoidRootPart.Position
	assert(
		Weapons.explodeCharacter(
			player,
			require(Shared.Config.CharacterExplosions).bySource["res://items/characters/bull/bull_explosion_stats.tres"],
			position
		)
	)
end
describe("Native Artificer package", function()
	it("unlocks only for a single explosion killing fifteen, with personal ownership", function()
		expect(Config.Classes.Artificer.nativeCodeReady).toBe(true)
		expect(originalAvailability).toBe(false)
		expect(Run.selectClass(me, "Artificer")).toBe(false)
		assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		protect()
		for _, p in { me, peer } do
			for _, w in Weapons.getWeapons(p) do
				Weapons.removeWeapon(p, w.uid)
			end
		end
		blast(me, 14)
		blast(me, 1)
		expect(Data.isUnlocked(me, "characters", "Artificer")).toBe(false)
		blast(peer, 15)
		expect(Data.isUnlocked(peer, "characters", "Artificer")).toBe(true)
		expect(Data.isUnlocked(me, "characters", "Artificer")).toBe(false)
		blast(me, 15)
		expect(Data.isUnlocked(me, "characters", "Artificer")).toBe(true)
	end)
	it("starts and attacks with every original weapon", function()
		for _, id in { "Plank", "RuneAwl", "FoundryKey", "ShrapnelOrgan", "StickyGrenade" } do
			start(id)
			expect(Weapons.getWeapons(me)[1].id).toBe(id)
			expect(Stats.getStat(me, "damage")).toBe(-100)
			expect(Stats.getStat(me, "explosionDamage")).toBe(175)
			local enemy = spawn(me, "Brute", 100, 10)
			local hp = Enemy.getHealth(enemy)
			world.advance(3.5)
			expect(Enemy.getHealth(enemy) < hp).toBe(true)
			expect(Weapons.getDamageStats(me)[id].damage > 0).toBe(true)
		end
	end)
	it("adds size from Elemental Damage and halves only the owner's Armor gains", function()
		assert(Stats.addStats(me, { elementalDamage = 5, armor = 4 }))
		expect(Stats.getStat(me, "explosionSize")).toBe(20)
		expect(Stats.getStat(me, "armor")).toBe(2)
		expect(Stats.getStat(peer, "armor")).toBe(0)
		expect(Weapons.getWeapons(me)[1].stats.explosionRadius).toBeNear(14.734 * 1.1 * 1.2)
	end)
	it("has no contact hit and damages the attached target and its neighbor only after the fuse", function()
		start("StickyGrenade")
		assert(Stats.addStats(me, { critChance = -100, lifeSteal = 100 }))
		require(S.CombatService).drainPlayer(me, 4)
		local ownHp = require(S.CombatService).getHp(me)
		local first = spawn(me, "Brute", 100, 10, 0)
		local second = spawn(me, "Brute", 100, 10, 5)
		local a, b = Enemy.getHealth(first), Enemy.getHealth(second)
		world.advance(0.5)
		expect(Enemy.getHealth(first)).toBe(a)
		expect(Enemy.getHealth(second)).toBe(b)
		world.advance(0.65)
		expect(a - Enemy.getHealth(first)).toBe(14)
		expect(b - Enemy.getHealth(second)).toBe(14)
		expect(require(S.CombatService).getHp(me)).toBe(ownHp)
		expect(#world.errors).toBe(0)
	end)
	it("awards Fireworks from one real delayed grenade and preserves it through retry", function()
		start("StickyGrenade")
		local key = require(Shared.Util.CharacterAccess).challengeKey("chal_fireworks")
		Data.get(me).achievements[key] = nil
		for i = 1, 15 do
			spawn(me, "Shadeling", 0.1, 10 + (i % 5) * 0.1, math.floor(i / 5) * 0.1)
		end
		world.advance(1.2)
		expect(Data.isUnlocked(me, "characters", "Artificer")).toBe(true)
		Run.endRun("Defeat")
		assert(Run.retryWave(me))
		expect(Data.isUnlocked(me, "characters", "Artificer")).toBe(true)
	end)
end)
