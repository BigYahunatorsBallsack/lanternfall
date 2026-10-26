--!strict
-- Admin rights and debug command values (DESIGN.md section 16). Read by AdminService.
-- Admins: everyone in Studio (if allowInStudio), the owner of a user-owned experience, and userIds.

return table.freeze({
	userIds = table.freeze({}) :: { number },
	allowInStudio = true,
	skipMinuteSeconds = 60, -- "SkipMinute"
	skipToBossLeadSeconds = 10, -- "SkipToBoss" leaves this many seconds until the boss
})
