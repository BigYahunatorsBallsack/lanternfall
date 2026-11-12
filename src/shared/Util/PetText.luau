--!strict
-- Original pet descriptions with current source-derived values; UpgradeText and the lobby share the server's pet arithmetic.
local Shared = script.Parent.Parent
local C = require(Shared.Config.Pets)
local Structures = require(Shared.Config.Structures)
local Stats = require(script.Parent.NativePetStats)
local StatMath = require(script.Parent.StatMath)
local StatConfig = require(Shared.Config.Stats)
local Timing = require(script.Parent.NativeWeaponTiming)
local Text = {}
local function number(value: number): string
	return if value == math.floor(value) then tostring(value) else string.format("%.1f", value)
end
local function seconds(value: number): string
	return number(math.round(value / C.tooltipTimeStep) * C.tooltipTimeStep)
end
-- Original Utils.get_scaling_stat_icon_text rounds coefficients to whole percentage points.
local function scalingText(scaling: { [string]: number }): string
	local parts = {}
	for _, stat in StatConfig.order do
		local share = scaling[stat.id]
		if share ~= nil then
			table.insert(parts, `{if share > 0 then "+" else ""}{number(math.round(share * 100))}% {stat.displayName}`)
		end
	end
	return table.concat(parts, ", ")
end
function Text.line(id: string, sheet: { [string]: number }?, beastMaster: boolean?): string
	local pet, template = C.kinds[id], C.tooltips[id]
	if not pet or not template then
		return ""
	end
	local owner = sheet or StatMath.baseSheet()
	local master = if beastMaster ~= nil then beastMaster else (owner.nativePetScaling or 0) > 0
	local function damage(weapon): string
		return number(Stats.compute(weapon, owner, master).damage)
	end
	local function scaling(weapon): string
		return scalingText(Stats.weaponScaling(weapon, owner, master))
	end
	local args = { damage(pet.weapon), scaling(pet.weapon) }
	if id == "BonkDog" then
		table.insert(args, seconds(pet.explosion.cooldownFrames / C.frameRate))
		table.insert(args, damage(pet.explosion))
		table.insert(args, scaling(pet.explosion))
	elseif id == "BotOMine" then
		-- Original get_args applies structure speed here; the live Bot itself retains the raw mine-spawn cooldown.
		local speed = (owner.structureAttackSpeed or 0)
			+ (
				if (owner.nativeImprovedTools or 0) > 0
					then (owner.attackSpeed or 0) * Structures.improvedToolsShare
					else 0
			)
		local frames = math.max(C.minimumCooldownFrames, math.floor(pet.mineIntervalFrames * Timing.factor(speed)))
		table.insert(args, seconds(frames / C.frameRate))
		table.insert(args, damage(pet.mine))
		table.insert(args, scaling(pet.mine))
	elseif id == "Blazemander" then
		local burn = pet.ranged.burning
		table.insert(args, number(burn.ticks))
		table.insert(args, number(Stats.burnDamage(burn, owner, master)))
		table.insert(args, scalingText(Stats.scaling(burn.scaling, master)))
		table.insert(args, seconds(Stats.compute(pet.ranged, owner, master).cooldown))
		table.insert(args, damage(pet.ranged))
		table.insert(args, scaling(pet.ranged))
	elseif id == "Lootworm" then
		args = { number(pet.doubleChance * 100) .. "%" }
	end
	return (
		string.gsub(template, "{(%d+)}", function(index)
			return assert(args[tonumber(index) + 1], "Missing original pet tooltip argument")
		end)
	)
end
return Text
