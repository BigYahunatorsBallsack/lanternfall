--!strict
-- Pure rules of the analytics events (Paket 20, Config.Analytics): the onboarding funnel's order, the per-minute
-- event budget, progression path names and the custom fields Roblox expects. Used by AnalyticsService; tested in
-- tests/AnalyticsRules.spec.luau.

local Shared = game:GetService("ReplicatedStorage").Shared
local Analytics = require(Shared.Config.Analytics)
local Types = require(Shared.Net.Types)

local AnalyticsRules = {}

-- Roblox's names for the three custom field slots (Enum.AnalyticsCustomFieldKeys).
AnalyticsRules.FIELD_KEYS = table.freeze({ "CustomField01", "CustomField02", "CustomField03" })

-- Funnel ------------------------------------------------------------------------------

-- One player's way through the onboarding funnel: `reached[step]` once the step happened, `logged` = how many steps
-- are already sent (always the first ones, in order).
export type Funnel = { reached: { [number]: boolean }, logged: number }

function AnalyticsRules.newFunnel(alreadyLogged: number?): Funnel
	return { reached = {}, logged = alreadyLogged or 0 }
end

-- The step number of a step name, nil for an unknown name.
function AnalyticsRules.stepIndex(name: string): number?
	return table.find(Analytics.onboarding.steps, name)
end

-- Marks `name` as reached (in place) and returns the steps to send now, in order: the reached steps that follow the
-- ones already sent without a gap. A step reached early waits for the ones before it.
function AnalyticsRules.reach(funnel: Funnel, name: string): { { step: number, name: string } }
	local index = AnalyticsRules.stepIndex(name)
	local out = {}
	if not index or index <= funnel.logged then
		return out
	end
	funnel.reached[index] = true
	local steps = Analytics.onboarding.steps
	while funnel.reached[funnel.logged + 1] do
		funnel.logged += 1
		table.insert(out, { step = funnel.logged, name = steps[funnel.logged] })
	end
	return out
end

-- Where a player starts in the funnel from their saved finished runs: none = from the start, one = everything up to
-- the first run's end is done (they come back for the lobby and the second run), more = not in the funnel (nil).
function AnalyticsRules.startStep(finishedRuns: number): number?
	if finishedRuns <= 0 then
		return 0
	elseif finishedRuns == 1 then
		return AnalyticsRules.stepIndex("FirstRunEnded")
	end
	return nil
end

-- Budget --------------------------------------------------------------------------------

-- Events this server may still send in the current minute.
export type Budget = { minuteStart: number, used: number }

function AnalyticsRules.newBudget(now: number): Budget
	return { minuteStart = now, used = 0 }
end

function AnalyticsRules.perMinute(playerCount: number): number
	local budget = Analytics.budget
	return budget.perMinute + budget.perMinutePerPlayer * math.max(playerCount, 0)
end

-- Whether one more event of `priority` may go out now; counts it if so (in place). Low priority events keep a
-- reserve of the minute free for the important ones.
function AnalyticsRules.take(budget: Budget, now: number, playerCount: number, priority: string): boolean
	if now - budget.minuteStart >= 60 then
		budget.minuteStart = now
		budget.used = 0
	end
	local limit = AnalyticsRules.perMinute(playerCount)
	local cap = if priority == "low" then math.floor(limit * (1 - Analytics.budget.lowReserveShare)) else limit
	if budget.used >= cap then
		return false
	end
	budget.used += 1
	return true
end

-- Names and fields --------------------------------------------------------------------------

-- The progression path of a run, e.g. "Danger3", "Danger3Endless" or "FirstNight".
function AnalyticsRules.pathName(options: Types.RunOptions): string
	local progression = Analytics.progression
	if options.firstNight then
		return progression.firstNightPath
	end
	local name = `{progression.pathPrefix}{options.danger}`
	if options.endless then
		name ..= progression.endlessSuffix
	end
	return name
end

-- The danger field of custom events: "D3", "D3E" (endless) or "FirstNight".
function AnalyticsRules.dangerField(options: Types.RunOptions): string
	if options.firstNight then
		return Analytics.progression.firstNightPath
	end
	return `D{options.danger}{if options.endless then "E" else ""}`
end

-- Roblox's custom fields from up to three values, in the order Config.Analytics.custom names them. Values become
-- strings cut to Config.Analytics.maxFieldLength; nil values are left out. Nil when there is no value.
function AnalyticsRules.fields(values: { any }): { [string]: string }?
	local out: { [string]: string } = {}
	local any = false
	for i = 1, #AnalyticsRules.FIELD_KEYS do
		local value = values[i]
		if value ~= nil then
			out[AnalyticsRules.FIELD_KEYS[i]] = string.sub(tostring(value), 1, Analytics.maxFieldLength)
			any = true
		end
	end
	return if any then out else nil
end

-- The cause field of "PlayerDown": the last hit if it is recent enough, else "Other" (boss attacks and the like).
function AnalyticsRules.downCause(lastHit: { kind: string, time: number }?, now: number): string
	if lastHit and now - lastHit.time <= Analytics.down.hitWindowSeconds then
		return lastHit.kind
	end
	return "Other"
end

return AnalyticsRules
