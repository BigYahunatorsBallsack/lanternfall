--!strict
-- Native flat burn truncation, item base additions and percent rounding; WeaponStats and OfferText share this.
local Damage = require(script.Parent.NativeWeaponDamage)
local C = require(script.Parent.Parent.Config.Combat)
local Burn = {}
local native = { nativeTiming = 1 }
function Burn.damage(base: number, sheet: { [string]: number }): number
	return Damage.total(
		base + (sheet.nativeGlobalBurnDamage or 0) + (sheet.elementalDamage or 0),
		Damage.factor(sheet, false),
		native
	)
end
function Burn.interval(speed: number): number
	return math.max(C.nativeBurn.minimumTickSeconds, C.burn.tickSeconds * (1 - speed / 100))
end
return Burn
