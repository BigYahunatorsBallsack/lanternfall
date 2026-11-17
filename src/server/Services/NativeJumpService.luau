--!strict
-- Captures trusted jump starts and cancels warnings on death/landing/cleanup; EnemySim owns all motion and damage.
local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)
local Enemies = require(Shared.Config.Enemies)
local Enemy = require(script.Parent.EnemySim)
local Jump = require(script.Parent.EnemySim.NativeJump)
local Run = require(script.Parent.RunDirector)
local Service = {}
local active: { [number]: Jump.State } = {}
local pending: { Types.NativeJumpInfo } = {}
local function send(batch: Types.NativeJumpBatch)
	for _, player in Run.getParticipants() do
		Net.fireClient("NativeJumps", player, batch)
	end
end
local function clear()
	table.clear(active)
	table.clear(pending)
	send({ reset = true, started = {}, ended = {} })
end
local function start(id: number, kind: Enemies.Enemy, state: Jump.State)
	local rule = kind.nativeJump
	if Run.getPhase() ~= "Running" or not rule or not kind.nativeJumpPresentation then
		return
	end
	local now = workspace:GetServerTimeNow()
	active[id] = state
	table.insert(pending, {
		id = id,
		typeId = kind.typeId,
		startX = state.startX,
		startZ = state.startZ,
		targetX = state.targetX,
		targetZ = state.targetZ,
		at = now,
	})
end
local function step()
	local ended = {}
	for id, state in active do
		if not state.jumping or not (Enemy.isAlive(id) or Enemy.isCharmed(id)) then
			active[id] = nil
			table.insert(ended, id)
		end
	end
	if #pending > 0 or #ended > 0 then
		send({ started = pending, ended = ended })
		pending = {}
	end
end
function Service.init()
	Enemy.NativeJumpStarted:Connect(start)
	Enemy.Stepped:Connect(step)
	Run.RunStarted:Connect(clear)
	Run.RunEnded:Connect(clear)
	Run.PhaseChanged:Connect(function(phase)
		if phase ~= "Running" then
			clear()
		end
	end)
end
return Service
