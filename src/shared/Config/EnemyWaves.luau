--!strict
-- Main-game spawn groups read by Config.Run; exact eligibility comes from Config.Enemies and Util.EnemyStats.
-- Group sizes and intervals are Roblox encounter-density assumptions, not numbers supplied by the enemy wiki.
local Enemies = require(script.Parent.Enemies)

local groups = {
	{ "Shadeling", 4, 2.5 },
	{ "AbyssShadeling", 6, 3 },
	{ "Charger", 3, 5.8 },
	{ "Spitter", 3, 6.3 },
	{ "Thornback", 2, 9 },
	{ "Reaper", 2, 8 },
	{ "IronHusk", 3, 6 },
	{ "HornedRusher", 2, 8 },
	{ "Mender", 1, 12 },
	{ "BroodEgg", 2, 9 },
	{ "Brute", 2, 5.2 },
	{ "AbyssBrute", 2, 6.5 },
	{ "Splitling", 4, 5 },
	{ "Stalker", 3, 7 },
	{ "DreadTendril", 1, 10 },
	{ "Splitter", 3, 6 },
	{ "Skulker", 2, 10 },
	{ "Herald", 1, 12 },
}

local waves = {}
for wave = 1, 20 do
	local list = {}
	for _, row in groups do
		local id = row[1] :: string
		local kind = Enemies.types[id]
		local earliest = kind.firstWave or 1
		for _, first in kind.firstWaveByDanger or {} do
			earliest = math.min(earliest, first)
		end
		if wave >= earliest then
			table.insert(list, table.freeze({ enemy = id, size = row[2], every = row[3] }))
		end
	end
	waves[wave] = table.freeze({ groups = table.freeze(list) })
end

return table.freeze(waves)
