--!strict
-- Pure native pre-hit Charm eligibility and endless dilution; friendly-world conversion owns all state changes.
local C = require(game:GetService("ReplicatedStorage").Shared.Config.Charm)
local Rules = {}
export type Target = {
	kind: string,
	hp: number,
	maxHp: number,
	elite: boolean?,
	boss: boolean?,
	charmed: boolean?,
	canBeCharmed: boolean?,
}
function Rules.chance(stats: { [string]: number }, target: Target, count: number, endless: number): number
	if
		target.hp <= 0
		or target.maxHp <= 0
		or target.elite
		or target.boss
		or target.charmed
		or target.canBeCharmed == false
		or C.excludedKinds[target.kind]
		or count >= C.maximumPerOwner
	then
		return 0
	end
	if target.hp / target.maxHp >= (stats.charmThreshold or 0) then
		return 0
	end
	return (stats.charmChance or 0) / math.max(1, endless / C.endlessDivisor)
end
function Rules.success(chance: number, roll: () -> number): boolean
	-- Native Utils.get_chance_success never consumes RNG for zero chance, otherwise includes equality.
	return chance ~= 0 and roll() <= chance
end
return Rules
