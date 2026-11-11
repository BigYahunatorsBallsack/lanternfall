--!strict
-- Native character event and condition effects; service loader initializes, combat/loot/stats drive updates.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.CharacterMechanics)
local StatMath = require(Shared.Util.StatMath)
local Schedule = require(Shared.Util.RunSchedule)
local Run = require(script.Parent.RunDirector)
local Stats = require(script.Parent.StatService)
local Combat = require(script.Parent.CombatService)
local Weapons = require(script.Parent.WeaponService)
local Enemy = require(script.Parent.EnemySim)
local Random = require(script.Parent.RandomService)
local Shop = require(script.Parent.ShopService)
local Loot = require(script.Parent.LootService)
local Experience = require(script.Parent.ExperienceService)
local Structures = require(script.Parent.StructureService)
local Danger = require(script.Parent.DangerService)
local Rules = require(script.Rules)
local Movement = require(script.Movement)
local HealingChallenges = require(script.HealingChallenges)

type State = {
	policy: Rules.Policy,
	wave: StatMath.Sheet,
	conversion: StatMath.Sheet,
	halfConverted: boolean,
	elapsed: number,
	stillElapsed: number,
	crates: number,
	refreshing: boolean,
}
type Saved = {
	wave: StatMath.Sheet,
	conversion: StatMath.Sheet,
	halfConverted: boolean,
	elapsed: number,
	stillElapsed: number,
	crates: number,
}
local states: { [Player]: State } = {}
local Service = {}

