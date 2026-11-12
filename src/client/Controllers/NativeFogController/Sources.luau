--!strict
-- Collects actual explosion events for the shared fog mask; independent of cosmetic VFX pool limits. Burning actors use their existing status feed.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.NativeFog)
local Rules = require(Shared.Util.NativeFogRules)
local Sources = {}
local enabled = false
local transient: { { x: number, z: number, at: number, hold: number, kind: string } } = {}
function Sources.setEnabled(value: boolean)
	enabled = value
	if not value then
		table.clear(transient)
	end
end
function Sources.effect(effect: any)
	if not enabled then
		return
	end
	local kind = effect.kind
	if kind ~= "Blast" then
		return
	end
	table.insert(transient, {
		x = effect.x or 0,
		z = effect.z or 0,
		at = effect.at,
		hold = C.rules.explosionHoldSeconds,
		kind = "structure",
	})
end
function Sources.visit(now: number, emit: (number, number, string, number, number) -> ())
	for i = #transient, 1, -1 do
		local light = transient[i]
		local age = math.max(0, now - light.at)
		local fade = Rules.transientFade(age, light.hold)
		if fade <= 0 then
			table.remove(transient, i)
		else
			emit(light.x, light.z, light.kind, age, fade)
		end
	end
end
return Sources
