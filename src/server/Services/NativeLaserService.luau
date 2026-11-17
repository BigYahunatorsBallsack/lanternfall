--!strict
-- Source centered hostile enemy-laser instances, translation following, warning and first-hit stop; EnemySim sends trusted attack requests.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.NativeEnemyLaser)
local Pixel = require(Shared.Config.Stats).range.studsPerPoint
local Geometry = require(Shared.Util.NativeEnemyLaser)
local Kinds = require(Shared.Util.EnemyKinds)
local Net = require(Shared.Net)
local Enemy = require(script.Parent.EnemySim)
local Run = require(script.Parent.RunDirector)
local Service = {}
type Shot = {
	source: number,
	x: number,
	z: number,
	ox: number,
	oz: number,
	dx: number,
	dz: number,
	damage: number,
	steppedAt: number,
	clock: Geometry.State,
}
local shots: { Shot } = {}
local pending = {}
local function clear()
	table.clear(shots)
	table.clear(pending)
end
local function updatePosition(shot: Shot, at: Vector3)
	shot.x, shot.z = at.X + shot.ox, at.Z + shot.oz
end
local function start(source: number, x: number, z: number, dx: number, dz: number, damage: number)
	local name = Enemy.getKind(source)
	local kind = name and Kinds.get(name)
	local at = Enemy.getPosition(source)
	if Run.getPhase() ~= "Running" or not kind or not kind.nativeBoss or not at then
		return
	end
	local allowed = false
	for _, attack in kind.nativeBoss.attacks do
		if attack.kind == "InfiniteLaser" then
			allowed = true
		end
	end
	if not allowed then
		return
	end
	local now = workspace:GetServerTimeNow()
	table.insert(shots, {
		source = source,
		x = x,
		z = z,
		ox = x - at.X,
		oz = z - at.Z,
		dx = dx,
		dz = dz,
		damage = math.round(damage),
		steppedAt = now,
		clock = Geometry.new(),
	})
	local half = C.halfExtentsPoints[1] * Pixel
	local stop = (math.ceil(C.delaySeconds * C.frameRate) + math.ceil(C.afterSeconds * C.frameRate) - 1) / C.frameRate
	table.insert(pending, {
		shape = "Line",
		x = x - dx * half,
		z = z - dz * half,
		dx = dx,
		dz = dz,
		length = 2 * half,
		radius = C.halfExtentsPoints[2] * Pixel,
		startsAt = now,
		hitsAt = now + C.delaySeconds,
		endsAt = now + stop,
	})
end
local function collision(shot: Shot): boolean
	for _, player in Run.getParticipants() do
		local at, radius = Enemy.getPlayerHurtGeometry(player, false)
		if
			Run.getParticipantState(player) == "Alive"
			and at
			and radius
			and Geometry.contains(shot.x, shot.z, shot.dx, shot.dz, at.X, at.Z, radius)
		then
			Enemy.ShotHit:Fire(player, shot.damage)
			return true
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
		local at = Enemy.getPosition(shot.source)
		if at then
			updatePosition(shot, at)
		end
		Geometry.step(shot.clock, math.max(0, now - shot.steppedAt), function()
			return collision(shot)
		end)
		shot.steppedAt = now
		if shot.clock.stopped then
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
	Enemy.NativeLaser:Connect(start)
	Enemy.Stepped:Connect(step)
	Enemy.EnemyKilled:Connect(function(info)
		-- Capture the final pose before World compacts dead bodies. Source lasers persist after their parent dies.
		for _, shot in shots do
			if shot.source == info.id then
				updatePosition(shot, info.position)
			end
		end
	end)
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
