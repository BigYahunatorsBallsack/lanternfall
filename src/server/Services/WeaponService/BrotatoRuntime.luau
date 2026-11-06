--!strict
-- Wave-local original weapon growth, held bonuses and conditional stats; driven by WeaponService.
local Arsenal = require(script.Parent.Arsenal)
local WeaponStats = require(script.Parent.WeaponStats)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Runtime = {}

function Runtime.step(
	weapons: { Arsenal.Weapon },
	dt: number,
	moving: boolean,
	hp: number,
	maxHp: number,
	drain: (number) -> ()
): { [string]: number }
	local result: { [string]: number } = {}
	for _, weapon in weapons do
		local s, state = weapon.stats, weapon.state
		if s.timedSeconds then
			state.growthElapsed = (state.growthElapsed or 0) + dt
			while state.growthElapsed >= s.timedSeconds do
				state.growthElapsed -= s.timedSeconds
				state.baseGain = (state.baseGain or 0) + (s.timedBaseDamage or 0)
				state.attackSpeedGain = (state.attackSpeedGain or 0) + (s.timedAttackSpeed or 0)
			end
		end
		if s.selfDamageSeconds then
			state.drainElapsed = (state.drainElapsed or 0) + dt
			while state.drainElapsed >= s.selfDamageSeconds do
				state.drainElapsed -= s.selfDamageSeconds
				drain(s.selfDamage)
			end
		end
		result.attackSpeed = (result.attackSpeed or 0) + (state.attackSpeedGain or 0)
		result.damage = (result.damage or 0)
			+ (state.hurtDamageGain or 0)
			+ (if moving then 0 else s.stationaryDamage or 0)
		if s.missingHpLifeSteal then
			result.lifeSteal = (result.lifeSteal or 0)
				+ math.floor(math.max(0, 1 - hp / math.max(1, maxHp)) / s.missingHpLifeSteal + 1e-6)
		end
	end
	return result
end

function Runtime.hurt(weapons: { Arsenal.Weapon })
	for _, weapon in weapons do
		if weapon.stats.timedBaseDamage then
			weapon.state.baseGain = 0
		end
		if weapon.stats.damageOnHurt then
			weapon.state.hurtDamageGain = (weapon.state.hurtDamageGain or 0) + weapon.stats.damageOnHurt
		end
	end
end

function Runtime.recompute(weapons: { Arsenal.Weapon }, bonuses: { [string]: number })
	local copies: { [string]: number } = {}
	for _, weapon in weapons do
		copies[weapon.id] = (copies[weapon.id] or 0) + 1
	end
	for _, weapon in weapons do
		if not weapon.config.brotato then
			continue
		end
		local config = weapon.config
		local stamp = `{weapon.tier}:{copies[weapon.id]}:{weapon.state.baseGain or 0}`
		if weapon.state.derivedBonuses == bonuses and weapon.state.derivedStamp == stamp then
			continue
		end
		local tiered = WeaponStats.compute(config, weapon.tier, bonuses, nil, Config.Player.minWeaponCooldown)
		local extra = (tiered.damagePerCopy or 0) * (copies[weapon.id] - 1) + (weapon.state.baseGain or 0)
		if extra ~= 0 then
			tiered.damage += extra * WeaponStats.damageFactor(bonuses)
		end
		weapon.stats = tiered
		weapon.state.derivedBonuses = bonuses
		weapon.state.derivedStamp = stamp
	end
end

return Runtime
