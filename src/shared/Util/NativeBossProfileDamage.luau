--!strict
-- Registered native boss attack damage, including late wrapper registration and later explicit resets; EnemySim owns the source global factor provider.
local R = require(script.Parent.Parent.Config.NativeEnemyStatCache).rules
local Damage = {}
type Attack = { damage: { base: number, perWave: number, registeredAfterBossInit: boolean? }? }
function Damage.compute(
	attacks: { Attack },
	wave: number,
	raw: (number) -> number,
	earlyShare: number,
	resetPercent: number?
): { number }
	local result = {}
	for index, attack in attacks do
		local rule = assert(attack.damage, "Separate source damage requires a record for every attack")
		local share = if resetPercent ~= nil
			then math.max(R.minimumFactor, 1 + resetPercent / R.percent)
			elseif rule.registeredAfterBossInit then 1
			else earlyShare
		result[index] = math.round(raw(rule.base + rule.perWave * math.max(0, wave - 1)) * share)
	end
	return result
end
return Damage
