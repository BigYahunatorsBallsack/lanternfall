--!strict
-- Existing snapshot status byte carries server invisibility through the actual client renderer and pooled sprite models.
local mock = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Snapshot = require(Shared.Net.Snapshot)
local Config = require(Shared.Config)
Net.initServer()
local me = mock.addPlayer("Owner", 1, true)
local client = folderProxy("src/client", "Client")
local State = require(client.Controllers.RunStateController)
local Renderer = require(client.Controllers.EnemyRenderer)
State.init()
Renderer.init()
Renderer.start()
local tick, version = 0, 0
local function view(phase)
	version += 1
	Net.fireClient(
		"RunState",
		me,
		{ version = version, phase = phase, players = { { userId = 1, participant = true } } }
	)
end
local function send(status, id)
	tick += 1
	local c = Snapshot.newColumns()
	c.ids[1], c.xs[1], c.zs[1] = id or 41, 20, 0
	c.typeIds[1] = Config.Enemies.types.Shadeling.typeId
	c.hpFractions[1], c.flags[1], c.statuses[1] = 1, 0, status
	Net.fireClient("EnemySnapshot", me, Snapshot.encode(tick, c, 1)[1])
	mock.advance(0.25)
end
local function model()
	local folder = assert(workspace:FindFirstChild("LanternfallEnemies"))
	return assert(folder:GetChildren()[1])
end
local function picture(m)
	for _, child in m:GetDescendants() do
		if child:IsA("ImageLabel") and child.Name ~= "Outline" then
			return child
		end
	end
	error("No sprite picture")
end
describe("Native server visibility", function()
	it("reserves bit6 without changing packet size or existing status bits", function()
		expect(Snapshot.STATUS_HIDDEN).toBe(64)
		local c = Snapshot.newColumns()
		c.ids[1], c.xs[1], c.zs[1], c.typeIds[1] = 1, 0, 0, 1
		c.hpFractions[1], c.flags[1] = 1, 0
		c.statuses[1] = 64
			+ Snapshot.STATUS_CHARMED
			+ Snapshot.STATUS_BURNING
			+ Snapshot.STATUS_SLOWED
			+ Snapshot.STATUS_BUFFED
			+ Snapshot.packPursuerStage(3)
		local packet = Snapshot.encode(1, c, 1)[1]
		expect(buffer.len(packet)).toBe(18)
		local out = Snapshot.newColumns()
		Snapshot.decodeInto(packet, out, 1)
		expect(out.statuses[1]).toBe(127)
		expect(Snapshot.unpackPursuerStage(out.statuses[1])).toBe(3)
	end)
	it("keeps a living server-hidden enemy hidden beyond the normal pool reveal delay", function()
		view("Running")
		send(64)
		expect(Renderer.getStats().drawn).toBe(1)
		local m = model()
		expect(m:GetAttribute("Hidden")).toBe(true)
		expect(picture(m).Visible).toBe(false)
		expect(Renderer.getPosition(41) ~= nil).toBe(true)
	end)
	it("reveals after timeout and hides again without releasing the live actor", function()
		send(0)
		local m = model()
		expect(m:GetAttribute("Hidden")).toBe(false)
		expect(picture(m).Visible).toBe(true)
		send(64 + Snapshot.STATUS_BURNING)
		expect(m:GetAttribute("Hidden")).toBe(true)
		expect(picture(m).Visible).toBe(false)
		local sources = 0
		Renderer.visitFogSources(function()
			sources += 1
		end)
		expect(sources).toBe(0)
		expect(Renderer.getStats().drawn).toBe(1)
	end)
	it("keeps a reused model hidden for the next actor and then reveals normally", function()
		view("Lobby")
		view("Running")
		send(64, 42)
		local m = model()
		expect(m:GetAttribute("Hidden")).toBe(true)
		send(0, 42)
		expect(m:GetAttribute("Hidden")).toBe(false)
		expect(Renderer.getPosition(42) ~= nil).toBe(true)
	end)
	it("does not expose a hidden model's windup telegraph", function()
		local Models = require(client.Controllers.EnemyRenderer.SpriteModels)
		local v = Models.build(Config.Enemies.types.Charger.typeId)
		Models.setMode(v, Models.MODE_WINDUP)
		expect(v.telegraph.Transparency < 1).toBe(true)
		Models.hide(v)
		expect(v.telegraph.Transparency).toBe(1)
		Models.setMode(v, Models.MODE_RUSH)
		Models.setMode(v, Models.MODE_WINDUP)
		expect(v.telegraph.Transparency).toBe(1)
		Models.show(v)
		expect(v.telegraph.Transparency < 1).toBe(true)
	end)
end)
