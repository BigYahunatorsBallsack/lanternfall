-- End-to-end test of down and revive during a wave (WP11): a teammate standing next to a downed player revives them,
-- walking away drains the revive, the down timer makes them out until the wave ends, and the camera of an out
-- player watches the teammate. Real server and client bootstraps in a simulated Roblox (tests/helpers/RobloxMock).
-- Look and feel: Studio with two clients.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Services = ServerScriptService.Server.Services
local CombatService = require(Services.CombatService)
local ExperienceService = require(Services.ExperienceService)
local UpgradeService = require(Services.UpgradeService)
local ReviveService = require(Services.ReviveService)
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)
local WeaponService = require(Services.WeaponService)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local ReviveController = require(Client.Controllers.ReviveController)
local CameraController = require(Client.Controllers.CameraController)

local Coop = Config.Run.coop

local function place(player, x, z)
	local root = player.Character.HumanoidRootPart
	root.Position = Vector3.new(x, root.Position.Y, z)
end

local function start()
	world.fireServerAs(me, "SetReady", true)
	world.fireServerAs(peer, "SetReady", true)
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	expect(RunDirector.getPhase()).toBe("Running")
	SpawnDirector.setPaused(true)
	WeaponService.setPaused(true)
	RunDirector.setHoldWaves(true)
	place(me, 0, 0)
	place(peer, 30, 0)
end

describe("revive", function()
	it("shows a downed player with the timer and a hint", function()
		start()
		RunDirector.setParticipantState(me, "Down")
		world.advance(2)
		local timeLeft, progress = ReviveService.get(me)
		expect(timeLeft).toBeNear(Coop.downTimerSeconds - 2, 0.1)
		expect(progress).toBe(0)
		expect(ReviveController.getLabel(1)).toBe(`DOWN {Coop.downTimerSeconds - 2} s`)
		expect(ReviveController.getHint()).toBe(
			`You are down! A teammate can revive you: {Coop.downTimerSeconds - 2} s`
		)
		expect(world.gui("Revive").Enabled).toBe(true)
	end)

	it("fills the revive while a teammate stands next to them and pauses the timer", function()
		local before = ReviveService.get(me)
		place(peer, Coop.reviveRadius - 1, 0)
		world.advance(Coop.reviveSeconds / 2)
		local timeLeft, progress = ReviveService.get(me)
		expect(timeLeft).toBeNear(before :: number, 0.05)
		expect(progress).toBeNear(0.5, 0.05)
		expect(ReviveController.getHint()).toBe("Peer is reviving you…")
		expect(ReviveController.getProgress(1)).toBeNear(0.5, 0.05)
	end)

	it("drains the revive when the teammate walks away", function()
		place(peer, 30, 0)
		world.advance(Coop.reviveDecaySeconds / 4)
		local _, progress = ReviveService.get(me)
		expect(progress).toBeNear(0.25, 0.05)
	end)

	it("stands up with revive HP and a short protection", function()
		place(peer, 2, 0)
		world.advance(Coop.reviveSeconds)
		expect(RunDirector.getParticipantState(me)).toBe("Alive")
		expect(ReviveService.get(me)).toBe(nil)
		local hp, maxHp = CombatService.getHp(me)
		expect(hp).toBe(math.ceil(maxHp * Coop.reviveHpFraction))
		expect(CombatService.damagePlayer(me, 10)).toBe(0) -- protected
		world.advance(Coop.reviveProtectionSeconds)
		expect(CombatService.damagePlayer(me, 10) > 0).toBe(true)
		expect(ReviveController.getHint()).toBe("")
		expect(ReviveController.getLabel(1)).toBe("")
	end)

	it("is out when nobody comes in time, and watches the teammate", function()
		place(peer, 30, 0)
		RunDirector.setParticipantState(me, "Down")
		world.advance(Coop.downTimerSeconds + 0.5)
		expect(RunDirector.getParticipantState(me)).toBe("Out")
		expect(RunDirector.getPhase()).toBe("Running")
		expect(CameraController.getFollowed()).toBe(peer)
		expect(ReviveController.getHint()).toBe("You are out until the wave ends – watching Peer")
		expect(ReviveController.getLabel(1)).toBe("OUT")
		-- the team still levels up for them: the cards wait for the shop
		ExperienceService.grantLevel()
		world.advance(0.2)
		-- out players cannot be revived any more
		place(peer, 1, 0)
		world.advance(Coop.reviveSeconds + 0.5)
		expect(RunDirector.getParticipantState(me)).toBe("Out")
	end)

	it("stands up again when the wave ends", function()
		world.click(world.gui("Debug", "SkipWave"))
		world.advance(0.3)
		expect(RunDirector.getPhase()).toBe("Shop")
		expect(RunDirector.getParticipantState(me)).toBe("Alive")
		local hp = CombatService.getHp(me)
		expect(hp > 0).toBe(true)
		expect(CameraController.getFollowed()).toBe(nil)
		expect(UpgradeService.getOffer(me) ~= nil).toBe(true) -- the level gained while out
	end)

	it("ends the run when the last one standing goes down", function()
		world.fireServerAs(me, "SetShopReady", true)
		world.fireServerAs(peer, "SetShopReady", true)
		world.advance(0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		place(me, 0, 0)
		place(peer, 30, 0)
		RunDirector.setParticipantState(me, "Down")
		world.advance(0.2)
		RunDirector.setParticipantState(peer, "Down")
		world.advance(0.2)
		expect(RunDirector.getPhase()).toBe("Ended")
	end)

	it("finished without any runtime error", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n\n"))
		end
	end)
end)
