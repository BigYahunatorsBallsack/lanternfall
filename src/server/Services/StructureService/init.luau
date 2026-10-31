--!strict
-- B12 authoritative structures: item-owned deployments, attacks, mines, fruit and companions.
-- Loader initializes this service; clients only receive bounded snapshots and cosmetic beams.
-- Paket 22: the snapshot goes out only when structures appear or vanish (at most every snapshotInterval) and both
-- feeds are compact buffers (Net/StructureFeed); orbiting companions follow server time, so clients draw them
-- around their owner every frame without updates.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local StructureFeed = require(Shared.Net.StructureFeed)
local Run = require(script.Parent.RunDirector)
local Stats = require(script.Parent.StatService)
local Enemy = require(script.Parent.EnemySim)
local Combat = require(script.Parent.CombatService)
local Loot = require(script.Parent.LootService)
local Map = require(script.Parent.MapService)
local RandomService = require(script.Parent.RandomService)
local Rules = require(script.Rules)
local Weapons = require(script.Parent.WeaponService)
local C = Config.Structures
local Service = {}
local paused = false
local objects: { any } = {}
local generators: { any } = {}
local serial = 0
local dirty = true
local elapsed = 0
local beams = {}
-- Paket 22: the owner's stats are copied once per step, not once per structure (StatService hands out copies)
local stepSheets: { [Player]: any } = {}
local stepImproved: { [Player]: boolean } = {}
local function sheetOf(player: Player): any
	local sheet = stepSheets[player]
	if not sheet then
		sheet = Stats.getSheet(player)
		stepSheets[player] = sheet
	end
	return sheet
end
local function improvedOf(player: Player): boolean
	local improved = stepImproved[player]
	if improved == nil then
		improved = (Stats.getItemCounts(player).CalibratedTools or 0) > 0
		stepImproved[player] = improved
	end
	return improved
end
local function snapshot()
	local result = {}
	for _, o in objects do
		table.insert(result, { id = o.id, ownerId = o.owner.UserId, kind = o.kind, x = o.position.X, z = o.position.Z })
	end
	return result
end
local function sync()
	Net.fireAllClients("Structures", StructureFeed.encodeStructures(snapshot()))
	dirty = false
end
local function reset()
	table.clear(objects)
	table.clear(generators)
	table.clear(beams)
	dirty = true
	elapsed = 0
	sync()
end
local function position(player)
	local root = Map.getRootPosition(player) or Config.Map.arena.center
	local rng = RandomService.stream("Combat", player)
	local bounds = Map.getArenaBounds()
	for _ = 1, C.spawnAttempts do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = math.sqrt(rng:NextNumber()) * C.spawnRadius
		local x = math.clamp(
			root.X + math.cos(angle) * radius,
			bounds.center.X - bounds.halfSize + C.margin,
			bounds.center.X + bounds.halfSize - C.margin
		)
		local z = math.clamp(
			root.Z + math.sin(angle) * radius,
			bounds.center.Z - bounds.halfSize + C.margin,
			bounds.center.Z + bounds.halfSize - C.margin
		)
		local valid = true
		for _, obstacle in Map.getObstacles() do
			if (x - obstacle.x) ^ 2 + (z - obstacle.z) ^ 2 < (obstacle.radius + C.margin) ^ 2 then
				valid = false
				break
			end
		end
		if valid then
			return Vector3.new(x, Config.Map.arena.center.Y, z)
		end
	end
	return root
