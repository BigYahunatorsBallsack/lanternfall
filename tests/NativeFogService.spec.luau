--!strict
-- Real server/client fog lifecycle, shared participant visibility and offline surface fallback without any uploads or Studio modifications.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
runScript(folderProxy("src/client", "Client"), "init.client.luau")
local Fog = require(f.S.NativeFogService)
local Client = folderProxy("src/client", "Client")
local Renderer = require(Client.Controllers.NativeFogController)
local Danger = require(f.S.DangerService)
local C = require(f.Shared.Config.NativeFog)
local packets = {}
f.world.getRemote("NativeFog").OnClientEvent:Connect(function(packet)
	table.insert(packets, packet)
end)
local function latest()
	return packets[#packets]
end
local function cells()
	local result = {}
	for _, child in f.world.gui("NativeFog"):GetChildren() do
		if child.Name == "FogCell" then
			table.insert(result, child)
		end
	end
	return result
end
describe("Native fog service", function()
	it("does not allocate a mask in ordinary runs or expose a client activation intent", function()
		f.start(f.class.startWeapons[1])
		expect(Fog.isActive()).toBe(false)
		expect(Renderer.isVisible()).toBe(false)
		expect(f.world.gui("NativeFog")).toBe(nil)
		expect(require(f.Shared.Net.Remotes).NativeFog.direction).toBe("toClient")
		expect(#f.Config.Difficulty.levels).toBe(7)
	end)
	it("renders an internally selected fog wave from all living participant lights below the HUD", function()
		Danger.getNightmareEvent = function()
			return "fog_of_war"
		end
		f.start(f.class.startWeapons[1])
		f.Weapons.setPaused(true)
		expect(Fog.isActive()).toBe(true)
		expect(Renderer.isVisible()).toBe(true)
		expect(latest().wave).toBe(1)
		expect(#latest().players).toBe(2)
		expect(latest().players[1].alive).toBe(true)
		local gui = f.world.gui("NativeFog")
		expect(gui.DisplayOrder < f.world.gui("HUD").DisplayOrder).toBe(true)
		expect(#cells()).toBe(
			math.ceil(C.runtimeCompatibility.fallbackHeight * 1280 / 720) * C.runtimeCompatibility.fallbackHeight
		)
		local lit, dark = false, false
		for _, cell in cells() do
			lit = lit or cell.BackgroundTransparency == 1
			dark = dark or cell.BackgroundTransparency == 0
		end
		expect(lit and dark).toBe(true)
	end)
	it("freezes visibility at wave start and replays the same state on sync without rerolling", function()
		local before = #packets
		f.Stats.addStats(f.me, { fogVisibility = 25 })
		f.world.advance(0.5)
		expect(#packets).toBe(before)
		local at = latest().at
		f.world.fireServerAs(f.me, "RequestSync")
		expect(latest().at).toBe(at)
		for _, info in latest().players do
			if info.userId == f.me.UserId then
				expect(info.visibility).toBe(0)
			end
		end
	end)
	it("removes downed light and restores revived light without changing wave visibility", function()
		assert(f.Run.setParticipantState(f.me, "Down"))
		f.world.advance(0.2)
		for _, info in latest().players do
			if info.userId == f.me.UserId then
				expect(info.alive).toBe(false)
			end
		end
		assert(f.Run.setParticipantState(f.me, "Alive"))
		f.world.advance(0.2)
		for _, info in latest().players do
			if info.userId == f.me.UserId then
				expect(info.alive).toBe(true)
			end
		end
		expect(Renderer.isVisible()).toBe(true)
	end)
	it("captures changed visibility on the next fog wave", function()
		f.nextWave()
		f.Weapons.setPaused(true)
		expect(latest().wave).toBe(2)
		for _, info in latest().players do
			if info.userId == f.me.UserId then
				expect(info.visibility).toBe(25)
			end
		end
		expect(Renderer.isVisible()).toBe(true)
	end)
	it("disables fog and transient sources after the next wave and at run end", function()
		Danger.getNightmareEvent = function()
			return nil
		end
		f.nextWave()
		expect(Fog.isActive()).toBe(false)
		expect(Renderer.isVisible()).toBe(false)
		expect(latest().wave).toBe(0)
		assert(f.Run.endRun("Abandoned"))
		f.world.advance(0.1)
		expect(Renderer.isVisible()).toBe(false)
		expect(#f.world.errors).toBe(0)
	end)
end)
