-- Unit tests for the boss state machine (BossService/BossBrain, WP10, Brotato 1.2.0.1 boss.gd and attack
-- behaviors): states switch once a second at an HP share or time, attacks wind up and strike when their cooldown ran
-- out and the player is in range, charges rush, fire their charge shots and recover.

local BossBrain = require(game:GetService("ServerScriptService").Server.Services.BossService.BossBrain)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local DT = 1 / 15

local SHOOT = {
	kind = "Shoot",
	windupSeconds = 0.4,
	cooldownSeconds = 1,
	initialSeconds = 0.5,
	maxRange = 50,
	projectile = "Bullet",
	count = 3,
	projectileSpeed = 30,
}
local CHARGE = {
	kind = "Charge",
	windupSeconds = 0.2,
	cooldownSeconds = 1,
	maxRange = 40,
	chargeSeconds = 0.5,
	chargeSpeed = 50,
	recoverSeconds = 0.05,
}
local SPAWN = { kind = "Spawn", windupSeconds = 0.4, cooldownSeconds = 2, enemy = "BroodEgg", spawnCount = 2 }
local SHOTS = { kind = "Shoot", windupSeconds = 0, cooldownSeconds = 0, projectile = "Bullet", count = 2 }

local PLAN = {
	states = {
		{ movement = "Follow", attack = SHOOT },
		{
			hpStart = 0.6,
			timerStart = 20,
			movement = "Follow",
			attack = CHARGE,
			chargeShots = SHOTS,
			chargeShotEvery = 0.25,
		},
		{ hpStart = 0.3, timerStart = 40, movement = "Roam", attack = SPAWN },
	},
}

local function fixed()
	return 0.5
end

-- Steps until an event of `kind` happens (or `limit` seconds pass); returns it and the seconds it took.
local function runUntil(brain, kind: string, limit: number, hp: number?, distance: number?)
	local waited = 0
	while waited < limit do
		waited += DT
		for _, event in BossBrain.step(brain, DT, hp or 1, distance or 5) do
			if event.kind == kind then
				return event, waited
			end
		end
	end
	return nil, waited
end

describe("BossBrain", function()
	it("picks the last state whose HP share or time is reached", function()
		expect(BossBrain.stateFor(PLAN, 1, 1, 0)).toBe(1)
		expect(BossBrain.stateFor(PLAN, 1, 0.5, 0)).toBe(2)
		expect(BossBrain.stateFor(PLAN, 1, 0.9, 20)).toBe(2)
		expect(BossBrain.stateFor(PLAN, 1, 0.1, 0)).toBe(3)
		expect(BossBrain.stateFor(PLAN, 3, 1, 0)).toBe(3)
	end)

	it("rolls cooldowns within their randomization, never below one frame", function()
		local attack = { kind = "Shoot", windupSeconds = 0, cooldownSeconds = 1 / 60, cooldownRandomSeconds = 10 / 60 }
		expect(BossBrain.rollCooldown(attack :: any, function()
			return 0
		end)).toBeNear(1 / 60)
		expect(BossBrain.rollCooldown(attack :: any, function()
			return 0.999999
		end)).toBeNear(11 / 60, 1e-3)
	end)

	it("winds up after the first cooldown plus the initial wait, keeps walking and strikes", function()
		local brain = BossBrain.new(PLAN :: any, fixed)
		local event, waited = runUntil(brain, "Windup", 5)
		expect(event ~= nil).toBe(true)
		expect(waited).toBeNear(1.5, DT * 1.5)
		expect(BossBrain.isHolding(brain)).toBe(false) -- a Shoot wind-up keeps it walking
		local strike, strikeWait = runUntil(brain, "Strike", 5)
		expect(strike ~= nil and (strike :: any).attack.kind).toBe("Shoot")
		expect(strikeWait).toBeNear(0.4, DT * 1.5)
		local _, next = runUntil(brain, "Windup", 5)
		expect(next).toBeNear(1, DT * 1.5) -- its cooldown runs from the strike
	end)

	it("waits while the player is out of range", function()
		local brain = BossBrain.new(PLAN :: any, fixed)
		local event = runUntil(brain, "Windup", 4, 1, 80)
		expect(event).toBe(nil)
		local none = BossBrain.new(PLAN :: any, fixed)
		expect((runUntil(none, "Windup", 4, 1, math.huge))).toBe(nil)
	end)

	it("switches state only at the once-a-second check", function()
		local brain = BossBrain.new(PLAN :: any, fixed)
		BossBrain.step(brain, 0.5, 0.5, 5)
		expect(brain.state).toBe(1)
		local event = runUntil(brain, "State", 1, 0.5)
		expect(event ~= nil and (event :: any).state).toBe(2)
	end)

	it("charges: holds during the wind-up, rushes with its shots, recovers", function()
		local brain = BossBrain.new(PLAN :: any, fixed)
		runUntil(brain, "State", 2, 0.5)
		expect(brain.state).toBe(2)
		local windup = runUntil(brain, "Windup", 3, 0.5)
		expect(windup ~= nil).toBe(true)
		expect(BossBrain.isHolding(brain)).toBe(true)
		local shots = 0
		local ended = false
		local waited = 0
		while not ended and waited < 3 do
			waited += DT
			for _, event in BossBrain.step(brain, DT, 0.5, 5) do
				if event.kind == "ChargeShot" then
					shots += 1
				elseif event.kind == "ChargeEnd" then
					ended = true
				end
			end
		end
		expect(ended).toBe(true)
		expect(shots).toBe(2) -- at 0 and 0.25 s of a 0.5 s charge
		expect(brain.mode).toBe("Recover")
		expect(BossBrain.isHolding(brain)).toBe(true)
		BossBrain.step(brain, DT, 0.5, 5)
		expect(brain.mode).toBe("Ready")
	end)

	it("summons whatever the distance", function()
		local brain = BossBrain.new(PLAN :: any, fixed)
		runUntil(brain, "State", 2, 0.1, math.huge)
		expect(brain.state).toBe(3)
		local strike = runUntil(brain, "Strike", 4, 0.1, math.huge)
		expect(strike ~= nil and (strike :: any).attack.kind).toBe("Spawn")
	end)

	it("runs every real boss and champion through all its states", function()
		local plans = {}
		for _, kind in Config.Enemies.bosses do
			table.insert(plans, kind.boss)
		end
		for _, kind in Config.Enemies.champions do
			table.insert(plans, kind.boss)
		end
		for _, plan in plans do
			local brain = BossBrain.new(plan, math.random)
			local strikes = 0
			for _ = 1, math.round(90 / DT) do
				for _, event in BossBrain.step(brain, DT, 1, 10) do
					if event.kind == "Strike" then
						strikes += 1
					end
				end
			end
			expect(brain.state).toBe(#plan.states)
			expect(strikes > 0).toBe(true)
		end
	end)
end)
