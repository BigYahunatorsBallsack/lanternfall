--!strict
-- Source slash attack lifecycle, real animated rectangle collision and bounded cosmetic batches; EnemySim emits trusted volley requests.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.NightmareEnemies)
local Geometry = require(Shared.Util.NativeSlashGeometry)
local Types = require(Shared.Net.Types)
local Net = require(Shared.Net)
local Enemy = require(script.Parent.EnemySim)
local Run = require(script.Parent.RunDirector)
local Random = require(script.Parent.RandomService)
local PIXEL = Config.Player.moveSpeed / C.runtimeCompatibility.referencePlayerSpeedPixels
local Service = {}
type Shot = { info: Types.NativeSlashInfo, damage: number, age: number }
local shots: { Shot } = {}
local fired: { Types.NativeSlashInfo } = {}
local ended: { number } = {}
local nextId = 0
local function flush(reset: boolean?)
	if not reset and #fired == 0 and #ended == 0 then
		return
	end
	local batch = { reset = reset, fired = fired, ended = ended }
	for _, player in Run.getParticipants() do
		Net.fireClient("NativeSlashes", player, batch)
	end
	fired = {}
	ended = {}
end
local function clear()
	table.clear(shots)
	fired = {}
	ended = {}
	flush(true)
end
local function sourceAlive(id: number): boolean
	return Enemy.isAlive(id) or Enemy.isCharmed(id)
end
local function start(id: number, tx: number, tz: number, damage: number, owner: number?)
	if Run.getPhase() ~= "Running" or not sourceAlive(id) then
		return
	end
	local name = Enemy.getKind(id)
	if name ~= "MadSlasher" then
		return
	end
	local a = C.enemies.MadSlasher.attack
	local player = if owner then Players:GetPlayerByUserId(owner) else nil
	local volley = Geometry.volley(
		tx,
		tz,
		a.projectile_spawn_spread,
		a.projectile_speed * PIXEL,
		a.number_projectiles,
		PIXEL,
		function()
			return Random.number("Combat", player)
		end
	)
	for _, shot in volley do
		nextId += 1
		local info = {
			id = nextId,
			sourceId = id,
			ownerId = owner,
			x = shot.x,
			z = shot.z,
			dx = shot.dx,
			dz = shot.dz,
			speed = shot.speed,
			at = workspace:GetServerTimeNow(),
		}
		table.insert(shots, { info = info, damage = math.round(damage), age = 0 })
		table.insert(fired, info)
	end
end
local function collision(shot: Shot, age: number): boolean
	local info = shot.info
	if not Geometry.active(age) then
		return false
	end
	if info.ownerId then
		local ids = {}
		Enemy.collectIds(ids)
		for _, id in ids do
			local name = Enemy.getKind(id)
			if not name or name == "Tree" then
				continue
			end
			local at, hurtRadius = Enemy.getHurtGeometry(id)
			if at and hurtRadius and Geometry.contains(info, age, at.X, at.Z, hurtRadius, PIXEL) then
				Enemy.damage(id, shot.damage, nil)
				return true
			end
		end
	else
		for _, player in Run.getParticipants() do
			local at, hurtRadius = Enemy.getPlayerHurtGeometry(player)
			if
				Run.getParticipantState(player) == "Alive"
				and at
				and hurtRadius
				and Geometry.contains(info, age, at.X, at.Z, hurtRadius, PIXEL)
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
		local age = math.min(C.slash.stopAt, math.max(0, now - shot.info.at))
		local stop = not sourceAlive(shot.info.sourceId)
		while not stop and shot.age < age - 1e-9 do
			local nextFrame = (math.floor(shot.age * C.rules.physicsRate + 1e-7) + 1) / C.rules.physicsRate
			shot.age = math.min(age, nextFrame)
			stop = collision(shot, shot.age)
		end
		if stop or age >= C.slash.stopAt then
			table.insert(ended, shot.info.id)
			table.remove(shots, index)
		end
	end
	flush()
end
function Service.init()
	Enemy.NativeSlash:Connect(start)
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
