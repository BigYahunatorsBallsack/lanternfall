--!strict
-- The launch check (Paket 24): what is still missing before this experience can go public. Pure, so it has unit
-- tests (tests/Launch24.spec.luau); LaunchService feeds it the running server's ids and prints the result.
-- Each item is "must" (the game breaks or earns nothing without it) or "should" (works, but looks unfinished).

local Shared = script.Parent.Parent
local Config = require(Shared.Config)
local PlaceRules = require(Shared.Util.PlaceRules)

export type Level = "must" | "should"
export type Item = { key: string, level: Level, ok: boolean, text: string }

-- What the check needs to know about the running server.
export type Context = {
	gameId: number, -- game.GameId (0 in an unpublished file)
	placeId: number, -- game.PlaceId
	configProblems: number, -- ConfigCheck.run() count
}

local LaunchRules = {}

-- The config entry for `gameId`: the one with exactly that gameId, else the catch-all one (gameId 0). `exact` tells
-- which of the two it is (a live experience must not run on the catch-all test ids).
local function entryFor<T>(gameId: number, experiences: { T }): (T?, boolean)
	local fallback: T? = nil
	for _, experience in experiences do
		local id = (experience :: any).gameId
		if gameId ~= 0 and id == gameId then
			return experience, true
		elseif id == 0 and fallback == nil then
			fallback = experience
		end
	end
	return fallback, false
end

-- Keys in `ids` whose id is still 0 (sorted, so the text is stable).
local function missing(ids: { [string]: number }): { string }
	local list = {}
	for key, id in ids do
		if not (type(id) == "number" and id > 0) then
			table.insert(list, key)
		end
	end
	table.sort(list)
	return list
end

local function plural(count: number, one: string, many: string): string
	return if count == 1 then `1 {one}` else `{count} {many}`
end

function LaunchRules.check(context: Context): { Item }
	local items: { Item } = {}
	local function add(key: string, level: Level, ok: boolean, text: string)
		table.insert(items, { key = key, level = level, ok = ok, text = text })
	end

	add(
		"Config",
		"must",
		context.configProblems == 0,
		if context.configProblems == 0
			then "Config check clean"
			else `{plural(context.configProblems, "config problem", "config problems")} (see the warnings above)`
	)

	-- Places: the server must know whether it is the hub or the run place, else every server runs alone.
	local role = PlaceRules.resolve(context.placeId, Config.Places.experiences)
	add(
		"Places",
		"must",
		role ~= "Single",
		if role ~= "Single"
			then `This place is the {role} place`
			else `Place {context.placeId} is not in Config.Places: no hub, parties or teleports here`
	)

	-- Store: passes and products of this very experience.
	local store, storeExact = entryFor(context.gameId, Config.Store.experiences)
	if not store then
		add("Store", "must", false, "No store ids for this experience in Config.Store")
	else
		local passes = missing(store.passes)
		local products = missing(store.products)
		local open = #passes + #products
		add(
			"StoreIds",
			"must",
			open == 0,
			if open == 0
				then `All passes and products set ({store.name})`
				else `Missing in Config.Store: {table.concat(passes, ", ")}{if #passes > 0
						and #products > 0
					then ", "
					else ""}{table.concat(products, ", ")}`
		)
		add(
			"StoreExperience",
			"must",
			storeExact or context.gameId == 0,
			if storeExact
				then `Store ids belong to this experience ({store.name})`
				elseif context.gameId == 0 then "Unpublished file: store ids of the catch-all entry"
				else `Experience {context.gameId} uses the catch-all store ids of "{store.name}": give it its own entry`
		)
	end
	-- Badges
	local badges, badgesExact = entryFor(context.gameId, Config.Badges.experiences)
	local badgeIds = if badges then badges.ids else {}
	local openBadges = missing(badgeIds)
	for _, badge in Config.Badges.badges do
		if badgeIds[badge.key] == nil and not table.find(openBadges, badge.key) then
			table.insert(openBadges, badge.key)
		end
	end
	table.sort(openBadges)
	add(
		"Badges",
		"should",
		#openBadges == 0,
		if #openBadges == 0
			then "All badge ids set"
			else `{plural(#openBadges, "badge id", "badge ids")} missing in Config.Badges: {table.concat(
				openBadges,
				", "
			)}`
	)
	if badges and #openBadges == 0 and not badgesExact and context.gameId ~= 0 then
		add(
			"BadgeExperience",
			"should",
			false,
			`Badge ids of "{badges.name}" are a catch-all entry: badges of another experience cannot be awarded here`
		)
	end

	-- Music and own sounds
	local silent = {}
	for state, track in Config.Audio.music do
		if track.sound == "" then
			table.insert(silent, state)
		end
	end
	table.sort(silent)
	add(
		"Music",
		"should",
		#silent == 0,
		if #silent == 0
			then "Every music track has a sound"
			else `No music yet for: {table.concat(silent, ", ")} (Config.Audio music)`
	)
	local sounds = missing(Config.Audio.ownSounds)
	add(
		"Sounds",
		"should",
		#sounds == 0,
		if #sounds == 0
			then "All own sounds uploaded"
			else `{plural(#sounds, "own sound", "own sounds")} not uploaded (placeholders play): {table.concat(
				sounds,
				", "
			)}`
	)

	-- Switches that must stay on in the live game
	add(
		"MovementCheck",
		"must",
		Config.Security.movement.enabled,
		if Config.Security.movement.enabled then "Movement check on" else "Config.Security.movement.enabled is off"
	)
	add(
		"FirstNight",
		"should",
		Config.FirstNight.enabled,
		if Config.FirstNight.enabled then "First Night on for new players" else "Config.FirstNight.enabled is off"
	)
	add(
		"Analytics",
		"should",
		Config.Analytics.enabled,
		if Config.Analytics.enabled then "Analytics on" else "Config.Analytics.enabled is off"
	)
	return items
end

-- Counts of open items: must, should.
function LaunchRules.open(items: { Item }): (number, number)
	local must, should = 0, 0
	for _, item in items do
		if not item.ok then
			if item.level == "must" then
				must += 1
			else
				should += 1
			end
		end
	end
	return must, should
end

-- One line for the Output: "Launch check: 2 must, 3 should open" or "ready".
function LaunchRules.summary(items: { Item }): string
	local must, should = LaunchRules.open(items)
	if must == 0 and should == 0 then
		return "Launch check: ready, nothing open"
	end
	return `Launch check: {must} must, {should} should open (debug button "Launch check" lists them)`
end

-- One line per item, open ones first: "[MUST] ..." / "[should] ..." / "[ok] ...".
function LaunchRules.lines(items: { Item }): { string }
	local lines = {}
	for pass = 1, 2 do
		for _, item in items do
			if (pass == 1) == not item.ok then
				local tag = if item.ok then "ok" elseif item.level == "must" then "MUST" else "should"
				table.insert(lines, `[{tag}] {item.text}`)
			end
		end
	end
	return lines
end

return LaunchRules
