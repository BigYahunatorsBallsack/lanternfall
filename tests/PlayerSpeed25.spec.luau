--!strict
-- Regression for the original movement/world-unit conversion, using the real combat service.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Combat = require(Server.Services.CombatService)
local player = world.addPlayer("Owner", 1, true)
world.step()
local sourceSpeed = 450
local expected = sourceSpeed * Config.Stats.range.studsPerPoint

describe("Original movement scale", function()
	it("uses the weapon-distance scale for the original 450 units per second", function()
		expect(Config.Player.moveSpeed).toBe(expected)
		expect(player.Character.Humanoid.WalkSpeed).toBe(expected)
	end)
	it("applies positive and negative speed percentages to the corrected base", function()
		Combat.setStats(player, { speed = 25 })
		expect(player.Character.Humanoid.WalkSpeed).toBe(expected * 1.25)
		Combat.setStats(player, { speed = -20 })
		expect(player.Character.Humanoid.WalkSpeed).toBe(expected * 0.8)
	end)
	it("keeps enemy movement in the same world-unit scale", function()
		expect(Config.Enemies.types.Shadeling.speed).toBe(200 * Config.Stats.range.studsPerPoint)
		expect(Config.Enemies.types.Mender.speed).toBe(400 * Config.Stats.range.studsPerPoint)
	end)
	it("keeps telegraphed rushes faster than normal movement", function()
		for id, kind in Config.Enemies.types do
			if kind.charge then
				assert(kind.charge.speed > (kind.speedMax or kind.speed), id)
				assert(kind.charge.speed > Config.Player.moveSpeed, id)
			end
		end
	end)
end)
