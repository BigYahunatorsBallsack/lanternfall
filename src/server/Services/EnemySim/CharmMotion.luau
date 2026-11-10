--!strict
-- Native random movement retained or substituted by Charm; CharmedWorld calls this before stepping the existing AI.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.Charm)
local Motion = {}
function Motion.step(friends: any)
	local world = friends.world
	local p = world.params
	local function random(owner)
		return if friends.callbacks.random then friends.callbacks.random(owner) else math.random()
	end
	for id, member in friends.members do
		local mode = Config.movement[member.kind.id]
		if not mode then
			continue
		end
		local index = world.indexOf[id]
		local x, z = world.xs[index], world.zs[index]
		if
			world.hasGoal[index] and (world.goalXs[index] - x) ^ 2 + (world.goalZs[index] - z) ^ 2 > Config.goalPrecision ^ 2
		then
			continue
		end
		local tx, tz
		for _ = 1, Config.goalAttempts do
			if mode == "AroundTarget" and #friends.targetIds > 0 then
				local nearest, distance = 1, math.huge
				for target = 1, #friends.targetIds do
					local squared = (friends.targetXs[target] - x) ^ 2 + (friends.targetZs[target] - z) ^ 2
					if squared < distance then
						nearest, distance = target, squared
					end
				end
				member.movementRange = member.movementRange
					or Config.aroundRange + (random(member.owner) * 2 - 1) * Config.aroundRandomization
				tx = friends.targetXs[nearest] + (random(member.owner) * 2 - 1) * member.movementRange
				tz = friends.targetZs[nearest] + (random(member.owner) * 2 - 1) * member.movementRange
			else
				tx = p.minX + (p.maxX - p.minX) * random(member.owner)
				tz = p.minZ + (p.maxZ - p.minZ) * random(member.owner)
			end
			tx, tz = math.clamp(tx, p.minX, p.maxX), math.clamp(tz, p.minZ, p.maxZ)
			local valid = true
			for _, obstacle in p.obstacles do
				if (tx - obstacle.x) ^ 2 + (tz - obstacle.z) ^ 2 < obstacle.radius ^ 2 then
					valid = false
					break
				end
			end
			if valid then
				break
			end
		end
		world:setGoal(id, tx, tz)
	end
end
return Motion
