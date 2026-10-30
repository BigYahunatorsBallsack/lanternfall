--!strict
-- Startup sanity check of all Config cross-references. Called once by the server bootstrap.
-- Returns a list of problems; an empty list means the data is consistent.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local EffectsConfig = require(Shared.Config.Effects)
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
		if #weapon.tiers ~= Config.Player.maxWeaponTier then
			problem(`Weapon {id} has {#weapon.tiers} tiers, expected {Config.Player.maxWeaponTier}`)
		end
		if not (weapon.base.damage and weapon.base.damage > 0) then
			problem(`Weapon {id} needs a base damage above 0`)
		end
		if weapon.base.cooldown and weapon.base.cooldown <= 0 then
			problem(`Weapon {id} needs a cooldown above 0`)
		end
		-- B5: melee or ranged, 1-2 known weapon classes, crit values
		if weapon.kind ~= "Melee" and weapon.kind ~= "Ranged" then
			problem(`Weapon {id} needs kind Melee or Ranged`)
		end
		if #weapon.classes < 1 or #weapon.classes > 2 then
			problem(`Weapon {id} needs 1 or 2 weapon classes`)
		end
		for _, classId in weapon.classes do
			if not Config.WeaponClasses.byId[classId] then
				problem(`Weapon {id} has unknown weapon class {classId}`)
			end
		end
		local critChance, critDamage = weapon.base.critChance, weapon.base.critDamage
		if not (critChance and critChance >= 0 and critChance <= 1) then
			problem(`Weapon {id} needs a critChance between 0 and 1`)
		end
		if not (critDamage and critDamage >= 1) then
			problem(`Weapon {id} needs a critDamage of at least 1`)
		end
		if weapon.base.knockback == nil then
			problem(`Weapon {id} needs a knockback (0 for none)`)
		end
		if weapon.base.burnDamage and not (weapon.base.burnTicks and weapon.base.burnTicks >= 1) then
			problem(`Weapon {id} burns but has no burnTicks`)
		end
		for tier, delta in weapon.tiers do
			for key in delta :: { [string]: number } do
				if key ~= "damage" and weapon.base[key] == nil then
					problem(`Weapon {id} tier {tier} changes {key}, which its base stats do not have`)
				end
			end
		end
	end

	local function checkStats(owner: string, stats: { [string]: number })
		for statId, value in stats do
			if not Config.Stats.byId[statId] then
				problem(`{owner} changes unknown stat {statId}`)
			elseif value ~= value then
				problem(`{owner} has no number for {statId}`)
			end
		end
	end

	-- Item effects (Config.Effects, since B4): known trigger, action and stats, and the values each action needs.
	local Effects = Config.Effects
	local NEEDS_STATS =
		{ Stats = true, PerX = true, Grow = true, WaveStats = true, TimedStats = true, NextWaveStats = true }
	local NEEDS_AMOUNT = {
		Heal = true,
		Shards = true,
		ShardShare = true,
		HpFraction = true,
		RandomStats = true,
		Shields = true,
		Burn = true,
		Explode = true,
	}
	local function checkEffect(owner: string, effect: EffectsConfig.Effect)
		if not Effects.triggers[effect.trigger] then
			problem(`{owner} has unknown trigger {effect.trigger}`)
		end
		local passive = Effects.passiveActions[effect.action] == true
		if not (passive or Effects.eventActions[effect.action]) then
			problem(`{owner} has unknown action {effect.action}`)
		elseif passive ~= (effect.trigger == "Always") then
			problem(`{owner}: {effect.action} needs trigger {if passive then "Always" else "an event, not Always"}`)
		end
		if NEEDS_STATS[effect.action] and not effect.stats then
			problem(`{owner}: {effect.action} needs stats`)
		end
		if effect.stats then
			checkStats(owner, effect.stats)
		end
		if NEEDS_AMOUNT[effect.action] and not (effect.amount and effect.amount > 0) then
			problem(`{owner}: {effect.action} needs an amount above 0`)
		end
		if effect.state and not Effects.states[effect.state] then
			problem(`{owner} has unknown state {effect.state}`)
		end
		if effect.action == "PerX" then
			local source = effect.source or ""
			if not (Effects.perXSources[source] or Config.Stats.byId[source]) then
				problem(`{owner} counts unknown source {source}`)
			end
			if not (effect.per and effect.per > 0) then
				problem(`{owner}: PerX needs per above 0`)
			end
		end
		if effect.trigger == "Timer" and not (effect.interval and effect.interval > 0) then
			problem(`{owner}: Timer needs an interval above 0`)
		end
		if effect.action == "TimedStats" and not (effect.seconds and effect.seconds > 0) then
			problem(`{owner}: TimedStats needs seconds above 0`)
		end
		if effect.chance and not (effect.chance > 0 and effect.chance <= 1) then
			problem(`{owner} needs a chance between 0 and 1`)
		end
		if effect.action == "Burn" or effect.action == "Explode" then
			if not Effects.enemyTriggers[effect.trigger] then
				problem(`{owner}: {effect.action} needs an enemy trigger (Hit, Crit or Kill)`)
			end
			if effect.scaling then
				checkStats(owner, effect.scaling)
			end
		end
		if effect.action == "Burn" and not (effect.ticks and effect.ticks >= 1) then
			problem(`{owner}: Burn needs at least 1 tick`)
		end
		if effect.action == "Explode" and not (effect.size and effect.size > 0) then
			problem(`{owner}: Explode needs a size above 0`)
		end
	end

	for _, stat in Config.Stats.order do
		local upgrade = stat.upgrade
		if upgrade and #upgrade ~= #Config.Items.tiers then
			problem(`Stat {stat.id} needs one upgrade value per rarity tier ({#Config.Items.tiers})`)
		end
	end
	for index, tier in Config.Items.tiers do
		if not (tier.minWave >= 1 and tier.max >= 0 and tier.max <= 1 and tier.perWave >= 0) then
			problem(`Items.tiers[{index}] needs minWave >= 1 and chances between 0 and 1`)
		end
	end
	local seenItems = {}
	for _, item in Config.Items.list do
		if seenItems[item.id] then
			problem(`Item {item.id} is listed twice`)
		end
		seenItems[item.id] = true
		if not Config.Items.tiers[item.tier] then
			problem(`Item {item.id} has unknown tier {item.tier}`)
		end
		if not (item.price > 0) then
			problem(`Item {item.id} needs a price above 0`)
		end
		if item.limit and item.limit < 1 then
			problem(`Item {item.id} needs a limit of at least 1`)
		end
		checkStats(`Item {item.id}`, item.stats)
		for index, effect in item.effects or {} do
			checkEffect(`Item {item.id} effect {index}`, effect)
		end
	end
	for tier = 1, #Config.Items.tiers do
		local found = false
		for _, item in Config.Items.list do
			found = found or item.tier == tier
		end
		if not found then
			problem(`Items has no item of tier {tier}`)
		end
	end
	if not Config.Items.tiers[Config.Items.chestMinTier] then
		problem("Items.chestMinTier must be a rarity tier")
	end
	for level, tier in Config.Run.levelUp.guaranteedTiers do
		if not Config.Items.tiers[tier] or level < 2 then
			problem(`Run.levelUp.guaranteedTiers[{level}] needs a level of at least 2 and a known tier`)
		end
	end

	for id, weapon in Config.Weapons do
		if not (Config.Shop.weaponPrices[id] and Config.Shop.weaponPrices[id] > 0) then
			problem(`Shop.weaponPrices needs a price above 0 for weapon {id}`)
		end
		checkStats(`Weapon {id} scaling`, weapon.scaling)
		for _, key in weapon.rangeKeys do
			if weapon.base[key] == nil then
				problem(`Weapon {id} grows {key} with Range, which its base stats do not have`)
			end
		end
	end
	for _, weaponClass in Config.WeaponClasses.order do
		for count, stats in weaponClass.bonuses do
			if count < Config.WeaponClasses.minCount or count > Config.WeaponClasses.maxCount then
				problem(`Weapon class {weaponClass.id} has a bonus for {count} weapons`)
			end
			checkStats(`Weapon class {weaponClass.id}`, stats)
		end
	end
	if Config.Shop.slots < 1 or Config.Shop.phaseSeconds <= 0 then
		problem("Shop needs at least one slot and a phase above 0 seconds")
	end
	if
		#Config.Shop.tierPriceFactors ~= Config.Player.maxWeaponTier
		or #Config.Items.tiers < Config.Player.maxWeaponTier
	then
		problem("Shop.tierPriceFactors needs one factor per weapon tier, and Items.tiers a rarity for each")
	end
	local pool = Config.Shop.weaponPool
	if
		not (
			Config.Shop.sellShare >= 0
			and pool.owned >= 0
			and pool.sameClass >= 0
			and pool.owned + pool.sameClass <= 1
		)
	then
		problem("Shop.sellShare and weaponPool chances must not be negative, weaponPool at most 1 together")
	end
	if Config.Shop.freeRerollAfterBuys < 1 then
		problem("Shop.freeRerollAfterBuys must be at least 1")
	end

	for id, evolution in Config.Evolutions do
		if not Config.Weapons[evolution.weapon] then
			problem(`Evolution {id} needs unknown weapon {evolution.weapon}`)
		end
		if not Config.Items.byId[evolution.item] then
			problem(`Evolution {id} needs unknown item {evolution.item}`)
		end
		local weapon = Config.Weapons[evolution.weapon]
		if weapon and hasBehavior(weapon.behavior) and not hasBehavior(evolution.behavior) then
			problem(`Evolution {id} has no behavior module {evolution.behavior}`)
		end
	end

	for id, class in Config.Classes do
		checkStats(`Class {id}`, class.stats)
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

	local spawn = Config.Run.spawn
	-- B9: spawn groups of every wave and HP and damage growth per kind
	if #spawn.groups ~= #spawn.waves.lengthsSeconds then
		problem("Run.spawn.groups needs one entry per wave in Run.spawn.waves")
	end
	for index, entry in spawn.groups do
		for _, group in entry.groups do
			if not Config.Enemies.types[group.enemy] then
				problem(`Run.spawn.groups wave {index} uses unknown enemy {group.enemy}`)
			end
			if not (group.size > 0 and group.every > 0) then
				problem(`Run.spawn.groups wave {index} needs sizes and intervals above 0`)
			end
		end
	end
	if not (spawn.maxOwedFirings >= 1) then
		problem("Run.spawn.maxOwedFirings must be at least 1")
	end
	if not (spawn.firstShare >= 0 and spawn.groupSpread >= 0 and spawn.markerSeconds >= 0) then
		problem("Run.spawn.firstShare, groupSpread and markerSeconds must not be negative")
	end
	if #spawn.growth.hpSteps < #spawn.groups or #spawn.growth.damageSteps < #spawn.groups then
		problem("Run.spawn.growth needs hpSteps and damageSteps for every wave")
	end
	if not (spawn.swarmRush.every > 0) then
		problem("Run.spawn.swarmRush.every must be above 0")
	end
	for enemyId, kind in Config.Enemies.types do
		if not (kind.hpPerWave >= 0 and kind.damagePerWave >= 0) then
			problem(`Enemies.{enemyId} needs hpPerWave and damagePerWave of at least 0`)
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

	-- Loot (B6): the Looter and Tree enemies exist and behave as such, chances are chances
	local loot = Config.Loot
	local looter = Config.Enemies.types[loot.looter.enemy]
	if not (looter and looter.flee and looter.contactDamage == 0) then
		problem(`Loot.looter.enemy {loot.looter.enemy} must be a known enemy with flee and no contact damage`)
	end
	local tree = Config.Enemies.types[loot.trees.enemy]
	if not (tree and tree.anchored and tree.speed == 0 and tree.contactDamage == 0) then
		problem(`Loot.trees.enemy {loot.trees.enemy} must be a known anchored enemy with speed and contact damage 0`)
	end
	for _, value in { loot.consumables.chance, loot.consumables.crateShare, loot.looter.chance, loot.orbDrop.minChance } do
		if value < 0 or value > 1 then
			problem("Loot chances must lie between 0 and 1")
		end
	end
	for id, enemy in Config.Enemies.types do
		if enemy.ranged and enemy.flee then
			problem(`Enemy {id} cannot both shoot and flee`)
		end
	end

	return problems
end

return ConfigCheck
