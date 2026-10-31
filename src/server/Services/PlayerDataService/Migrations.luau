--!strict
-- Upgrades saved player data step by step to ProfileTemplate.SCHEMA_VERSION (pure, tests/PlayerDataRules.spec.luau).
-- Called by PlayerDataService right after a profile loads, before ProfileStore's Reconcile fills in missing keys.
-- Every schema change adds one step here; steps only add or convert fields, they never drop one.

local Migrations = {}

-- steps[v] turns data of version v into version v + 1 (in place).
local steps: { [number]: (data: any) -> () } = {
	-- v1 -> v2 (Paket 12): wins, furthest wave and highest danger won, plus a record per character
	[1] = function(data)
		local stats = if type(data.stats) == "table" then data.stats else {}
		data.stats = stats
		stats.wins = stats.wins or 0
		stats.bestWave = stats.bestWave or 0
		stats.bestDanger = stats.bestDanger or -1
		if type(data.characterStats) ~= "table" then
			data.characterStats = {}
		end
	end,
}

Migrations.steps = steps

-- Runs every step from the data's version up to `target`. Returns the version the data had. Data from a newer schema
-- (a newer server wrote it) is left untouched; PlayerDataService warns about it.
function Migrations.run(data: any, target: number): number
	local from = if type(data.schemaVersion) == "number" then data.schemaVersion else 1
	local version = from
	while version < target do
		local step = steps[version]
		assert(step, `No migration from schema {version}`)
		step(data)
		version += 1
	end
	if version > from then
		data.schemaVersion = version
	end
	return from
end

return Migrations
