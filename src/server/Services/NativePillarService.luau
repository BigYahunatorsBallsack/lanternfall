--!strict
-- Source Enigmacursor pillar hit windows and faction collisions; EnemySim emits trusted shots, existing BossTelegraphs show explicit fallback circles.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.JungleWalkers).shootingRules
local Kinds = require(Shared.Util.EnemyKinds)
local Net = require(Shared.Net)
local Enemy = require(script.Parent.EnemySim)
local Run = require(script.Parent.RunDirector)
local Map = require(script.Parent.MapService)
local Service = {}
local pixel = Config.Stats.range.studsPerPoint
type Shot = {
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	damage: number,
	owner: number?,
	at: number,
	age: number,
}
local shots: { Shot } = {}
local pending = {}
local function clear()
	table.clear(shots)
	table.clear(pending)
end
local function start(
	source: number,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	damage: number,
	owner: number?
)
	local name = Enemy.getKind(source)
	local kind = name and Kinds.get(name)
	if Run.getPhase() ~= "Running" or not kind or not kind.ranged or not kind.ranged.nativePillar then
		return
	end
	local at = workspace:GetServerTimeNow()
	-- The source pillar rotates its Hitbox local offset with its travel direction.
	local offset = C.pillar.offsetPoints
	x += (dx * offset[1] - dz * offset[2]) * pixel
	z += (dz * offset[1] + dx * offset[2]) * pixel
	table.insert(
		shots,
		{ x = x, z = z, dx = dx, dz = dz, speed = speed, damage = math.round(damage), owner = owner, at = at, age = 0 }
	)
	table.insert(pending, {
		shape = "Circle",
		x = x,
		z = z,
		radius = C.pillar.radiusPoints * pixel,
		startsAt = at,
		hitsAt = at + C.pillar.hitFrom,
		vx = dx * speed,
		vz = dz * speed,
	})
end
local function collision(shot: Shot, age: number): boolean
	if age < C.pillar.hitFrom or age >= C.pillar.hitUntil then
		return false
	end
	local x, z = shot.x + shot.dx * shot.speed * age, shot.z + shot.dz * shot.speed * age
	local radius = C.pillar.radiusPoints * pixel
	if shot.owner then
		local ids = {}
		Enemy.collectIds(ids)
		for _, id in ids do
			local name, elite = Enemy.getKind(id)
			local kind = name and Kinds.get(name, elite)
			local at = Enemy.getPosition(id)
			if
				kind
				and name ~= "Tree"
				and at
				and (at.X - x) ^ 2 + (at.Z - z) ^ 2 <= (radius + (kind.hurtRadius or kind.radius)) ^ 2
			then
				Enemy.damage(id, shot.damage, nil)
				return true
			end
		end
	else
		for _, player in Run.getParticipants() do
			local at = Map.getRootPosition(player)
			if
				Run.getParticipantState(player) == "Alive"
				and at
				and (at.X - x) ^ 2 + (at.Z - z) ^ 2 <= (radius + Config.Simulation.playerRadius) ^ 2
			then
				Enemy.ShotHit:Fire(player, shot.damage)
				return true
			end
		end
	end
	return false
end
local function step()
	if Run.getPhase() ~= "Running" then
		return
	end
	local now = workspace:GetServerTimeNow()
	for index = #shots, 1, -1 do
		local shot = shots[index]
		local age = math.min(C.pillar.stopAt, math.max(0, now - shot.at))
		local stopped = false
		while not stopped and shot.age < age - 1e-9 do
			local frame = (math.floor(shot.age * C.frameRate + 1e-7) + 1) / C.frameRate
			shot.age = math.min(age, frame)
			stopped = collision(shot, shot.age)
		end
		-- Normal Enigmacursor does not delete projectiles when its source dies.
		if stopped or age >= C.pillar.stopAt then
			table.remove(shots, index)
		end
	end
	if #pending > 0 then
		for _, player in Run.getParticipants() do
			Net.fireClient("BossTelegraphs", player, pending)
		end
		pending = {}
	end
end
function Service.init()
	Enemy.NativePillar:Connect(start)
	Enemy.Stepped:Connect(step)
	Run.RunStarted:Connect(clear)
	Run.RunEnded:Connect(clear)
	Run.PhaseChanged:Connect(function(phase)
		if phase ~= "Running" then
			clear()
		end
	end)
end
function Service.getCount(): number
	return #shots
end
return Service
