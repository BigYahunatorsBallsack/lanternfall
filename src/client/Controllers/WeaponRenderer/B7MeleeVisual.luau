--!strict
-- Pooled directional blade strokes for B7 melee Visuals, driven by server Strike events.
local Types = require(game:GetService("ReplicatedStorage").Shared.Net.Types)
local VisualKit = require(script.Parent.VisualKit)
return function(color: Color3)
	local pool = VisualKit.objectPool(function()
		return VisualKit.part("MeleeStroke", Enum.PartType.Block, Vector3.one, color)
	end, function(part: BasePart): { BasePart }
		return { part }
	end)
	local strikes: { any } = {}
	local visual = {}
	function visual.effect(effect: Types.WeaponEffect)
		if effect.kind == "Strike" then
			table.insert(strikes, { effect = effect })
		end
	end
	function visual.render(frame: VisualKit.Frame)
		for i = #strikes, 1, -1 do
			local strike = strikes[i]
			local e = strike.effect
			local t = math.max(0, (frame.now - e.at) / e.duration)
			if t >= 1 then
				if strike.part then
					pool:release(strike.part)
				end
				table.remove(strikes, i)
			else
				local part = strike.part or pool:acquire(frame.folder)
				strike.part = part
				local angle = math.atan2(e.dz, e.dx) + math.rad(e.angle) * (t - 0.5)
				local reach = if e.angle == 0 then e.range * math.sin(t * math.pi) else e.range
				local x, z = math.cos(angle) * reach, math.sin(angle) * reach
				local a = Vector3.new(e.x, frame.floorY + 2, e.z)
				local b = a + Vector3.new(x, 0, z)
				part.Size = Vector3.new(e.radius, 0.25, math.max(0.01, reach))
				part.Transparency = t
				frame.move(part, if reach > 0.001 then CFrame.lookAt((a + b) / 2, b) else CFrame.new(a))
			end
		end
	end
	function visual.clear()
		for _, strike in strikes do
			if strike.part then
				pool:release(strike.part)
			end
		end
		table.clear(strikes)
	end
	return visual
end
