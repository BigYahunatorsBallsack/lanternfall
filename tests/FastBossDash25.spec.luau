--!strict
-- A player grazing a fast boss charge must be hit along the segment, once per charge.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local Services = Server.Services
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Bosses = require(Services.BossService)
local Brain = require(Services.BossService.BossBrain)
local Enemies = require(Services.EnemySim)
local Combat = require(Services.CombatService)
local player = world.addPlayer("Owner", 1, true)
world.step()
world.fireServerAs(player, "SetReady", true)
world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.1)
require(Services.SpawnDirector).setPaused(true)
require(Services.WeaponService).setPaused(true)
require(Services.RunDirector).setHoldWaves(true)
Enemies.killAll()
local originalNew = Brain.new
local brain
Brain.new = function(plan, roll)
	brain = originalNew(plan, roll)
	return brain
end
Bosses.spawnNext(Vector3.zero)
Brain.new = originalNew
local boss = Bosses.getBosses()[1]
assert(boss.bossId == "LanternEater")
local kind = Config.Enemies.bosses.LanternEater
local attack = kind.boss.states[1].attack
local step = 1 / Config.Simulation.tickRate
local distance = (kind.speed + (attack.chargeSpeed or 0)) * step
local root = player.Character.HumanoidRootPart
local originalPlayerPosition = Enemies.getPlayerPosition
-- Manual simulation ticks supply the new target position directly, without the separate EnemySim sampling tick.
Enemies.getPlayerPosition = function(target)
	return if target == player then root.Position else originalPlayerPosition(target)
end
root.Position = Vector3.new(0, Config.Map.arena.center.Y, 5.5)
Enemies.teleport(boss.id, Vector3.new(-distance / 2, Config.Map.arena.center.Y, 5.5))
local originalDamage = Combat.damagePlayer
local dashHits = 0
Combat.damagePlayer = function(target, _amount)
	-- in wave 1 the charge and the orbit projectiles both hit for 1 (Brotato's base values), so count charge hits only
	if target == player and string.find(debug.traceback(), "chargeStep", 1, true) then
		dashHits += 1
	end
end
brain.cooldown = 0
Enemies.Stepped:Fire(step, workspace:GetServerTimeNow()) -- the wind-up fixes the direction along +X
root.Position = Vector3.new(0, Config.Map.arena.center.Y, 0) -- sidestep to a grazing intersection
brain.timer = 0

describe("Fast boss charge", function()
	it("hits a grazing player even when both endpoints lie outside the hit circle", function()
		Enemies.Stepped:Fire(step, workspace:GetServerTimeNow())
		expect(dashHits).toBe(1)
	end)
	it("does not damage the same player twice during that charge", function()
		local position = Enemies.getPosition(boss.id)
		root.Position = Vector3.new(position.X + distance / 2, root.Position.Y, 5.5)
		Enemies.Stepped:Fire(step, workspace:GetServerTimeNow())
		expect(dashHits).toBe(1)
		Combat.damagePlayer = originalDamage
		Enemies.getPlayerPosition = originalPlayerPosition
		expect(#world.errors).toBe(0)
	end)
end)
