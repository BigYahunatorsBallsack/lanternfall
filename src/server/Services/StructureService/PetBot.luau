--!strict
-- Bot-O-Mine owner-following, native shot cadence and queued mine requests; PetActors supplies fixed physics frames.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Run = require(script.Parent.Parent.RunDirector)
local Map = require(script.Parent.Parent.MapService)
local Enemy = require(script.Parent.Parent.EnemySim)
local Random = require(script.Parent.Parent.RandomService)
local Rules = require(script.Parent.PetRules)
local Placement = require(script.Parent.GroupedPlacement)
local Projectiles = require(script.Parent.Projectiles)
local Bot = {}
local scale = Config.Stats.range.studsPerPoint

local function flatRoot(player: Player, y: number): Vector3?
	local root = Map.getRootPosition(player)
	return if root then Vector3.new(root.X, y, root.Z) else nil
end
function Bot.goal(o: any): Vector3?
	if not o.playerTarget or Run.getParticipantState(o.playerTarget) ~= "Alive" then
		o.playerTarget = nil
		if Run.getParticipantState(o.owner) == "Alive" then
			o.playerTarget = o.owner
		else
			local nearest = math.huge
			for _, player in Run.getParticipants() do
				local at = flatRoot(player, o.position.Y)
				if Run.getParticipantState(player) == "Alive" and at then
					local distance = (at - o.position).Magnitude
					if distance < nearest then
						o.playerTarget, nearest = player, distance
					end
				end
			end
		end
	end
	local root = o.playerTarget and flatRoot(o.playerTarget, o.position.Y)
	return if root and (root - o.position).Magnitude >= o.pet.stopDistancePoints * scale then root else nil
end

-- Returns a request rather than mutating the actor array during its physics step.
function Bot.step(o: any, sheet: { [string]: number }): any?
	if o.shotSheet ~= sheet then
		o.shotSheet = sheet
		o.shotStats = Rules.compute(o.pet.weapon, sheet, o.beastMaster)
	end
	o.cooldownFrames = math.max(0, o.cooldownFrames - 1)
	if o.cooldownFrames == 0 then
		local ids, target, distance = {}, nil, math.huge
		Enemy.queryRadius(o.position, o.shotStats.range, ids)
		for _, id in ids do
			local at = Enemy.getPosition(id)
			local d = (at - o.position).Magnitude
			if Enemy.getKind(id) ~= "Tree" and d <= o.shotStats.range and d < distance then
				target, distance = at, d
			end
		end
		if target and distance > 0 then
			local muzzle = o.position + Vector3.new(o.pet.muzzleXPoints * scale, 0, o.pet.muzzleZPoints * scale)
			Projectiles.launchPet(o.owner, muzzle, o.pet.weapon, sheet, { (target - o.position).Unit }, o.beastMaster)
			o.cooldownFrames = o.shotStats.cooldown * require(Shared.Config.Pets).frameRate
		end
	end
	o.mineFrames = math.max(0, o.mineFrames - 1)
	if o.mineFrames > 0 then
		return nil
	end
	o.mineFrames = o.pet.mineIntervalFrames
	local def = table.clone(Config.Structures.kinds.RuneMine)
	def.petMine, def.petBeastMaster = true, o.beastMaster
	local at = Placement.inArea(
		o.position,
		o.pet.mineAreaPoints * scale,
		Map.getArenaBounds(),
		Map.getObstacles(),
		function()
			return Random.number("Combat", o.owner)
		end
	)
	return { owner = o.owner, kind = "RuneMine", definition = def, at = at }
end
return Bot
