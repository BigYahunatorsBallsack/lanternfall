--!strict
-- Native spawning attacks queue exact square-area child births; EnemySim and CharmedWorld retain faction/death policy.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rules = require(Shared.Util.NativeZoneSampling)
local Enemies = require(Shared.Config.Enemies)
local NativeSummons = {}
function NativeSummons.emit(
	world: any,
	id: number,
	rule: Enemies.NativeSpawn,
	owner: number?,
	random: () -> number,
	emit: (string, number, number, number?) -> ()
)
	local x, z = world:getPosition(id)
	if not x or not z then
		return
	end
	for _ = 1, rule.count do
		local sx, sz = Rules.inArea(random, world.params, x, z, rule.area, world.params.forbiddenCircles)
		emit(rule.enemy, sx, sz, owner)
	end
end
return NativeSummons
