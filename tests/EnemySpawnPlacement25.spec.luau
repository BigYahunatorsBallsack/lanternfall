--!strict
-- Enemy sprites must already occupy their spawn point when first attached to Workspace, including pool reuse.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Snapshot = require(Shared.Net.Snapshot)
local Client = folderProxy("src/client", "Client")
world.addPlayer("Owner", 1, true)
world.step()
Net.initServer()
-- Isolate rendering from the lobby flow; snapshots still pass through the real codec and buffer.
require(Client.Controllers.RunStateController).getView = function()
	return "Run"
end
local Renderer = require(Client.Controllers.EnemyRenderer)
local attached = {}
workspace.ChildAdded:Connect(function(folder)
	if folder.Name == "LanternfallEnemies" then
		folder.ChildAdded:Connect(function(model)
			local body = model:FindFirstChild("Body")
			local shadow = model:FindFirstChild("Shadow")
			table.insert(attached, {
				model = model,
				body = if body and body.CFrame then body.CFrame.Position else Vector3.zero,
				shadow = if shadow and shadow.CFrame then shadow.CFrame.Position else Vector3.zero,
			})
		end)
	end
end)
Renderer.init()
Renderer.start()

local function send(tick: number, id: number?, x: number?, z: number?)
	local columns = Snapshot.newColumns()
	if id then
		columns.ids[1], columns.xs[1], columns.zs[1] = id, x, z
		columns.typeIds[1] = Config.Enemies.types.Shadeling.typeId
		columns.hpFractions[1], columns.flags[1], columns.statuses[1] = 1, 0, 0
	end
	for _, packet in Snapshot.encode(tick, columns, if id then 1 else 0) do
		Net.fireAllClients("EnemySnapshot", packet)
	end
	world.advance(0.2)
end

describe("Enemy spawn placement", function()
	it("positions a newly built sprite before making it visible", function()
		send(10, 1, 30, 45)
		expect(#attached).toBe(1)
		expect(attached[1].body.X).toBe(30)
		expect(attached[1].body.Z).toBe(45)
		expect(attached[1].body.Y).toBe(Config.Map.arena.center.Y)
		expect(attached[1].shadow.X).toBe(30)
		expect(attached[1].shadow.Z).toBe(45)
	end)
	it("moves a pooled sprite to its next spawn before reattaching it", function()
		send(11, nil)
		send(12, 2, -25, -40)
		expect(#attached).toBe(2)
		expect(attached[2].model).toBe(attached[1].model)
		expect(attached[2].body.X).toBe(-25)
		expect(attached[2].body.Z).toBe(-40)
		expect(attached[2].shadow.X).toBe(-25)
		expect(attached[2].shadow.Z).toBe(-40)
		expect(#world.errors).toBe(0)
	end)
end)