local function countsOf(player: Player, state: State, hp: number, maxHp: number): { [string]: number }
	local items = Stats.getItemCounts(player)
	local weapons = Weapons.getWeapons(player)
	local counts: { [string]: number } = {
		cratesCollected = state.crates,
		shards = Shop.getShards(player),
		missingHealthPercent = if maxHp > 0 then math.round((1 - hp / maxHp) * 100) else 0,
		freeWeaponSlots = math.max(0, Weapons.getMaxWeapons(player) - #weapons),
		distinctWeapons = 0,
		tier4Weapons = 0,
		livingTrees = 0,
		structures = 0,
		distinctItems = 0,
		duplicateItemsAndWeapons = 0,
	}
	for id, count in items do
		counts[`item:{id}`] = count
		counts.distinctItems += 1
		counts.duplicateItemsAndWeapons += math.max(0, count - 1)
		local item = Config.Items.byId[id]
		if item then
			local key = `distinctItemsTier{item.tier}`
			counts[key] = (counts[key] or 0) + 1
		end
	end
	local weaponCounts: { [string]: number } = {}
	for _, weapon in weapons do
		if not weaponCounts[weapon.id] then
			counts.distinctWeapons += 1
		end
		if weapon.tier >= Config.Player.maxWeaponTier then
			counts.tier4Weapons += 1
		end
		weaponCounts[weapon.id] = (weaponCounts[weapon.id] or 0) + 1
	end
	for _, count in weaponCounts do
		counts.duplicateItemsAndWeapons += math.max(0, count - 1)
	end
	local ids = {}
	Enemy.collectIds(ids)
	for _, id in ids do
		if Enemy.getKind(id) == "Tree" then
			counts.livingTrees += 1
		end
	end
	counts.structures = Structures.sourceCount(player)

	return counts
end

local function refresh(player: Player)
	local state = states[player]
	if not state or state.refreshing then
		return
	end
	state.refreshing = true
	local hp, maxHp = Combat.getHp(player)
	local counts = countsOf(player, state, hp, maxHp)
	local dynamic = Rules.dynamic(state.policy, {
		hp = hp,
		maxHp = maxHp,
		moving = if Run.isActive() then Movement.isMoving(player) else nil,
		counts = counts,
		items = Stats.getItemCounts(player),
	})
	StatMath.add(dynamic, state.wave)
	StatMath.add(dynamic, state.conversion)
	Stats.setCharacterDynamic(player, dynamic)
	require(script.Parent.PlayerDataService).observeNativeInventory(player, counts, Stats.getSheet(player))
	state.refreshing = false
end

local function waveGain(player: Player, key: "onHurt" | "onDodge")
	local state = states[player]
	if state and Run.isActive() then
		StatMath.add(state.wave, state.policy[key])
		refresh(player)
	end
end

local function strike(player: Player, rule: Rules.Strike?)
	if not rule or Weapons.isPaused() or not Run.isActive() or Run.getParticipantState(player) ~= "Alive" then
		return
	end
	if Random.number("Combat", player) >= rule.chance then
		return
	end
	local ids, candidates = {}, {}
	Enemy.collectIds(ids)
	for _, id in ids do
		if Enemy.getKind(id) ~= "Tree" then
			table.insert(candidates, id)
		end
	end
	if #candidates > 0 then
		local index = math.min(#candidates, math.floor(Random.number("Combat", player) * #candidates) + 1)
		Weapons.queueCharacterStrike(player, candidates[index], Rules.statStrike(rule, Stats.getSheet(player)))
	end
end

local function clearWave()
	for player, state in states do
		table.clear(state.wave)
		table.clear(state.conversion)
		state.halfConverted = false
		state.elapsed, state.stillElapsed = 0, 0
		refresh(player)
	end
end

function Service.init()
	require(script.CharmSupport).init()
	require(script.KillChallenges).init()
	require(script.Steps).init()
	require(script.RecyclingChallenges).init()
	require(script.ConsumptionChallenges).init()
	Weapons.ExplosionResolved:Connect(require(script.Parent.PlayerDataService).observeNativeExplosion)
	Experience.OrbsPickedUp:Connect(require(script.Parent.PlayerDataService).observeNativeMaterials)
	HealingChallenges.init()
	Movement.init()
	Run.RunStarted:Connect(function(participants)
		table.clear(states)
		for _, player in participants do
			local policy = Rules.compile(Run.getParticipantClassId(player))
			if policy then
				states[player] = {
					policy = policy,
					wave = {},
					conversion = {},
					halfConverted = false,
					elapsed = 0,
					stillElapsed = 0,
					crates = 0,
					refreshing = false,
				}
			end
		end
	end)
	Run.WaveStarting:Connect(clearWave)
	Run.WaveEnding:Connect(function(wave)
		local ids, enemies, trees = {}, 0, 0
		Enemy.collectAllIds(ids)
		for _, id in ids do
			if Enemy.getKind(id) == "Tree" then
				trees += 1
			else
				enemies += 1
			end
		end
		local challenge = Danger.getChallenge(wave)
		local context: Rules.WaveContext = {
			enemies = enemies,
			trees = trees,
			-- regular enemies removed at the enemy maximum this wave (lazy require: SpawnDirector loads after us)
			removedForPerformance = require(script.Parent.SpawnDirector).getRemovedForPerformance(),
			horde = challenge ~= nil and challenge.kind == "Horde",
		}
		for player, state in states do
			require(script.Parent.PlayerDataService).observeNativeWaveTrees(player, trees)
			if Run.getParticipantState(player) == "Alive" then
				require(script.Parent.PlayerDataService).observeNativeWaveHp(player, Combat.getHp(player))
			end
			for _, effect in state.policy.source.remainingRules do
				if effect.customKey == "convert_stats_end_of_wave" and effect.sourceKey == "materials" then
					local chunks = math.max(
						0,
						math.floor(
							Shop.getShards(player)
								* Rules.numberParameter(effect, "pct_converted", 0)
								/ 100
								/ effect.amount
						)
					)
					if chunks > 0 then
						Shop.spendShards(player, chunks * effect.amount)
						local gain = state.policy.source.gainMultipliers.maxHp or 1
						Stats.addStats(player, {
							maxHp = math.round(
								chunks * Rules.numberParameter(effect, "to_value", 0) / (if gain > 0 then gain else 1)
							),
						})
					end
				end
			end
			Shop.setCharacterWaveReward(player, Rules.waveReward(state.policy, 0, context))
			table.clear(state.conversion) -- native wave-end TempStats reset precedes shop/harvesting
			refresh(player)
		end
	end)
	Run.PhaseChanged:Connect(function(phase)
		if phase == "Lobby" or phase == "Countdown" then
			table.clear(states)
		elseif phase ~= "Running" then
			clearWave()
		else
			for player in states do
				refresh(player)
			end
		end
	end)
	Run.addCheckpoint("Characters", function()
		local saved: { [Player]: Saved } = {}
		for player, state in states do
			saved[player] = {
				wave = table.clone(state.wave),
				conversion = table.clone(state.conversion),
				halfConverted = state.halfConverted,
				elapsed = state.elapsed,
				stillElapsed = state.stillElapsed,
				crates = state.crates,
			}
		end
		return saved
	end, function(saved: { [Player]: Saved })
		for player, data in saved do
			local state = states[player]
			if state then
				state.wave = table.clone(data.wave)
				state.conversion = table.clone(data.conversion)
				state.halfConverted = data.halfConverted
				state.elapsed, state.stillElapsed, state.crates = data.elapsed, data.stillElapsed, data.crates
			end
		end
	end)
	Run.WaveRetried:Connect(function()
		for player in states do
			refresh(player)
		end
	end)
	Stats.PermanentChanged:Connect(refresh)
	Weapons.Changed:Connect(refresh)
	Shop.ShardsChanged:Connect(refresh)
	Movement.Changed:Connect(function(player)
		local state = states[player]
		if state and Movement.isMoving(player) then
			state.stillElapsed = 0
		end
		refresh(player)
	end)
	Combat.PlayerDamaged:Connect(function(player)
		waveGain(player, "onHurt")
		local state = states[player]
		local explosion = state and state.policy.hurtExplosion
		if explosion and (explosion.chance >= 1 or Random.number("Combat", player) < explosion.chance) then
			Weapons.explodeCharacter(player, explosion.definition)
		end
	end)
	Combat.Dodged:Connect(function(player)
		waveGain(player, "onDodge")
	end)
	Combat.Healed:Connect(function(player)
		refresh(player)
		local state = states[player]
		strike(player, state and state.policy.healStrike)
	end)
	Experience.OrbsPickedUp:Connect(function(player, count)
		local state = states[player]
		if state and state.policy.pickupStrike then
			for _ = 1, count do
				strike(player, state.policy.pickupStrike)
			end
		end
	end)
	Loot.ConsumableCollected:Connect(function(player, _kind, wasFull, position)
		local state = states[player]
		if state and wasFull then
			Stats.addStats(player, state.policy.onFullConsumable)
		end
		local explosion = state and state.policy.consumableExplosion
		if position and explosion and Run.isActive() then
			if explosion.chance >= 1 or Random.number("Combat", player) < explosion.chance then
				Weapons.queueConsumableExplosion(player, explosion.definition, position, Stats.getItemCounts(player))
			end
		end
	end)
	Loot.ChestCollected:Connect(function(player)
		local state = states[player]
		if state then
			state.crates += 1
			refresh(player)
		end
	end)
	Shop.WaveEnding:Connect(function(player)
		local state = states[player]
		if state then
			Stats.addStats(player, state.policy.source.perWave)
		end
	end)
	Enemy.Stepped:Connect(function(dt)
		if not Run.isActive() then
			return
		end
		local wave = Schedule.wave(Run.getWave())
		local halfAt = wave.startsAt + (wave.endsAt - wave.startsAt) * C.halfWaveShare
		for player, state in states do
			if not state.halfConverted and Run.getElapsed() >= halfAt then
				state.halfConverted = true
				state.conversion = Rules.halfWaveConversion(state.policy, Stats.getPermanentSheet(player))
				refresh(player)
			end
			if Run.getParticipantState(player) == "Alive" then
				refresh(player)
				state.elapsed += dt
				while state.elapsed >= C.periodSeconds do
					state.elapsed -= C.periodSeconds
					if state.policy.selfDamage > 0 then
						Combat.drainPlayer(player, state.policy.selfDamage)
					end
				end
				if Movement.isMoving(player) then
					state.stillElapsed = 0
				else
					state.stillElapsed += dt
					while state.stillElapsed >= C.periodSeconds do
						state.stillElapsed -= C.periodSeconds
						local amount = Rules.periodicMaterials(state.policy, Shop.getShards(player))
						if amount > 0 then
							Shop.addShards(player, amount)
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return Service
