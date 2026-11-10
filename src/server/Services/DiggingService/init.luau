--!strict
-- Authoritative native Dig Sites; Loader initializes wave placement, physical occupancy, loot and persistent challenge credit.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.Digging)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Run = require(script.Parent.RunDirector)
local Enemy = require(script.Parent.EnemySim)
local Map = require(script.Parent.MapService)
local Stats = require(script.Parent.StatService)
local Loot = require(script.Parent.LootService)
local Data = require(script.Parent.PlayerDataService)
local Random = require(script.Parent.RandomService)
local Rules = require(script.Rules)
local Service = {}
local sites: { any } = {}
local elapsed = 0
local function snapshot(): { any }
	local result = {}
	for _, site in sites do
		table.insert(
			result,
			{ id = site.id, x = site.x, z = site.z, progress = site.progress / site.duration, dug = site.dug }
		)
	end
	return result
end
local function sync()
	Net.fireAllClients("DigSites", snapshot())
	elapsed = 0
end
local function clear()
	table.clear(sites)
	sync()
end
local function deploy()
	clear()
	local count = 0
	for _, player in Run.getParticipants() do
		count += Rules.siteCount(Run.getParticipantClassId(player), Stats.getItemCounts(player), Run.getWave())
	end
	local bounds = Map.getArenaBounds()
	for id = 1, math.min(count, C.maxSites) do
		local x, z = Rules.position(bounds, sites, function()
			return Random.number("Spawns")
		end)
		table.insert(sites, {
			id = id,
			x = x,
			z = z,
			progress = 0,
			duration = C.minimumSeconds + (C.maximumSeconds - C.minimumSeconds) * Random.number("Spawns"),
			dug = false,
		})
	end
	sync()
end
local function step(dt: number)
	if not Run.isActive() or #sites == 0 then
		return
	end
	local changed = false
	local completed = false
	for _, site in sites do
		if site.dug then
			continue
		end
		local diggers = {}
		for _, player in Run.getParticipants() do
			local at = Map.getRootPosition(player)
			if
				Run.getParticipantState(player) == "Alive"
				and at
				and Rules.contains(site.x, site.z, at.X, at.Z + C.playerBodyOffsetZ)
			then
				table.insert(diggers, player)
			end
		end
		if #diggers == 0 then
			continue
		end
		site.progress = math.min(site.duration, site.progress + dt)
		changed = true
		if site.progress >= site.duration then
			site.dug = true
			completed = true
			Loot.dropPickup(Vector3.new(site.x, Config.Map.arena.center.Y, site.z), "Crate")
			for _, player in diggers do
				Data.observeNativeDigSite(player)
			end
		end
	end
	elapsed += dt
	if completed or (changed and elapsed >= C.snapshotSeconds) then
		sync()
	end
end
function Service.init()
	Run.RunStarted:Connect(clear)
	Run.RunEnded:Connect(clear)
	Run.PhaseChanged:Connect(function(phase, previous)
		if phase == "Running" and previous ~= "Running" then
			deploy()
		elseif phase ~= "Running" and phase ~= "Boss" then
			clear()
		end
	end)
	Enemy.Stepped:Connect(step)
	Run.SyncRequested:Connect(function(player)
		Net.fireClient("DigSites", player, snapshot())
	end)
end
function Service.getSnapshot(): { any }
	return snapshot()
end
return Service
