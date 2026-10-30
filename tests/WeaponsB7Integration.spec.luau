--!strict
-- End-to-end smoke test: real server and client bootstraps in a simulated Roblox (tests/helpers/RobloxMock).
-- Catches crashes, wrong module paths, broken remote payloads and flow bugs. Look and feel: Studio.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local RunDirector = require(ServerScriptService.Server.Services.RunDirector)
local EnemySim = require(ServerScriptService.Server.Services.EnemySim)
local CombatService = require(ServerScriptService.Server.Services.CombatService)
local WeaponService = require(ServerScriptService.Server.Services.WeaponService)
local ExperienceService = require(ServerScriptService.Server.Services.ExperienceService)
local SpawnDirector = require(ServerScriptService.Server.Services.SpawnDirector)
local StatService = require(ServerScriptService.Server.Services.StatService)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local me = world.addPlayer("Owner", 1, true)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

world.click(world.gui("Lobby", "Ready"))
world.advance(3.5)
RunDirector.setHoldWaves(true)
SpawnDirector.setPaused(true)
ExperienceService.setPaused(true)
CombatService.protect(me, 10000)
local function clear()
	EnemySim.killAll()
	for _, weapon in WeaponService.getWeapons(me) do
		WeaponService.removeWeapon(me, weapon.uid)
	end
end
local function give(id, tier)
	local ok, reason, uid = WeaponService.addWeapon(me, id, tier)
	assert(ok, reason)
	return uid
end
local function target(hp)
	local center = me.Character.HumanoidRootPart.Position
	return EnemySim.spawn("Shadeling", center.X + 5, center.Z, hp or 100, 0)
end

describe("B7 integration", function()
	it("loads every new visual and renders attacks without errors", function()
		for id, config in Config.Weapons do
			if not config.minTier then
				continue
			end
			clear()
			give(id, config.minTier)
			target()
			local drawn = false
			for _ = 1, 10 do
				world.advance(0.1)
				local folder = workspace:FindFirstChild("LanternfallWeapons")
				if folder and #folder:GetChildren() > 0 then
					drawn = true
				end
			end
			expect(drawn).toBe(true)
		end
	end)
	it("held stats follow copies, merging and selling without accumulating", function()
		clear()
		local before = StatService.getStat(me, "harvesting")
		local uid = give("TithePalm")
		give("TithePalm")
		expect(StatService.getStat(me, "harvesting")).toBe(before + 11) -- 6 held +5 class
		assert(WeaponService.merge(me, uid))
		expect(StatService.getStat(me, "harvesting")).toBe(before + 6)
		WeaponService.removeWeapon(me, uid)
		expect(StatService.getStat(me, "harvesting")).toBe(before)
	end)
	it("rejects restricted tiers at the service boundary", function()
		clear()
		expect(WeaponService.addWeapon(me, "CathedralEngine", 1)).toBe(false)
		give("CathedralEngine")
		expect(WeaponService.getWeapons(me)[1].tier).toBe(4)
	end)
	it("awards permanent kill growth as a permanent stat that survives selling", function()
		clear()
		give("WraithHatchet", 4)
		local before = StatService.getStat(me, "damage")
		for _ = 1, 12 do
			target(0.01)
			world.advance(1.7)
		end
		expect(StatService.getStat(me, "damage")).toBe(before + 1)
		clear()
		expect(StatService.getStat(me, "damage")).toBe(before + 1)
	end)
	it("debug NextWeapon can traverse all 24 weapons and respects minimum tiers", function()
		clear()
		give("BoomerangAxe")
		local seen = {}
		for _ = 1, 24 do
			world.click(world.gui("Debug", "NextWeapon"))
			world.advance(0.3)
			local weapon = WeaponService.getWeapons(me)[1]
			seen[weapon.id] = true
			expect(weapon.tier >= (Config.Weapons[weapon.id].minTier or 1)).toBe(true)
		end
		local count = 0
		for _ in seen do
			count += 1
		end
		expect(count).toBe(24)
	end)
end)
