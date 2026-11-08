--!strict
-- Real Bull/final-boss interaction regressions; stable main.gdc prioritizes no surviving players over boss death.
-- Native sources: main.gdc MD5 903bd37107ab9c164addda2167477fb1, player.gdc MD5 80ac166ba6b5c71fbf220bcd43ddc90e.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
Config.Classes.Bull.available = true -- fixture-only until code and sprite dependencies are complete
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run = require(S.RunDirector)
local Stats = require(S.StatService)
local Combat = require(S.CombatService)
local Enemy = require(S.EnemySim)
local Boss = require(S.BossService)
local Shop = require(S.ShopService)
local Schedule = require(Shared.Util.RunSchedule)
local Danger = require(Shared.Util.DangerRules)
local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.advance(0.5)
require(S.PlayerDataService).unlockAll(me)
assert(Run.selectClass(me, "Bull"))
require(S.SpawnDirector).setPaused(true)
require(S.WeaponService).setPaused(true)
require(S.ExperienceService).setPaused(true)
require(S.LootService).setDropsPaused(true)
Run.setHoldWaves(true)
Run.RunStarted:Connect(function()
	require(S.SpawnDirector).setPaused(true)
	require(S.WeaponService).setPaused(true)
	require(S.ExperienceService).setPaused(true)
end)
local settlements = 0
local results = {}
Run.WaveRewards:Connect(function()
	settlements += 1
end)
Run.RunEnded:Connect(function(result)
	table.insert(results, result)
end)

local function prepare(players)
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.5)
	end
	assert(Run.launch(players, Danger.defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	Enemy.killAll()
	for _, player in players do
		Stats.addStats(
			player,
			{ harvesting = 10 - Stats.getStat(player, "harvesting"), critChance = -100, maxHp = 10000 }
		)
	end
	assert(Run.skipTo(Schedule.wave(Schedule.waveCount() - 1).endsAt))
	for _, player in players do
		world.fireServerAs(player, "SetShopReady", true)
	end
	world.advance(Config.Enemies.bossWave.introSeconds + 0.5)
	expect(Run.getWave()).toBe(Schedule.waveCount())
	local bosses = Boss.getBosses()
	expect(#bosses).toBe(1)
	expect(bosses[1].wave).toBe(true)
	local id = bosses[1].id
	Enemy.damage(id, Enemy.getHealth(id) - 1, me)
	local root = me.Character.HumanoidRootPart.Position
	Enemy.teleport(id, Vector3.new(root.X + 5, root.Y, root.Z))
	-- Refresh the real spatial hash before the hurt event.
	world.advance(0.1)
	-- Pausing WeaponService also suppresses character explosions. Enable only at the tested hit.
	require(S.WeaponService).setPaused(false)
	return id
end

describe("Bull lethal final-boss interaction", function()
	it("kills the final boss on lethal hurt and settles a surviving co-op team once", function()
		local id = prepare({ me, peer })
		local paid, ended = settlements, #results
		Combat.drainPlayer(me, 1e9)
		expect(Enemy.isAlive(id)).toBe(false)
		expect(Run.getParticipantState(me)).toBe("Down")
		world.advance(0.2)
		expect(Run.getPhase()).toBe("Shop")
		expect(settlements).toBe(paid + 1)
		local gold = Shop.getShards(me)
		world.fireServerAs(me, "ChooseEndless", false)
		world.fireServerAs(peer, "ChooseEndless", false)
		world.advance(0.2)
		expect(Run.getPhase()).toBe("Ended")
		expect(#results).toBe(ended + 1)
		expect(results[#results].outcome).toBe("Victory")
		expect(settlements).toBe(paid + 1)
		expect(Shop.getShards(me)).toBe(gold)
		expect(Run.endRun("Victory")).toBe(false)
		expect(#world.errors).toBe(0)
	end)

	it("does not let a deferred boss callback pay or end a solo defeat a second time", function()
		local id = prepare({ me })
		local paid, ended = settlements, #results
		Combat.drainPlayer(me, 1e9)
		expect(Enemy.isAlive(id)).toBe(false)
		expect(Run.getPhase()).toBe("Ended")
		expect(#results).toBe(ended + 1)
		-- Native _on_player_died immediately cleans up when no player survives.
		-- _set_run_states treats the non-endless final wave as lost even if its last boss also dies.
		expect(results[#results].outcome).toBe("Defeat")
		local gold = Shop.getShards(me)
		world.advance(0.2)
		expect(#results).toBe(ended + 1)
		expect(settlements).toBe(paid)
		expect(Shop.getShards(me)).toBe(gold)
		expect(#world.errors).toBe(0)
	end)
end)
