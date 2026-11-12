--!strict
-- Native charmed Healer entry healing and Buffer ally boosts; CharacterService initializes the server-only signals.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.Charm)
local Run = require(script.Parent.Parent.RunDirector)
local Enemy = require(script.Parent.Parent.EnemySim)
local Stats = require(script.Parent.Parent.StatService)
local Combat = require(script.Parent.Parent.CombatService)
local Map = require(script.Parent.Parent.MapService)
local Structures = require(script.Parent.Parent.StructureService)
local Random = require(script.Parent.Parent.RandomService)
local Support = {}
local gains: { [Player]: { [string]: number } } = {}
local buffs: { [Player]: { expires: number, beforeMax: number, speed: number, attackSpeed: number } } = {}
local function body(player: Player): Vector3?
	local at = Map.getRootPosition(player)
	return if at then Vector3.new(at.X, require(Shared.Config.Map).arena.center.Y, at.Z + C.playerBodyOffsetZ) else nil
end
local function boostPlayer(player: Player, now: number, rule: any)
	local hp, maximum = Combat.getHp(player)
	local sheet = gains[player] or {}
	gains[player] = sheet
	local added = math.floor(maximum * rule.playerMaxHp / 100)
	sheet.maxHp = (sheet.maxHp or 0) + added
	sheet.speed = (sheet.speed or 0) + rule.playerSpeed
	sheet.attackSpeed = (sheet.attackSpeed or 0) + rule.playerAttackSpeed
	buffs[player] = {
		expires = now + rule.duration,
		beforeMax = maximum,
		speed = rule.playerSpeed,
		attackSpeed = rule.playerAttackSpeed,
	}
	Stats.setCharmBoost(player, sheet)
	Combat.setBoostHealth(player, hp + added)
end
local function expire(now: number)
	for player, buff in buffs do
		if now < buff.expires then
			continue
		end
		local hp, maximum = Combat.getHp(player)
		local sheet = gains[player]
		-- Stable Player.boost_ended removes the current maximum difference, not the original raw HP grant.
		sheet.maxHp -= (maximum - buff.beforeMax)
		sheet.speed -= buff.speed
		sheet.attackSpeed -= buff.attackSpeed
		buffs[player] = nil
		Stats.setCharmBoost(player, sheet)
		Combat.setBoostHealth(player, hp)
	end
end
local function tick(member: any, x: number, z: number)
	local kind = member.kind.id
	if kind ~= "Mender" and kind ~= "Herald" and kind ~= "CorruptedBuffer" then
		return
	end
	local buffer = if kind == "CorruptedBuffer" then C.corruptedBuffer else C.buffer
	local now = workspace:GetServerTimeNow()
	local at = Vector3.new(x, require(Shared.Config.Map).arena.center.Y, z)
	if kind == "Mender" then
		local inside = {}
		for _, player in Run.getParticipants() do
			local position = body(player)
			if
				Run.getParticipantState(player) == "Alive"
				and position
				and (position - at).Magnitude <= C.healer.radius + C.playerBodyRadius
			then
				inside[player] = true
				if not (member.playersInside and member.playersInside[player]) then
					local hp, maximum = Combat.getHp(player)
					if hp < maximum then
						Combat.healPlayer(player, math.floor(C.healer.base + (Run.getWave() - 1) * C.healer.perWave))
					end
				end
			end
		end
		member.playersInside = inside
		return
	end
	if not member.nextBoostAt then
		local first = (member.base.spawnedAt or now) + buffer.firstSeconds
		local convertedAt = member.expires - C.duration
		member.nextBoostAt = if first > convertedAt
			then first
			else first + (math.floor((convertedAt - first) / buffer.interval) + 1) * buffer.interval
	end
	if now < member.nextBoostAt then
		return
	end
	member.nextBoostAt = now + buffer.interval
	local candidates = {}
	for _, player in Run.getParticipants() do
		local position = body(player)
		if
			not buffs[player]
			and Run.getParticipantState(player) == "Alive"
			and position
			and (position - at).Magnitude <= buffer.radius + C.playerBodyRadius
		then
			table.insert(candidates, { player = player })
		end
	end
	for _, id in Structures.boostCandidates(at, buffer.radius) do
		table.insert(candidates, { structure = id })
	end
	local owner = Players:GetPlayerByUserId(member.owner)
	for _ = 1, math.min(buffer.count, #candidates) do
		local index = math.min(#candidates, math.floor(Random.number("Combat", owner) * #candidates) + 1)
		local chosen = table.remove(candidates, index)
		if chosen.player then
			boostPlayer(chosen.player, now, buffer)
		else
			Structures.applyBoost(
				chosen.structure,
				buffer.structureDamage,
				buffer.structureRange,
				buffer.structureAttackSpeed,
				buffer.duration
			)
		end
	end
end
local function clear()
	for player in gains do
		Stats.setCharmBoost(player, {})
	end
	table.clear(gains)
	table.clear(buffs)
end
function Support.init()
	Enemy.CharmSupport:Connect(tick)
	Enemy.Stepped:Connect(function()
		expire(workspace:GetServerTimeNow())
	end)
	Run.RunStarted:Connect(clear)
	Run.WaveStarting:Connect(clear)
	Run.WaveRetried:Connect(clear)
	Run.PhaseChanged:Connect(function(phase)
		if phase == "Shop" or phase == "Lobby" or phase == "Ended" then
			clear()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		gains[player] = nil
		buffs[player] = nil
	end)
end
return Support
