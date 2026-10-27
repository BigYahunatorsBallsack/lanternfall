--!strict
-- Startup sanity check of all Config cross-references. Called once by the server bootstrap.
-- Returns a list of problems; an empty list means the data is consistent.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Snapshot = require(Shared.Net.Snapshot)

local ConfigCheck = {}

function ConfigCheck.run(): { string }
	local problems = {}
	local function problem(message: string)
		table.insert(problems, message)
	end

	-- Weapon behaviors: one module per behavior name in Services/WeaponService/Behaviors.
	local services = script.Parent:FindFirstChild("Services")
	local weaponService = services and services:FindFirstChild("WeaponService")
	local behaviorFolder = weaponService and weaponService:FindFirstChild("Behaviors")
	local function hasBehavior(name: string): boolean
		return behaviorFolder ~= nil and behaviorFolder:FindFirstChild(name) ~= nil
	end

	for id, weapon in Config.Weapons do
		if weapon.id ~= id then
			problem(`Weapon key {id} does not match id {weapon.id}`)
		end
		if #weapon.levels ~= Config.Player.maxItemLevel then
			problem(`Weapon {id} has {#weapon.levels} levels, expected {Config.Player.maxItemLevel}`)
		end
		if not (weapon.base.damage and weapon.base.damage > 0) then
			problem(`Weapon {id} needs a base damage above 0`)
		end
		if weapon.base.cooldown and weapon.base.cooldown <= 0 then
			problem(`Weapon {id} needs a cooldown above 0`)
		end
		for level, delta in weapon.levels do
			for key in delta :: { [string]: number } do
				if key ~= "damage" and weapon.base[key] == nil then
					problem(`Weapon {id} level {level} changes {key}, which its base stats do not have`)
				end
			end
		end
	end

	for id, passive in Config.Passives do
		if passive.id ~= id then
			problem(`Passive key {id} does not match id {passive.id}`)
		end
	end

	for id in Config.Weapons do
		if not (Config.Shop.basePrices[id] and Config.Shop.basePrices[id] > 0) then
			problem(`Shop.basePrices needs a price above 0 for weapon {id}`)
		end
	end
	for id in Config.Passives do
		if not (Config.Shop.basePrices[id] and Config.Shop.basePrices[id] > 0) then
			problem(`Shop.basePrices needs a price above 0 for passive {id}`)
		end
	end
	if Config.Shop.slots < 1 or Config.Shop.phaseSeconds <= 0 then
		problem("Shop needs at least one slot and a phase above 0 seconds")
	end

	for id, evolution in Config.Evolutions do
		if not Config.Weapons[evolution.weapon] then
			problem(`Evolution {id} needs unknown weapon {evolution.weapon}`)
		end
		if not Config.Passives[evolution.passive] then
			problem(`Evolution {id} needs unknown passive {evolution.passive}`)
		end
		local weapon = Config.Weapons[evolution.weapon]
		if weapon and hasBehavior(weapon.behavior) and not hasBehavior(evolution.behavior) then
			problem(`Evolution {id} has no behavior module {evolution.behavior}`)
		end
	end

	for id, class in Config.Classes do
		local weapon = Config.Weapons[class.startWeapon]
		if class.available and not weapon then
			problem(`Class {id} starts with unknown weapon {class.startWeapon}`)
		elseif class.available and weapon and not hasBehavior(weapon.behavior) then
			problem(`Class {id} starts with {class.startWeapon}, which has no behavior module {weapon.behavior}`)
		end
	end

	local typeIds = { [Config.Enemies.boss.typeId] = Config.Enemies.boss.id }
	for id, enemy in Config.Enemies.types do
		if enemy.id ~= id then
			problem(`Enemy key {id} does not match id {enemy.id}`)
		end
		if typeIds[enemy.typeId] then
			problem(`Enemy {id} reuses typeId {enemy.typeId} of {typeIds[enemy.typeId]}`)
		end
		typeIds[enemy.typeId] = id
		local eliteOffset = Config.Enemies.elite.typeIdOffset
		if enemy.typeId < 1 or enemy.typeId >= eliteOffset or enemy.typeId + eliteOffset > 255 then
			problem(`Enemy {id} typeId must be 1-{eliteOffset - 1} (its elite variant adds {eliteOffset})`)
		end
		if not (enemy.hp > 0 and enemy.radius > 0 and enemy.mass > 0 and enemy.speed >= 0) then
			problem(`Enemy {id} needs hp, radius and mass above 0 and a speed of at least 0`)
		end
		if enemy.look and not Config.Enemies.types[enemy.look] then
			problem(`Enemy {id} looks like unknown enemy {enemy.look}`)
		end
		local split = enemy.split
		if split and not (Config.Enemies.types[split.enemy] and split.enemy ~= id and split.count >= 1) then
			problem(`Enemy {id} must split into at least 1 of another known enemy`)
		end
		local charge = enemy.charge
		if
			charge
			and not (
				charge.triggerRange > 0
				and charge.windupSeconds > 0
				and charge.speed > 0
				and charge.maxDistance > 0
				and charge.recoverSeconds >= 0
				and charge.cooldownSeconds >= 0
			)
		then
			problem(`Enemy {id} needs positive charge values`)
		end
	end

	local affixes = Config.Enemies.elite.affixes
	if #affixes > 3 then
		problem("Enemies.elite.affixes can have at most 3 entries (2 bits in the snapshot flags)")
	end
	for index, affix in affixes do
		local summon = affix.summon
		if summon and not (Config.Enemies.types[summon.enemy] and summon.count >= 1 and summon.intervalSeconds > 0) then
			problem(`Enemies.elite.affixes[{index}] summons an unknown enemy or with bad numbers`)
		end
	end

	if Config.Enemies.boss.typeId >= Config.Enemies.elite.typeIdOffset then
		problem("Enemies.boss.typeId must stay below elite.typeIdOffset")
	end

	local sim = Config.Simulation
	if not (sim.tickRate > 0 and sim.spatialHashCellSize > 0 and sim.maxCatchUpSteps >= 1) then
		problem("Simulation.tickRate, spatialHashCellSize and maxCatchUpSteps must be positive")
	end
	if not (sim.separationStiffness > 0 and sim.separationStiffness <= 1 and sim.separationPasses >= 1) then
		problem("Simulation.separationStiffness must be in (0, 1] and separationPasses at least 1")
	end
	local cap = Config.Run.spawn.cap
	if cap.max > Snapshot.MAX_PER_PACKET * Snapshot.MAX_PARTS or cap.max >= Snapshot.MAX_ID then
		problem("Run.spawn.cap.max is more than enemy snapshots can carry")
	end
	if cap.base > cap.max then
		problem("Run.spawn.cap.base must not exceed cap.max")
	end
	if not (Config.Run.spawn.ringMin > 0 and Config.Run.spawn.ringMin <= Config.Run.spawn.ringMax) then
		problem("Run.spawn.ringMin must be above 0 and at most ringMax")
	end

	for _, step in Config.Run.spawn.mix do
		local sum = 0
		for enemyId, weight in step.weights do
			sum += weight
			if not Config.Enemies.types[enemyId] then
				problem(`Spawn mix at minute {step.fromMinute} uses unknown enemy {enemyId}`)
			end
		end
		if math.abs(sum - 1) > 1e-6 then
			problem(`Spawn mix at minute {step.fromMinute} sums to {sum}, expected 1`)
		end
	end

	local spawn = Config.Run.spawn
	for name, curve in { rateCurve = spawn.rateCurve, hpCurve = spawn.hpCurve, damageCurve = spawn.damageCurve } do
		if #curve == 0 or curve[1][1] ~= 0 then
			problem(`Run.spawn.{name} must start at minute 0`)
		end
		for k, point in curve do
			if not (point[2] > 0) or (k > 1 and point[1] <= curve[k - 1][1]) then
				problem(`Run.spawn.{name} needs values above 0 at rising minutes`)
				break
			end
		end
	end
	local waves = spawn.waves
	if #waves.lengthsSeconds == 0 then
		problem("Run.spawn.waves needs at least one wave")
	end
	for index, length in waves.lengthsSeconds do
		if not (length > 0) then
			problem(`Run.spawn.waves wave {index} needs a length above 0`)
		end
	end
	if not (spawn.swarmRush.durationShare > 0 and spawn.swarmRush.durationShare <= 1) then
		problem("Run.spawn.swarmRush.durationShare must be above 0 and at most 1")
	end
	if not (waves.rampFrom >= 0 and waves.rampTo >= 0 and waves.finalRate > 0) then
		problem("Run.spawn.waves rates must not be negative")
	end
	for _, entry in spawn.elites.waves do
		if entry.count < 1 then
			problem(`Run.spawn.elites at minute {entry.atMinute} needs a count of at least 1`)
		end
	end

	for id, tier in Config.Difficulty.tiers do
		if tier.unlockedBy and not Config.Difficulty.tiers[tier.unlockedBy] then
			problem(`Difficulty {id} unlocked by unknown tier {tier.unlockedBy}`)
		end
	end

	local flow = Config.Run.flow
	local defaultClass = Config.Classes[flow.defaultClassId]
	if not (defaultClass and defaultClass.available and defaultClass.free) then
		problem(`Run.flow.defaultClassId {flow.defaultClassId} must be an available free class`)
	end
	if not Config.Difficulty.tiers[flow.defaultDifficulty] then
		problem(`Run.flow.defaultDifficulty {flow.defaultDifficulty} is not a difficulty tier`)
	end
	if flow.allReadyCountdownSeconds <= 0 or flow.allReadyCountdownSeconds > flow.countdownSeconds then
		problem("Run.flow.allReadyCountdownSeconds must be above 0 and at most countdownSeconds")
	end
	if flow.resultsSeconds <= 0 then
		problem("Run.flow.resultsSeconds must be above 0")
	end
	if Config.Admin.skipToBossLeadSeconds >= Config.Run.durationSeconds then
		problem("Admin.skipToBossLeadSeconds must be shorter than the run")
	end

	for name, area in { arena = Config.Map.arena, lobby = Config.Map.lobby } do
		if area.spawnRadius * 2 >= area.size then
			problem(`Map.{name}.spawnRadius does not fit into its size`)
		end
	end
	local arena = Config.Map.arena
	local reach = math.max(math.abs(arena.center.X), math.abs(arena.center.Z)) + arena.size / 2
	if reach > Snapshot.MAX_COORDINATE then
		problem(`Map.arena reaches beyond +-{Snapshot.MAX_COORDINATE} studs, which enemy snapshots cannot encode`)
	end
	for index, obstacle in arena.obstacles do
		local half = arena.size / 2
		if math.abs(obstacle.x) + obstacle.radius > half or math.abs(obstacle.z) + obstacle.radius > half then
			problem(`Map.arena.obstacles[{index}] does not fit into the arena`)
		end
		local fromCenter = math.sqrt(obstacle.x ^ 2 + obstacle.z ^ 2)
		if fromCenter < obstacle.radius + arena.spawnRadius + sim.playerRadius then
			problem(`Map.arena.obstacles[{index}] blocks the start positions`)
		end
	end

	return problems
end

return ConfigCheck
