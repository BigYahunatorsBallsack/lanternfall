--!strict
-- Native movement-step milestones from validated world displacement; CharacterService initializes, never trusts movement intent for gains.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.CharacterMechanics).steps
local Run = require(script.Parent.Parent.RunDirector)
local Enemy = require(script.Parent.Parent.EnemySim)
local Map = require(script.Parent.Parent.MapService)
local Stats = require(script.Parent.Parent.StatService)
local Weapons = require(script.Parent.Parent.WeaponService)
local Players = game:GetService("Players")
local Steps = {}
local states: { [Player]: { at: Vector3?, count: number } } = {}
local function reset()
	table.clear(states)
	for _, p in Run.getParticipants() do
		states[p] = { at = nil, count = 0 }
	end
end
function Steps.init()
	Run.RunStarted:Connect(reset)
	Run.WaveStarting:Connect(reset)
	Run.WaveRetried:Connect(reset)
	Run.RunEnded:Connect(function()
		table.clear(states)
	end)
	Map.CharacterPlaced:Connect(function(p, _, at)
		local s = states[p]
		if s then
			s.at = at
		end
	end)
	Map.MovementCorrected:Connect(function(p)
		local s = states[p]
		if s then
			s.at = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		states[p] = nil
	end)
	Enemy.Stepped:Connect(function()
		if not Run.isActive() then
			return
		end
		for p, s in states do
			local at = Map.getRootPosition(p)
			if at and s.at and Run.getParticipantState(p) == "Alive" then
				local distance = Vector3.new(at.X - s.at.X, 0, at.Z - s.at.Z).Magnitude
				local before = math.floor(s.count + 1e-9)
				s.count += distance * C.perAnimation / (C.baseSpeed * C.animationSeconds)
				local after = math.floor(s.count + 1e-9)
				if after > before then
					local gain = 0
					for _, weapon in Weapons.getWeapons(p) do
						local stats = weapon.stats
						if stats.stepEvery then
							gain += (math.floor(after / stats.stepEvery) - math.floor(before / stats.stepEvery)) * stats.stepRangeGain
						end
					end
					if gain > 0 then
						Stats.addStats(p, { range = gain })
					end
				end
			end
			s.at = at
		end
	end)
end
function Steps.getCount(p: Player): number
	local s = states[p]
	return if s then s.count else 0
end
return Steps
