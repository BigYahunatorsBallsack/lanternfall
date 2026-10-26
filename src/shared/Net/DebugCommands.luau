--!strict
-- Ids of the admin debug commands. Used by Net/Remotes (validation), AdminService (handlers) and
-- DebugController (buttons). Only admins may run them; the server checks that, not the client.

return table.freeze({
	"SkipMinute", -- run timer +1 minute
	"SkipToBoss", -- run timer to a few seconds before the boss
	"DownSelf", -- knock yourself down
	"ReviveSelf", -- stand up again
	"WinRun", -- end the run as a victory
})
