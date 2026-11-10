--!strict
-- Pure native Dig Site counts, collision and scored placement; DiggingService calls these at wave start and each tick.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.Digging)
local Items = require(Shared.Config.Items)
local Classes = require(Shared.Config.Classes)
local Rules = {}
function Rules.siteCount(classId: string?, items: { [string]: number }, wave: number): number
	local result = 0
	local class = classId and Classes[classId]
	for _, rule in (class and class.native and class.native.remainingRules) or {} do
		if rule.sourceKey == "dig_sites" then
			result += rule.amount
		end
		if rule.sourceKey == "dig_sites_every_x_waves" then
			for _, parameter in rule.parameters do
				if
					parameter.name == "value2"
					and parameter.numberValue
					and parameter.numberValue > 0
					and wave % parameter.numberValue == 0
				then
					result += rule.amount
				end
			end
		end
	end
	for id, count in items do
		local item = Items.byId[id]
		for _, effect in (item and item.effects) or {} do
			if effect.action == "DigSites" and effect.per and effect.per > 0 and wave % effect.per == 0 then
				result += count * (effect.amount or 0)
			end
		end
	end
	return result
end
function Rules.contains(x: number, z: number, bodyX: number, bodyZ: number): boolean
	local dx = bodyX - math.clamp(bodyX, x - C.halfSize, x + C.halfSize)
	local dz = bodyZ - math.clamp(bodyZ, z - C.halfSize, z + C.halfSize)
	return dx * dx + dz * dz <= C.playerBodyRadius * C.playerBodyRadius + 1e-9
end
function Rules.position(bounds: any, existing: { any }, random: () -> number): (number, number)
	local function candidate(): (number, number)
		return bounds.center.X + math.clamp(
			(random() * 2 - 1) * bounds.halfX,
			-bounds.halfX + C.edgeMargin,
			bounds.halfX - C.edgeMargin
		),
			bounds.center.Z + math.clamp(
				(random() * 2 - 1) * bounds.halfZ,
				-bounds.halfZ + C.edgeMargin,
				bounds.halfZ - C.edgeMargin
			)
	end
	local function score(x, z)
		local result = math.sqrt((x - bounds.center.X) ^ 2 + (z - bounds.center.Z) ^ 2) / C.minimumCenterDistance
		for _, site in existing do
			result = math.min(result, math.sqrt((x - site.x) ^ 2 + (z - site.z) ^ 2) / C.minimumSpacing)
		end
		return result
	end
	local x, z = candidate()
	local best = score(x, z)
	for _ = 1, C.placementTries do
		if best >= 1 then
			break
		end
		local nx, nz = candidate()
		local value = score(nx, nz)
		if value > best then
			x, z, best = nx, nz, value
		end
	end
	return x, z
end
return Rules
