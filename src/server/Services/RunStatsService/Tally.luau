--!strict
-- Counts one run's statistics (kills, team level over time, damage taken, downs) and turns them into the
-- results screen summary and the playtest log lines. Pure logic, used by RunStatsService and the balance sim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Types = require(Shared.Net.Types)

export type PlayerTally = {
	userId: number,
	name: string,
	classId: string,
	damageTaken: number,
	downs: number,
	firstDownAt: number?, -- run seconds
}

-- What the run's players carried at the end (from WeaponService and StatService).
export type Loadout = {
	weapons: { { id: string, tier: number, evolution: string?, damage: number, kills: number } },
	items: { Types.ItemInfo },
}

local Tally = {}
Tally.__index = Tally

export type Tally = typeof(setmetatable(
	{} :: {
		kills: number,
		killsByType: { [string]: number },
		levelTimes: { number }, -- levelTimes[n] = run seconds when the team reached level n (level 1 at 0)
		players: { PlayerTally },
	},
	Tally
))

function Tally.new(): Tally
	return setmetatable({ kills = 0, killsByType = {}, levelTimes = { 0 }, players = {} }, Tally)
end

function Tally.addPlayer(self: Tally, userId: number, name: string, classId: string)
	table.insert(self.players, { userId = userId, name = name, classId = classId, damageTaken = 0, downs = 0 })
end

function Tally.getPlayer(self: Tally, userId: number): PlayerTally?
	for _, entry in self.players do
		if entry.userId == userId then
			return entry
		end
	end
	return nil
end

function Tally.recordKill(self: Tally, enemyId: string)
	self.kills += 1
	self.killsByType[enemyId] = (self.killsByType[enemyId] or 0) + 1
end

-- The team reached `level` after `seconds` of the run. Levels arrive in order; gaps (admin skips) are filled.
function Tally.recordLevel(self: Tally, level: number, seconds: number)
	for n = #self.levelTimes + 1, level do
		self.levelTimes[n] = seconds
	end
end

function Tally.recordDamageTaken(self: Tally, userId: number, amount: number)
	local entry = self:getPlayer(userId)
	if entry then
		entry.damageTaken += amount
	end
end

function Tally.recordDown(self: Tally, userId: number, seconds: number)
	local entry = self:getPlayer(userId)
	if entry then
		entry.downs += 1
		entry.firstDownAt = entry.firstDownAt or seconds
	end
end

-- Team level after `seconds` of the run.
function Tally.levelAt(self: Tally, seconds: number): number
	local level = 1
	for n, at in self.levelTimes do
		if at <= seconds then
			level = n
		end
	end
	return level
end

function Tally.getLevel(self: Tally): number
	return #self.levelTimes
end

local function sumWeapons(loadout: Loadout?): (number, number)
	local damage, kills = 0, 0
	for _, weapon in if loadout then loadout.weapons else {} do
		damage += weapon.damage
		kills += weapon.kills
	end
	return damage, kills
end

-- Summary for the results screen; `loadouts` by userId.
function Tally.summary(self: Tally, loadouts: { [number]: Loadout }): Types.RunSummary
	local players = {}
	for _, entry in self.players do
		local loadout = loadouts[entry.userId]
		local damage, kills = sumWeapons(loadout)
		local weapons: { Types.RunSummaryWeapon } = {}
		for _, weapon in if loadout then loadout.weapons else {} do
			table.insert(weapons, {
				id = weapon.id,
				tier = weapon.tier,
				evolution = weapon.evolution,
				damage = math.round(weapon.damage),
				kills = weapon.kills,
			})
		end
		table.sort(weapons, function(a, b)
			return a.damage > b.damage
		end)
		table.insert(players, {
			userId = entry.userId,
			kills = kills,
			damageDealt = math.round(damage),
			damageTaken = math.round(entry.damageTaken),
			downs = entry.downs,
			weapons = weapons,
		})
	end
	return { teamLevel = self:getLevel(), kills = self.kills, players = players }
end

local function displayName(records: { [string]: any }, id: string): string
	local record = records[id]
	return if record then record.displayName else id
end

-- Readable lines for the server Output, so the owner can copy them after a playtest.
function Tally.logLines(self: Tally, results: Types.Results, loadouts: { [number]: Loadout }): { string }
	local lines = {}
	local byType = {}
	for enemyId, count in self.killsByType do
		table.insert(byType, `{displayName(Config.Enemies.types, enemyId)} {count}`)
	end
	table.sort(byType)
	table.insert(
		lines,
		`{results.outcome} after {Format.time(results.survivedSeconds)} · {results.difficulty} · {#self.players} player(s)`
			.. ` · team level {self:getLevel()} · {self.kills} kills`
			.. (if #byType > 0 then ` ({table.concat(byType, ", ")})` else "")
	)

	local timeline = {}
	for minute = 1, math.floor(results.survivedSeconds / 60) do
		table.insert(timeline, `{minute}:00 L{self:levelAt(minute * 60)}`)
	end
	if #timeline > 0 then
		table.insert(lines, `Level per minute: {table.concat(timeline, " · ")}`)
	end

	for _, entry in self.players do
		local loadout = loadouts[entry.userId]
		local damage, kills = sumWeapons(loadout)
		local downText = if entry.firstDownAt then `, first down at {Format.time(entry.firstDownAt)}` else ""
		table.insert(
			lines,
			`{entry.name} ({displayName(Config.Classes, entry.classId)}): {kills} kills, {math.round(damage)} damage,`
				.. ` took {math.round(entry.damageTaken)}, down {entry.downs}x{downText}`
		)
		if loadout then
			local weapons = {}
			for _, weapon in loadout.weapons do
				table.insert(
					weapons,
					`{displayName(Config.Weapons, weapon.id)} {Format.tier(weapon.tier)} {math.round(weapon.damage)} dmg/{weapon.kills} kills`
				)
			end
			local items = {}
			for _, item in loadout.items do
				table.insert(items, `{displayName(Config.Items.byId, item.id)} x{item.count}`)
			end
			table.insert(lines, `  Weapons: {if #weapons > 0 then table.concat(weapons, " · ") else "none"}`)
			table.insert(lines, `  Items: {if #items > 0 then table.concat(items, " · ") else "none"}`)
		end
	end
	return lines
end

return Tally
