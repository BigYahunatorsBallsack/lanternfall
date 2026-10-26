--!strict
-- Startup sanity check of all Config cross-references. Called once by the server bootstrap.
-- Returns a list of problems; an empty list means the data is consistent.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local ConfigCheck = {}

function ConfigCheck.run(): { string }
	local problems = {}
	local function problem(message: string)
		table.insert(problems, message)
	end

	for id, weapon in Config.Weapons do
		if weapon.id ~= id then
			problem(`Weapon key {id} does not match id {weapon.id}`)
		end
		if #weapon.levels ~= Config.Player.maxItemLevel then
			problem(`Weapon {id} has {#weapon.levels} levels, expected {Config.Player.maxItemLevel}`)
		end
	end

	for id, passive in Config.Passives do
		if passive.id ~= id then
			problem(`Passive key {id} does not match id {passive.id}`)
		end
	end

	for id, evolution in Config.Evolutions do
		if not Config.Weapons[evolution.weapon] then
			problem(`Evolution {id} needs unknown weapon {evolution.weapon}`)
		end
		if not Config.Passives[evolution.passive] then
			problem(`Evolution {id} needs unknown passive {evolution.passive}`)
		end
	end

	for id, class in Config.Classes do
		if class.available and not Config.Weapons[class.startWeapon] then
			problem(`Class {id} starts with unknown weapon {class.startWeapon}`)
		end
	end

	local typeIds = { [Config.Enemies.boss.typeId] = Config.Enemies.boss.id }
	for id, enemy in Config.Enemies.types do
		if typeIds[enemy.typeId] then
			problem(`Enemy {id} reuses typeId {enemy.typeId} of {typeIds[enemy.typeId]}`)
		end
		typeIds[enemy.typeId] = id
		if enemy.typeId < 1 or enemy.typeId > 255 then
			problem(`Enemy {id} typeId must be 1-255`)
		end
	end

	for _, step in Config.Run.spawn.mix do
		local sum = 0
		for enemyId, weight in step.weights do
			sum += weight
			if not Config.Enemies.types[enemyId] then
				problem(`Spawn mix at minute {step.fromMinute} uses unknown enemy {enemyId}`)
			end
		end
		if math.abs(sum - 1) > 1e-6 then
			problem(`Spawn mix at minute {step.fromMinute} sums to {sum}, expected 1`)
		end
	end

	for id, tier in Config.Difficulty.tiers do
		if tier.unlockedBy and not Config.Difficulty.tiers[tier.unlockedBy] then
			problem(`Difficulty {id} unlocked by unknown tier {tier.unlockedBy}`)
		end
	end

	return problems
end

return ConfigCheck
