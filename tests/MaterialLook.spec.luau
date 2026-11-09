--!strict
-- Shard drops look varied: picture, turn, mirror and size come from the orb id and are the same on every client.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local MaterialLook = require(Shared.Util.MaterialLook)
local Client = folderProxy("src/client", "Client")
local Orbs = require(Client.Controllers.XpOrbRenderer)
world.addPlayer("Owner", 1, true)
world.step()
Net.initServer()
Orbs.init()

local settings = Config.Sprites.material

describe("MaterialLook", function()
	it("gives the same look for the same id", function()
		local a, b = MaterialLook.of(42, 6, settings), MaterialLook.of(42, 6, settings)
		expect(a.variant).toBe(b.variant)
		expect(a.rotation).toBe(b.rotation)
		expect(a.scale).toBe(b.scale)
		expect(a.flipped).toBe(b.flipped)
	end)
	it("stays in range and spreads over every picture, turn and mirror", function()
		local seen, flips, minTurn, maxTurn = {}, 0, math.huge, -math.huge
		for id = 1, 600 do
			local look = MaterialLook.of(id, 6, settings)
			expect(look.variant >= 1 and look.variant <= 6).toBe(true)
			expect(math.abs(look.rotation) <= settings.turn).toBe(true)
			expect(math.abs(look.scale - 1) <= settings.sizeJitter + 1e-9).toBe(true)
			seen[look.variant] = (seen[look.variant] or 0) + 1
			flips += if look.flipped then 1 else 0
			minTurn, maxTurn = math.min(minTurn, look.rotation), math.max(maxTurn, look.rotation)
		end
		for variant = 1, 6 do
			expect((seen[variant] or 0) > 50).toBe(true)
		end
		expect(flips > 200 and flips < 400).toBe(true)
		expect(minTurn < -settings.turn * 0.8 and maxTurn > settings.turn * 0.8).toBe(true)
	end)
	it("deals every picture once per six drops in a row, never the same one twice in a row", function()
		local last = 0
		for block = 0, 199 do
			local seen = {}
			for slot = 1, 6 do
				local variant = MaterialLook.of(block * 6 + slot - 1, 6, settings).variant
				expect(seen[variant]).toBe(nil)
				seen[variant] = true
				expect(variant ~= last).toBe(true)
				last = variant
			end
		end
	end)
	it("draws lying shards behind figures", function()
		expect(settings.depthBias < Config.Sprites.depthBias).toBe(true)
		expect(settings.depthBias > 0).toBe(true)
	end)
	it("works with a single picture", function()
		expect(MaterialLook.of(7, 1, settings).variant).toBe(1)
		expect(MaterialLook.of(7, 0, settings).variant).toBe(1)
	end)
	it("turns lying shards differently on the floor", function()
		Net.fireAllClients("XpOrbs", {
			reset = true,
			orbs = { 11, 20, 30, 1, 12, 25, 30, 1, 13, 30, 30, 1, 14, 35, 30, 1 },
			collected = {},
		})
		local folder = assert(workspace:FindFirstChild("LanternfallXpOrbs"))
		local turns = {}
		for _, anchor in folder:GetChildren() do
			turns[anchor.XpOrb.Picture.Rotation] = true
		end
		local distinct = 0
		for _ in turns do
			distinct += 1
		end
		expect(distinct >= 3).toBe(true)
		expect(#world.errors).toBe(0)
	end)
end)
