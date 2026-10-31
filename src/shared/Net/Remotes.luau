--!strict
-- Definition of every remote in the game. Read by Net; adding a remote anywhere else is not allowed.
-- toServer remotes carry intents only and must declare a rate limit and argument validators.

local Config = require(script.Parent.Parent.Config)
local DebugCommands = require(script.Parent.DebugCommands)
local EmberShopRules = require(script.Parent.Parent.Util.EmberShopRules)
local LeaderboardRules = require(script.Parent.Parent.Util.LeaderboardRules)
local PurchaseRules = require(script.Parent.Parent.Util.PurchaseRules)
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
	ChooseCrate = {
		direction = "toServer",
		rateLimit = { count = 4, perSeconds = 1 },
		args = { Validate.boolean() }, -- B6: take (true) or sell (false) the open crate's item; UpgradeService checks
	},

	-- Server -> client state
	RunState = { direction = "toClient" }, -- full Net/Types.RunState, sent on every change
	PlayerState = { direction = "toClient" }, -- Net/Types.PlayerVitals of one player, to everyone
	Loadout = { direction = "toClient" }, -- Net/Types.Loadout of one player, to everyone on change
	WeaponEffects = { direction = "toClient" }, -- buffer (Net/WeaponFx, since Paket 22) of one simulation step, to participants
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
	EnemyShots = { direction = "toClient" }, -- buffer (Net/ShotFeed, since Paket 22) after each snapshot with changes
	DamageNumbers = { direction = "toClient", unreliable = true }, -- buffer, see Net/HitNumbers; own hits, per step
	Chests = { direction = "toClient" }, -- { Net/Types.ChestInfo } on the floor, to participants on change
	ChestOpened = { direction = "toClient" }, -- Net/Types.ChestOpened, to participants
	ShopState = { direction = "toClient" }, -- Net/Types.ShopState, to its player on change (Shards also during waves)
	DebugStats = { direction = "toClient" }, -- Net/Types.DebugStats, admins only, once per second
	OrbBag = { direction = "toClient" }, -- B6: XP of the orbs in the team's bag (number), to everyone on change
	Pickups = { direction = "toClient" }, -- B6: Net/Types.PickupEvents of one simulation step, to participants
	CrateOffer = { direction = "toClient" }, -- B6: Net/Types.CrateOffer, to the choosing player
	SpawnMarkers = { direction = "toClient" }, -- B9: Net/Types.SpawnMarkers of one spawn group, to participants
	BossState = { direction = "toClient" }, -- WP10: Net/Types.BossState, to participants while a boss is alive
	BossTelegraphs = { direction = "toClient" }, -- WP10: { Net/Types.BossTelegraph } of one step, to participants
}

