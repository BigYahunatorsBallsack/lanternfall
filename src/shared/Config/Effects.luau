--!strict
-- Item effects beyond plain stats (DESIGN.md sections 4 and 6, Brotato direction since B4): what an effect record
-- may say and the numbers of the effect rules. Effects are data, {trigger, condition, action, values}, like in
-- Brotato's effect engine; Config.Items lists them per item. Read by the server's EffectService (EffectRules),
-- StatService and ConfigCheck, and by the client for texts (Util/EffectText) and the bonus line in the HUD.
--
-- Trigger + action:
--   Always    + Stats        stats while the condition holds (`state` "Still" or "Moving", else always), times count
--   Always    + PerX         stats times floor(source / per) (at most `max` steps), times count; `source` is
--                            "shards" (held), "distinctWeapons" (different weapons carried) or a stat id (its
--                            permanent value: items, cards and growth, before any effect bonus)
--   any event + Grow         stats added for the rest of the run (Brotato's "at the end of a wave" growth)
--   any event + WaveStats    stats until the wave ends (at most `maxStacks` applications)
--   any event + TimedStats   stats for `seconds`, a new trigger refreshes them (at most `maxStacks` stacks)
--   any event + NextWaveStats stats during the next wave only (Brotato's "during the next wave")
--   any event + Heal         `amount` HP
--   any event + Shards       `amount` Shards
--   any event + ShardShare   `amount` percent of the Shards held, at most `max`
--   any event + HpFraction   HP set to `amount` of max HP (Brotato's "start waves with -50 % HP")
--   any event + RandomStats  `amount` points split at random between the primary stats (randomPoint below)
--   any event + Shields      `amount` hits nullified until the wave ends
--   any event + UpgradeWeapon a random weapon below the max tier one tier up; without one, `stats` instead
--   Hit/Crit/Kill + Burn     sets the enemy on fire (B5): `ticks` ticks of `amount` + `scaling` (stat id -> share)
--                            per tick, times Damage % (Brotato's burning items; burns do not stack)
--   Hit/Crit/Kill + Explode  an explosion at the enemy (B5): `amount` + `scaling` damage, radius `size` times
--                            Config.Combat.explosion.baseRadius; copies that fire together add their damage
--   any event + Strike       (B8) hits an enemy: `amount` + `scaling` times Damage %, plus `hpShare` of its current HP
--                            (`eliteHpShare` for elites); `target` "random" = a random living enemy (one per copy that
--                            fires), else the enemy of a Hit, Crit or Kill (damage times copies). No crit, life steal,
--                            knockback; its kills count as Kill events, its hits not as Hit
--   any event + Drain        (B8) lose `amount` HP, never below 1, ignoring armor, dodge and hit protection
-- Events (triggers): Acquire (this copy is taken), WaveStart, WaveEnd (before Harvesting pays), ShopEnter (offers
-- rolled), Reroll, Buy, Sell, LevelUp, Hit, Crit, Kill (weapon hits of the owner), Dodge, Hurt (HP lost), Pickup
-- (per orb picked up), Chest, Timer (every `interval` seconds of a wave).
-- Since B6 also Consumable (a fruit or crate picked up; a crate fires Chest as well).
-- Conditions: `chance` (0..1, rolled per copy), `crit` / `elite` (Hit, Crit, Kill), `fromWave` / `untilWave`,
-- `maxPerWave` (firings per wave); since B8 `fullHp` (Consumable: at max HP before its healing).
-- PerX since B8: `per` may be negative ("per -1 % Speed"), `min` keeps the steps from dropping below it; more sources:
-- "enemies" (living enemies right now) and "distinctItemsTier1".."distinctItemsTier4" (different items of that tier).
-- Copies: an effect without `chance` works count times as strong; with `chance` every copy rolls on its own.

export type Effect = {
	trigger: string,
	action: string,
	stats: { [string]: number }?,
	amount: number?,
	chance: number?,
	state: string?,
	source: string?,
	per: number?,
	max: number?,
	interval: number?,
	seconds: number?,
	maxStacks: number?,
	crit: boolean?,
	elite: boolean?,
	fromWave: number?,
	untilWave: number?,
	maxPerWave: number?,
	scaling: { [string]: number }?, -- Burn, Explode: stat id -> share added to `amount` (B5)
	ticks: number?, -- Burn
	size: number?, -- Explode: share of the base explosion radius
	min: number?, -- PerX: fewest steps (B8)
	fullHp: boolean?, -- Consumable: only at max HP (B8)
	target: string?, -- Strike: "random" or nil (the event's enemy) (B8)
	hpShare: number?, -- Strike: share of the enemy's current HP added (B8)
	eliteHpShare: number?, -- Strike: hpShare against elites (B8)
}

local function set(list: { string }): { [string]: boolean }
	local result = {}
	for _, name in list do
		result[name] = true
	end
	return table.freeze(result)
end

return table.freeze({
	triggers = set({
		"Always",
		"Acquire",
		"WaveStart",
		"WaveEnd",
		"ShopEnter",
		"Reroll",
		"Buy",
		"Sell",
		"LevelUp",
		"Hit",
		"Crit",
		"Kill",
		"Dodge",
		"Hurt",
		"Pickup",
		"Chest",
		"Timer",
		"Consumable",
	}),
	passiveActions = set({ "Stats", "PerX" }), -- only with trigger "Always"
	eventActions = set({
		"Grow",
		"WaveStats",
		"TimedStats",
		"NextWaveStats",
		"Heal",
		"Shards",
		"ShardShare",
		"HpFraction",
		"RandomStats",
		"Shields",
		"UpgradeWeapon",
		"Burn",
		"Explode",
		"Strike",
		"Drain",
	}),
	enemyTriggers = set({ "Hit", "Crit", "Kill" }), -- events with an enemy: the only ones for Burn and Explode (B5)
	states = set({ "Still", "Moving" }),
	perXSources = set({
		"shards",
		"distinctWeapons",
		"enemies",
		"distinctItemsTier1",
		"distinctItemsTier2",
		"distinctItemsTier3",
		"distinctItemsTier4",
	}), -- and every stat id
	strikeTargets = set({ "random" }), -- Strike without a target hits the event's enemy (B8)

	-- Standing still (Brotato's "while standing still"): moving slower than maxSpeed studs/s for at least
	-- settleSeconds; moving again counts after the same time, so a stutter step does not flicker the bonus.
	-- Only during a wave and while alive (assumption: Brotato gives no numbers).
	standStill = table.freeze({ maxSpeed = 1, settleSeconds = 0.2 }),
	-- RandomStats: one point of each primary stat in Config.Stats units (Brotato's points, Max HP times hpScale).
	randomPoint = table.freeze({ maxHp = 10 }), -- every other stat: 1
	-- Feedback texts over the own character when an effect pays out (EffectProcs remote), per player and step.
	procs = table.freeze({ maxPerStep = 6 }),
})