end
local function add(player, kind)
	local own = {}
	for i, o in objects do
		if o.owner == player then
			table.insert(own, i)
		end
	end
	local budget = math.floor(C.maxActive / math.max(1, #Run.getParticipants()))
	if #own >= budget or #objects >= C.maxActive then
		if #own == 0 then
			return
		end
		table.remove(objects, own[RandomService.stream("Combat", player):NextInteger(1, #own)])
	end
	serial += 1
	table.insert(
		objects,
		{ id = serial, owner = player, kind = kind, position = position(player), remaining = 0, armed = false }
	)
	dirty = true
end
local function addGenerator(player, kind, definition)
	local count = 0
	for _, generator in generators do
		if generator.owner == player then
			count += 1
		end
	end
	local budget = math.floor(C.maxActive / math.max(1, #Run.getParticipants()))
	if count >= budget then
		return
	end
	local def = definition or C.kinds[kind]
	table.insert(generators, {
		owner = player,
		kind = kind,
		definition = def,
		remaining = Rules.interval(def, Stats.getSheet(player), (Stats.getItemCounts(player).CalibratedTools or 0) > 0),
	})
end
local function addWeaponSources(player)
	for _, weapon in Weapons.getWeapons(player) do
		local config = Config.Weapons[weapon.id]
		if config.structureKinds then
			local kind = config.structureKinds[weapon.tier]
			add(player, kind)
			if config.structureIntervals and #generators < C.maxActive then
				local def = table.clone(C.kinds[kind])
				def.interval = config.structureIntervals[weapon.tier]
				addGenerator(player, kind, def)
			end
		end
	end
end
local function deploy()
	reset()
	for _, player in Run.getParticipants() do
		addWeaponSources(player)
		local counts = Stats.getItemCounts(player)
		local ids = {}
		for id in counts do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local item = Config.Items.byId[id]
			if item and item.structure then
				-- At most 100 sources need simulation; excess copies cannot allocate unbounded timers.
				for _ = 1, math.min(counts[id], C.maxActive) do
					add(player, item.structure)
					if C.kinds[item.structure].mode == "Mine" and #generators < C.maxActive then
						addGenerator(player, item.structure)
					end
				end
			end
		end
	end
	sync()
end
local function hit(player, id, amount, source)
	-- EnemySim credits owner kills/loot. Structure damage deliberately bypasses primary weapon stats.
	Weapons.structureHit(player, id, amount, source)
end
local function burst(player, at, def, sheet, factor)
	local ids = {}
	local radius = def.radius * math.max(0, 1 + (sheet.explosionSize or 0) / 100)
	Enemy.queryRadius(at, radius, ids)
	local damage = Rules.damage(def, sheet) * math.max(0, 1 + (sheet.explosionDamage or 0) / 100) * (factor or 1)
	for _, id in ids do
		hit(player, id, damage, "Explosion")
	end
end
local function impact(o, def, sheet, id, at, factor)
	if def.mode == "Burn" then
		hit(o.owner, id, C.flameContactDamage)
		Weapons.structureBurn(o.owner, id, Rules.damage(def, sheet), def.ticks, sheet)
	elseif def.mode == "Explosion" then
		burst(o.owner, at, def, sheet, factor)
	else
		hit(o.owner, id, Rules.damage(def, sheet) * factor)
	end
end
local function ray(o, def, sheet, direction)
	local target = o.position + direction * def.range
	local ids = {}
	Enemy.querySegment(o.position, target, C.rayWidth, ids)
	if #ids > 1 then
		-- nearest first; distances once per enemy instead of in every comparison (Paket 22)
		local distances = {}
		for _, id in ids do
			local at = Enemy.getPosition(id)
			distances[id] = if at then (at - o.position).Magnitude else math.huge
		end
		table.sort(ids, function(a, b)
			return distances[a] < distances[b]
		end)
	end
	local limit = if def.pierce == -1
		then #ids
		else 1 + (def.pierce or 0) + math.max(0, math.floor(sheet.piercing or 0))
	local lastPosition = target
	for index, id in ids do
		if index > limit then
			break
		end
		local at = Enemy.getPosition(id)
		if at then
			lastPosition = at
			impact(o, def, sheet, id, at, Rules.pierceFactor(def, sheet) ^ (index - 1))
		end
	end
	-- Bounces use secondary stats, with an explicit visited set to prevent repeated hits.
	if #ids > 0 then
		local visited = {}
		for i = 1, math.min(#ids, limit) do
			visited[ids[i]] = true
		end
		local origin = lastPosition
		local damage = Rules.damage(def, sheet)
		for _ = 1, math.max(0, math.floor(sheet.bounce or 0)) do
			local nearby = {}
			Enemy.queryRadius(origin, C.bounceRange, nearby)
			local best = nil
			local distance = math.huge
			for _, id in nearby do
				local at = Enemy.getPosition(id)
				if at and not visited[id] and (at - origin).Magnitude < distance then
					best = id
					distance = (at - origin).Magnitude
				end
			end
			if not best then
				break
			end
			visited[best] = true
			origin = Enemy.getPosition(best)
			damage *= C.bounceFalloff
			impact(o, def, sheet, best, origin, damage / Rules.damage(def, sheet))
		end
	end
	if #beams < C.maxBeams then
		table.insert(beams, { x = o.position.X, z = o.position.Z, tx = target.X, tz = target.Z, kind = o.kind })
	end
end
local function step(dt)
	if paused or not Run.isActive() then
		return
	end
	table.clear(stepSheets)
	table.clear(stepImproved)
	elapsed += dt
	for _, generator in generators do
		if Run.getParticipantState(generator.owner) == "Alive" then
			generator.remaining -= dt
			if generator.remaining <= 0 then
				add(generator.owner, generator.kind)
				generator.remaining = Rules.interval(
					generator.definition or C.kinds[generator.kind],
					sheetOf(generator.owner),
					improvedOf(generator.owner)
				)
			end
		end
	end
	for index = #objects, 1, -1 do
		local o = objects[index]
		if Run.getParticipantState(o.owner) ~= "Alive" then
			continue
		end
		local def = C.kinds[o.kind]
		if def.mode == "Orbit" then
			local root = Map.getRootPosition(o.owner)
			if root then
				-- server time, so clients compute the same angle (StructureRenderer)
				local angle = workspace:GetServerTimeNow() * C.orbitSpeed + o.id
				o.position = root + Vector3.new(math.cos(angle) * C.orbitRadius, 0, math.sin(angle) * C.orbitRadius)
			end
		end
		o.remaining -= dt
		if o.remaining > 0 then
			continue
		end
		local sheet = sheetOf(o.owner)
		o.remaining = Rules.interval(def, sheet, improvedOf(o.owner))
		if def.mode == "Garden" then
			Loot.dropPickup(o.position + Vector3.new(C.fruitOffset, 0, 0), "Fruit")
		elseif def.mode == "Heal" then
			local root = Map.getRootPosition(o.owner)
			if root and (root - o.position).Magnitude <= def.range then
				Combat.healPlayer(o.owner, Rules.heal(def, sheet))
			end
		elseif def.mode == "Orbit" then
			local ids = {}
			Enemy.queryRadius(o.position, def.range, ids)
			for _, id in ids do
				Enemy.slow(id, C.slowFactor, C.slowSeconds)
			end
		elseif def.mode == "Mine" then
			o.remaining = 0
			local id = Enemy.nearest(o.position, def.range)
			if id then
				o.armed = true
			elseif o.armed then
				burst(o.owner, o.position, def, sheet)
				table.remove(objects, index)
				dirty = true
			end
		else
			local id = Enemy.nearest(o.position, def.range)
			local target = id and Enemy.getPosition(id)
			if target then
				if def.mode == "Radial" then
					for n = 1, def.rays do
						local angle = n * math.pi * 2 / def.rays
						ray(o, def, sheet, Vector3.new(math.cos(angle), 0, math.sin(angle)))
					end
				else
					local delta = target - o.position
					if delta.Magnitude > 0 then
						ray(o, def, sheet, delta.Unit)
					end
				end
			else
				o.remaining = 0
			end
		end
	end
	if elapsed >= C.snapshotInterval then
		elapsed = 0
		if #beams > 0 then
			local packet = StructureFeed.encodeBeams(beams)
			for _, player in Run.getParticipants() do
				Net.fireClient("StructureBeams", player, packet)
			end
			beams = {}
		end
		if dirty then
			sync()
		end
	end
end
function Service.init()
	Run.RunStarted:Connect(reset)
	Run.PhaseChanged:Connect(function(phase, previous)
		if phase == "Running" and previous ~= "Running" then
			deploy()
		elseif phase ~= "Running" and phase ~= "Boss" then
			reset()
		end
	end)
	Enemy.Stepped:Connect(step)
	Run.SyncRequested:Connect(function(player)
		Net.fireClient("Structures", player, StructureFeed.encodeStructures(snapshot()))
	end)
	Players.PlayerRemoving:Connect(function(player)
		for i = #objects, 1, -1 do
			if objects[i].owner == player then
				table.remove(objects, i)
			end
		end
		for i = #generators, 1, -1 do
			if generators[i].owner == player then
				table.remove(generators, i)
			end
		end
		dirty = true
	end)
end
function Service.getSnapshot()
	return snapshot()
end
function Service.setPaused(value: boolean)
	paused = value
end
return Service
