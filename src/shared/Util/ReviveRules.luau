--!strict
-- Pure rules of one downed player during a wave (DESIGN.md section 8, WP11): the down timer runs out (then they are
-- out), a teammate standing next to them fills the revive, and with nobody near a started revive drains back.
-- No Roblox objects, so it is unit tested. Used by ReviveService (values from Config.Run.coop) and by
-- ReviveController, which animates the bar and timer between updates with `project`.

export type Settings = {
	downTimerSeconds: number,
	reviveSeconds: number,
	reviveDecaySeconds: number,
	downTimerPausesWhileReviving: boolean,
}

export type Entry = {
	timeLeft: number, -- seconds until out
	progress: number, -- 0-1
}

export type Outcome = "Revived" | "Out"

local ReviveRules = {}

function ReviveRules.new(settings: Settings): Entry
	return { timeLeft = settings.downTimerSeconds, progress = 0 }
end

-- Advances one downed player by `dt` seconds; `helped` = a living teammate is close enough. Returns "Revived" once
-- the revive is full, "Out" once the timer runs out (a full revive in the same step wins), else nil.
function ReviveRules.step(entry: Entry, dt: number, helped: boolean, settings: Settings): Outcome?
	if helped then
		entry.progress = math.min(1, entry.progress + dt / math.max(settings.reviveSeconds, 1e-3))
	else
		entry.progress = math.max(0, entry.progress - dt / math.max(settings.reviveDecaySeconds, 1e-3))
	end
	if entry.progress >= 1 then
		return "Revived"
	end
	if not (helped and settings.downTimerPausesWhileReviving) then
		entry.timeLeft = math.max(0, entry.timeLeft - dt)
	end
	if entry.timeLeft <= 0 then
		return "Out"
	end
	return nil
end

-- The entry `elapsed` seconds after it was sent, without outcomes (client display).
function ReviveRules.project(entry: Entry, elapsed: number, helped: boolean, settings: Settings): Entry
	local copy = { timeLeft = entry.timeLeft, progress = entry.progress }
	ReviveRules.step(copy, math.max(0, elapsed), helped, settings)
	return copy
end

return ReviveRules
