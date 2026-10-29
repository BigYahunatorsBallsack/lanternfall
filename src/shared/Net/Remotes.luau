--!strict
-- Definition of every remote in the game. Read by Net; adding a remote anywhere else is not allowed.
-- toServer remotes carry intents only and must declare a rate limit and argument validators.

local Config = require(script.Parent.Parent.Config)
local DebugCommands = require(script.Parent.DebugCommands)
local Validate = require(script.Parent.Validate)

export type Definition = {
	direction: "toServer" | "toClient",
	unreliable: boolean?,
	rateLimit: { count: number, perSeconds: number }?,
	args: { Validate.Validator }?,
}

local ID_LENGTH = 32
local MAX_UID = 2 ^ 31 -- weapon uids (WeaponService/Arsenal) stay far below this

local Remotes: { [string]: Definition } = {
	-- Client -> server intents
	RequestSync = {
		direction = "toServer",
		rateLimit = { count = 3, perSeconds = 10 },
		args = {}, -- asks for a full RunState, sent once when the client starts
	},
	SelectClass = {
		direction = "toServer",
		rateLimit = { count = 4, perSeconds = 1 },
		args = { Validate.keyOf(Config.Classes) }, -- classId; availability and ownership are checked by RunDirector
	},
	SetReady = {
		direction = "toServer",
		rateLimit = { count = 4, perSeconds = 1 },
		args = { Validate.boolean() }, -- join the next run (also "Play again" on the results screen)
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
		args = {}, -- new level-up cards for Shards; price and Shards are checked by UpgradeService
	},
	SetShopReady = {
		direction = "toServer",
		rateLimit = { count = 4, perSeconds = 1 },
		args = { Validate.boolean() }, -- done shopping; checked by RunDirector (only while the shop is open)
	},
	BuyShopOffer = {
		direction = "toServer",
		rateLimit = { count = 6, perSeconds = 1 },
		args = { Validate.string(ID_LENGTH) }, -- offer id, must be one the server offered to this player
	},
	RerollShop = {
		direction = "toServer",
		rateLimit = { count = 4, perSeconds = 1 },
		args = {}, -- price and Shards are checked by ShopService
	},
	LockShopOffer = {
		direction = "toServer",
		rateLimit = { count = 8, perSeconds = 1 },
		args = { Validate.string(ID_LENGTH), Validate.boolean() }, -- offer id (one the server offered), locked or not
	},
	SellWeapon = {
		direction = "toServer",
		rateLimit = { count = 4, perSeconds = 1 },
		args = { Validate.integer(1, MAX_UID) }, -- weapon uid; ShopService checks the player carries it
	},
	MergeWeapons = {
		direction = "toServer",
		rateLimit = { count = 4, perSeconds = 1 },
		args = { Validate.integer(1, MAX_UID) }, -- weapon uid; WeaponService checks for a copy of the same tier
	},
	DebugCommand = {
		direction = "toServer",
		rateLimit = { count = 5, perSeconds = 1 },
		args = { Validate.oneOf(DebugCommands) }, -- admin only, checked by AdminService
	},

	-- Server -> client state
	RunState = { direction = "toClient" }, -- full Net/Types.RunState, sent on every change
	PlayerState = { direction = "toClient" }, -- Net/Types.PlayerVitals of one player, to everyone
	Loadout = { direction = "toClient" }, -- Net/Types.Loadout of one player, to everyone on change
	WeaponEffects = { direction = "toClient" }, -- { Net/Types.WeaponEffect } of one simulation step, to participants
	LevelUpOffer = { direction = "toClient" }, -- Net/Types.LevelUpOffer, to the choosing player
	TeamProgress = { direction = "toClient" }, -- Net/Types.TeamProgress, to everyone on change
	XpOrbs = { direction = "toClient" }, -- Net/Types.XpOrbEvents of one simulation step, to participants
	Items = { direction = "toClient" }, -- Net/Types.ItemLoadout of one player, to everyone on change
	Stats = { direction = "toClient" }, -- Net/Types.StatSheet, to its player on change
	EffectProcs = { direction = "toClient" }, -- { Net/Types.EffectProc } of one step (or the shop), to its player
	ActiveBonuses = { direction = "toClient" }, -- { Net/Types.ActiveBonus }, to its player on change
	RunSummary = { direction = "toClient" }, -- Net/Types.RunSummary, to the participants when a run ends
	Notify = { direction = "toClient" }, -- short on-screen messages
	EnemySnapshot = { direction = "toClient", unreliable = true }, -- buffer, see Net/Snapshot
	EnemyShots = { direction = "toClient" }, -- Net/Types.EnemyShotEvents after each snapshot with changes, to participants
	DamageNumbers = { direction = "toClient", unreliable = true }, -- buffer, see Net/HitNumbers; own hits, per step
	Chests = { direction = "toClient" }, -- { Net/Types.ChestInfo } on the floor, to participants on change
	ChestOpened = { direction = "toClient" }, -- Net/Types.ChestOpened, to participants
	ShopState = { direction = "toClient" }, -- Net/Types.ShopState, to its player on change (Shards also during waves)
	DebugStats = { direction = "toClient" }, -- Net/Types.DebugStats, admins only, once per second
}

return table.freeze(Remotes)
