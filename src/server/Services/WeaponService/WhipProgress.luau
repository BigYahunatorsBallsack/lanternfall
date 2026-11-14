--!strict
-- Captures native Whip/Jungle kill eligibility before synchronous hit callbacks can clear actors or end the run; called only by BrotatoWhip.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rule = require(Shared.Config.CharacterWeaponAccess).Flail
export type Receipt = { player: Player, zoneId: number }
local Progress = {}
local capture: ((number, number) -> Receipt?)? = nil
local credit: ((Player, number) -> ())? = nil
-- WeaponService owns world/profile dependencies; loading a behavior never starts or imports those services.
function Progress.configure(context: (number, number) -> Receipt?, observe: (Player, number) -> ())
	capture, credit = context, observe
end
function Progress.capture(weaponId: string, ownerId: number, targetId: number): Receipt?
	if weaponId ~= Rule.sourceWeaponId or not capture then
		return nil
	end
	return capture(ownerId, targetId)
end
function Progress.credit(receipt: Receipt?, killed: boolean)
	if receipt and killed and credit then
		credit(receipt.player, receipt.zoneId)
	end
end
return Progress
