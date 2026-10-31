-- Paket 22 performance check: four players with six tier-IV weapons each, effect items and structures among the
-- maximum of 140 enemies (refilled all the time, so they keep dying and dropping orbs) for 20 simulated seconds.
-- Measures what the local client receives per remote (Net/NetSize estimate of Roblox's remote format) and the CPU
-- time per handler (tests/helpers/RobloxMock profiler), prints both and checks the network budget per client.
-- The mock's instances are Lua tables, much slower than Roblox's, so client times are only a ranking.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
runScript(ServerScriptService.Server, "init.server.luau")

local Shared = game:GetService("ReplicatedStorage").Shared
local Services = ServerScriptService.Server.Services
local CombatService = require(Services.CombatService)
local EnemySim = require(Services.EnemySim)
local RunDirector = require(Services.RunDirector)
local SpawnDirector = require(Services.SpawnDirector)
local StatService = require(Services.StatService)
local WeaponService = require(Services.WeaponService)
local Config = require(Shared.Config)
local NetSize = require(Shared.Net.NetSize)
local RunSchedule = require(Shared.Util.RunSchedule)

local SECONDS = 20
local FRAME = 1 / 30
local ENEMY_HP = 40 -- times the base HP, so the crowd lives long enough to be hit for a while (late-wave crowd)
local MIX = { "Shadeling", "Shadeling", "Shadeling", "Spitter", "Charger", "Brute", "Herald", "Stalker", "Skulker" }

local me = world.addPlayer("Owner", 1, true)
local players =
	{ me, world.addPlayer("P2", 2, false), world.addPlayer("P3", 3, false), world.addPlayer("P4", 4, false) }
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)

local function protectAll()
	for _, player in players do
		CombatService.protect(player, 100000)
	end
end

local function nextWave()
	RunDirector.skipTo(RunSchedule.wave(RunDirector.getWave()).endsAt)
	world.advance(0.2)
	assert(RunDirector.getPhase() == "Shop", "shop did not open")
	for _, player in players do
		world.fireServerAs(player, "SetShopReady", true)
	end
	world.advance(1)
	assert(RunDirector.getPhase() == "Running", "next wave did not start")
	protectAll()
end

local function arm()
	local implemented = WeaponService.getImplemented()
	table.sort(implemented)
	for index, player in players do
		local k = 0
		while #WeaponService.getWeapons(player) < WeaponService.getMaxWeapons(player) and k < #implemented do
			WeaponService.addWeapon(player, implemented[(index * 7 + k) % #implemented + 1], 4)
			k += 1
		end
		-- items with effects and combat stats (burn, explode, bounce, pierce) on everyone
		local given = 0
		for _, item in Config.Items.list do
			if given >= 14 then
				break
			end
			if (item.effects and #item.effects > 0) and (given + index) % 2 == 0 then
				StatService.addItem(player, item.id)
			end
			given += 1
		end
	end
end

local function place(player: Player, x: number, z: number, vx: number, vz: number)
	local root = player.Character.HumanoidRootPart
	root.Position = Vector3.new(x, root.Position.Y, z)
	root.AssemblyLinearVelocity = Vector3.new(vx, 0, vz)
end

local spawnIndex = 0
local function refill()
	local center = Config.Map.arena.center
	local cap = SpawnDirector.getCap()
	local count = EnemySim.getCount()
	while count < cap do
		spawnIndex += 1
		local angle = spawnIndex * 2.39996
		local distance = 20 + (spawnIndex * 7) % 30
		local id = MIX[spawnIndex % #MIX + 1]
		if
			not EnemySim.spawn(
				id,
				center.X + math.cos(angle) * distance,
				center.Z + math.sin(angle) * distance,
				ENEMY_HP,
				1
			)
		then
			break
		end
		count += 1
	end
end

local received: { [string]: number } = {}
local calls: { [string]: number } = {}
local measuring = false
world.netWatch = function(name: string, player: Player?, ...)
	if measuring and (player == nil or player == me) then
		received[name] = (received[name] or 0) + NetSize.call(...)
		calls[name] = (calls[name] or 0) + 1
	end
end

local function sortedKeys(map: { [string]: number }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return map[a] > map[b]
	end)
	return keys
end

local function report(): number
	local total = 0
	for _, bytes in received do
		total += bytes
	end
	print(string.format("-- network, local client: %.1f KB/s estimated", total / 1024 / SECONDS))
	for _, name in sortedKeys(received) do
		print(
			string.format(
				"   %-16s %6.2f KB/s  %5.1f calls/s",
				name,
				received[name] / 1024 / SECONDS,
				calls[name] / SECONDS
			)
		)
	end
	local profile = world.profiler
	local serverSteps = SECONDS * Config.Simulation.tickRate
	local frames = SECONDS / FRAME
	local server, client = 0, 0
	for key, seconds in profile do
		if string.find(key, "src/server", 1, true) then
			server += seconds
		elseif string.find(key, "src/client", 1, true) then
			client += seconds
		end
	end
	print(
		string.format(
			"-- cpu: server %.2f ms per step (%.2f ms per frame), client %.2f ms per frame (mock instances)",
			server * 1000 / serverSteps,
			server * 1000 / frames,
			client * 1000 / frames
		)
	)
	local shown = 0
	for _, key in sortedKeys(profile) do
		shown += 1
		if shown > 24 then
			break
		end
		local per = if string.find(key, "src/server", 1, true) then serverSteps else frames
		local unit = if per == serverSteps then "step" else "frame"
		print(string.format("   %6.3f ms/%-5s %s", profile[key] * 1000 / per, unit, key))
	end
	return total / 1024 / SECONDS
end

describe("performance (Paket 22)", function()
	it("keeps the local client under the network budget in a full four-player fight", function()
		for _, player in players do
			world.fireServerAs(player, "SetReady", true)
		end
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		expect(RunDirector.getPhase()).toBe("Running")
		protectAll()
		-- structures (B12) deploy at the next wave start
		for _, player in players do
			world.fireServerAs(player, "DebugCommand", "GiveStructureKit")
		end
		world.advance(0.3)
		nextWave()
		RunDirector.setHoldWaves(true)
		arm()
		refill()
		world.advance(1)

		measuring = true
		world.profiler = {}
		local t = 0
		local refillAt = 0
		for _ = 1, SECONDS / FRAME do
			t += FRAME
			for index, player in players do
				local angle = t * 0.6 + index * math.pi / 2
				local radius = 18
				local cx, cz = Config.Map.arena.center.X, Config.Map.arena.center.Z
				place(
					player,
					cx + math.cos(angle) * radius,
					cz + math.sin(angle) * radius,
					-math.sin(angle) * radius * 0.6,
					math.cos(angle) * radius * 0.6
				)
			end
			if t >= refillAt then
				refillAt = t + 0.5
				refill()
				protectAll()
			end
			world.step(FRAME)
		end
		measuring = false
		local profile = world.profiler
		world.profiler = nil
		world.profiler = profile
		local kilobytes = report()
		world.profiler = nil
		expect(#world.errors).toBe(0)
		expect(kilobytes < Config.Simulation.budget.networkKilobytesPerSecond).toBe(true)
	end)
end)