-- B10: class + starting weapon are intents, checked against the current lobby choice.
Remotes.SelectStartWeapon = {
	direction = "toServer",
	rateLimit = { count = 4, perSeconds = 1 },
	args = { Validate.keyOf(Config.Classes), Validate.keyOf(Config.Weapons) },
}
Remotes.StartWeaponChoice = { direction = "toClient" }
Remotes.Structures = { direction = "toClient" } -- B12 authoritative full snapshot; also on RequestSync
Remotes.StructureBeams = { direction = "toClient" } -- B12 cosmetic attacks
-- B11: the lobby's run options for the next run: danger level, endless mode, enemy HP/damage/speed sliders in percent
-- (snapped to Config.Difficulty.sliders by RunDirector)
Remotes.SetRunOptions = {
	direction = "toServer",
	rateLimit = { count = 6, perSeconds = 1 },
	args = {
		Validate.integer(0, #Config.Difficulty.levels - 1),
		Validate.boolean(),
		Validate.number(Config.Difficulty.sliders.enemyHp.min, Config.Difficulty.sliders.enemyHp.max),
		Validate.number(Config.Difficulty.sliders.enemyDamage.min, Config.Difficulty.sliders.enemyDamage.max),
		Validate.number(Config.Difficulty.sliders.enemySpeed.min, Config.Difficulty.sliders.enemySpeed.max),
		Validate.optional(
			Validate.number(Config.Difficulty.sliders.enemyCount.min, Config.Difficulty.sliders.enemyCount.max)
		),
	},
}
-- WP11: Net/Types.ReviveState, to everyone when someone goes down or out, stands up, or a revive starts or stops
Remotes.ReviveState = { direction = "toClient" }
-- Paket 12: Net/Types.ProfileInfo, to its player when the saved data loads or changes
Remotes.ProfileInfo = { direction = "toClient" }
-- Paket 13: Net/Types.RunRewards, to each participant when a finished run is saved
Remotes.RunRewards = { direction = "toClient" }
-- Paket 14: the settings menu (shake, damage numbers, music and effects volume), saved in the profile
Remotes.SaveSettings = {
	direction = "toServer",
	rateLimit = { count = 3, perSeconds = 5 }, -- the client sends once per burst of changes (Config.Settings)
	args = {
		Validate.boolean(),
		Validate.boolean(),
		Validate.number(0, 1),
		Validate.number(0, 1),
		Validate.optional(Validate.oneOf(Config.Graphics.choices)), -- Paket 22: graphics quality
	},
}
-- Paket 14: { Net/Types.WaveChallenge }, the planned elite and horde waves of the run so far, to the participants
Remotes.WavePlan = { direction = "toClient" }
-- B11 part 2: "Retry wave" on the results after a defeat; RunDirector checks the phase, the outcome and the retries left
Remotes.RetryWave = {
	direction = "toServer",
	rateLimit = { count = 2, perSeconds = 1 },
	args = {},
}
-- Paket 15: hub parties and portals (PartyService checks the role, the party and who may do what)
Remotes.PartyState = { direction = "toClient" } -- Net/Types.PartyState, to its player on change
Remotes.InviteToParty = {
	direction = "toServer",
	rateLimit = { count = 3, perSeconds = 2 },
	args = { Validate.integer(1, 2 ^ 53) }, -- userId of a player in this hub
}
Remotes.AnswerInvite = {
	direction = "toServer",
	rateLimit = { count = 4, perSeconds = 2 },
	args = { Validate.integer(1, 2 ^ 53), Validate.boolean() }, -- inviter's userId, accept
}
Remotes.LeaveParty = { direction = "toServer", rateLimit = { count = 2, perSeconds = 2 }, args = {} }
Remotes.KickFromParty = {
	direction = "toServer",
	rateLimit = { count = 3, perSeconds = 2 },
	args = { Validate.integer(1, 2 ^ 53) }, -- userId of a party member; leader only
}
-- Play solo, start the party run (leader), join quick join, or cancel the countdown/queue
Remotes.PlayFromHub = {
	direction = "toServer",
	rateLimit = { count = 3, perSeconds = 2 },
	args = { Validate.oneOf({ "Solo", "Party", "QuickJoin", "Cancel" }) },
}
-- Run place: back to the hub (RunPlaceService; not during the player's own run)
Remotes.ReturnToHub = { direction = "toServer", rateLimit = { count = 1, perSeconds = 2 }, args = {} }
-- Paket 16: Robux purchases. The client only asks; MonetizationService checks the key is set up and allowed right now
-- (Revive: down in a running co-op wave, once per run; passes: not owned yet), then shows Roblox's purchase prompt.
-- Everything a purchase gives is granted by the server in ProcessReceipt.
Remotes.RequestPurchase = {
	direction = "toServer",
	rateLimit = { count = 3, perSeconds = 3 },
	args = { Validate.oneOf(PurchaseRules.keys()) }, -- pass or product key from Config.Store
}
-- Paket 16: a free reroll from the VIP pass or a bought reroll token; only while the player's shop is open
Remotes.UseBonusReroll = { direction = "toServer", rateLimit = { count = 4, perSeconds = 1 }, args = {} }
Remotes.StoreState = { direction = "toClient" } -- Net/Types.StoreState, to its player on change
-- Paket 17 Ember shop: buy a locked character ("Character", class id) or a cosmetic ("Cosmetic", Config.Cosmetics id)
-- with Embers; EmberShopService checks the price, the saved Embers and that it is not owned yet
Remotes.BuyWithEmbers = {
	direction = "toServer",
	rateLimit = { count = 3, perSeconds = 2 },
	args = { Validate.oneOf(EmberShopRules.KINDS), Validate.string(ID_LENGTH) },
}
-- Paket 17: put an owned cosmetic (or Config.Cosmetics.none) into a slot; shown on the character for everyone
local equipIds = table.clone(EmberShopRules.ids())
table.insert(equipIds, Config.Cosmetics.none)
Remotes.EquipCosmetic = {
	direction = "toServer",
	rateLimit = { count = 4, perSeconds = 2 },
	args = { Validate.oneOf(Config.Cosmetics.slots), Validate.oneOf(equipIds) },
}
-- Paket 18: daily quests and the login streak (QuestService); swapping checks the swaps left and that it is not done
Remotes.QuestState = { direction = "toClient" } -- Net/Types.QuestState, to its player on change
Remotes.SwapQuest = {
	direction = "toServer",
	rateLimit = { count = 2, perSeconds = 2 },
	args = { Validate.integer(1, Config.Quests.daily) }, -- index of the quest in the list
}
-- Paket 18: weekly leaderboards (LeaderboardService answers with Leaderboard; reads are cached per server)
Remotes.RequestLeaderboard = {
	direction = "toServer",
	rateLimit = { count = 6, perSeconds = 3 },
	args = {
		Validate.oneOf(LeaderboardRules.boardKeys()),
		Validate.integer(0, #Config.Difficulty.levels - 1), -- danger level
		Validate.oneOf(Config.Leaderboards.scopes),
	},
}
Remotes.Leaderboard = { direction = "toClient" } -- Net/Types.LeaderboardPage, to the player who asked
-- Paket 19: "Skip" on the First Night hints (FirstNightService checks that the player is in a First Night run)
Remotes.SkipFirstNight = {
	direction = "toServer",
	rateLimit = { count = 1, perSeconds = 2 },
	args = {},
}
Remotes.FirstNightLobby = { direction = "toClient" } -- Paket 19: show the lobby hint after the First Night (no data)
return table.freeze(Remotes)
