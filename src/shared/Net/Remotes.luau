--!strict
-- Definition of every remote in the game. Read by Net; adding a remote anywhere else is not allowed.
-- toServer remotes carry intents only and must declare a rate limit and argument validators.

local Validate = require(script.Parent.Validate)

export type Definition = {
	direction: "toServer" | "toClient",
	unreliable: boolean?,
	rateLimit: { count: number, perSeconds: number }?,
	args: { Validate.Validator }?,
}

local ID_LENGTH = 32

local Remotes: { [string]: Definition } = {
	-- Client -> server intents
	RequestStartRun = {
		direction = "toServer",
		rateLimit = { count = 1, perSeconds = 2 },
		args = { Validate.string(ID_LENGTH), Validate.optional(Validate.string(ID_LENGTH)) }, -- classId, difficulty
	},
	RequestDash = {
		direction = "toServer",
		rateLimit = { count = 2, perSeconds = 1 },
		args = { Validate.vector3(1.01) }, -- unit move direction; cooldown is checked by the service
	},
	ChooseUpgrade = {
		direction = "toServer",
		rateLimit = { count = 4, perSeconds = 1 },
		args = { Validate.string(ID_LENGTH) }, -- card id, must be one the server offered
	},
	RequestReroll = {
		direction = "toServer",
		rateLimit = { count = 2, perSeconds = 1 },
		args = {},
	},

	-- Server -> client state
	RunState = { direction = "toClient" }, -- phase, timer, team level/xp
	PlayerState = { direction = "toClient" }, -- hp, items, dash cooldown
	LevelUpOffer = { direction = "toClient" }, -- offered cards
	Notify = { direction = "toClient" }, -- short on-screen messages
	EnemySnapshot = { direction = "toClient", unreliable = true }, -- buffer, see Net/Snapshot
}

return table.freeze(Remotes)
