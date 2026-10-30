-- Unit tests for the boss state machine (BossService/BossBrain, WP10): phases switch at an HP share or after some
-- seconds, attacks go wind-up -> strike -> recover in list order, cooldowns and ranges skip attacks.

local BossBrain = require(game:GetService("ServerScriptService").Server.Services.BossService.BossBrain)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local DT = 1 / 15

local PLAN = {
	phases = {
		{ attacks = { "Dash", "Slam" }, pauseSeconds = 1 },
		{ fromHp = 0.5, afterSeconds = 45, attacks = { "Ring" }, pauseSeconds = 0.5 },
		{ fromHp = 0.2, attacks = { "Rain" }, pauseSeconds = 0 },
	},
	attacks = {
		Dash = {
			kind = "Dash",
			windupSeconds = 0.8,
			recoverSeconds = 0.5,
			range = 30,
			damage = 10,
			speed = 40,
			distance = 20,
		},
		Slam = {
			kind = "Slam",
			windupSeconds = 1,
			recoverSeconds = 0.5,
			cooldownSeconds = 6,
			range = 10,
			damage = 10,
			radius = 8,
		},
		Ring = {
			kind = "Ring",
			windupSeconds = 0.6,
			recoverSeconds = 0.4,
			damage = 5,
			count = 8,
			bursts = 3,
			burstGapSeconds = 0.3,
			projectileSpeed = 10,
			projectileRange = 30,
			projectileRadius = 0.5,
		},
		Rain = {
			kind = "Rain",
			windupSeconds = 1,
			recoverSeconds = 0,
			cooldownSeconds = 2,
			moving = true,
			damage = 5,
			count = 3,
			spread = 8,
			radius = 2,
		},
	},
}

-- Steps the brain for `seconds` and returns every event as "kind:attackId" / "Phase:n".
local function run(brain, seconds, hp, distance)
	local log = {}
	for _ = 1, math.round(seconds / DT) do
		for _, event in BossBrain.step(brain, DT, hp or 1, distance or 5) do
			table.insert(log, if event.kind == "Phase" then `Phase:{event.phase}` else `{event.kind}:{event.attackId}`)
		end
	end
	return log
end

describe("BossBrain", function()
	it("picks the phase by HP or time, whichever comes first, never back", function()
		expect(BossBrain.phaseFor(PLAN, 1, 1, 0)).toBe(1)
		expect(BossBrain.phaseFor(PLAN, 1, 0.5, 0)).toBe(2)
		expect(BossBrain.phaseFor(PLAN, 1, 0.9, 45)).toBe(2)
		expect(BossBrain.phaseFor(PLAN, 1, 0.1, 0)).toBe(3)
		expect(BossBrain.phaseFor(PLAN, 3, 1, 0)).toBe(3)
	end)

	it("walks, winds up, strikes, rushes and recovers, then takes the next attack", function()
		local brain = BossBrain.new(PLAN)
		expect(table.concat(run(brain, 0.9), ",")).toBe("") -- still pausing
		expect(table.concat(run(brain, 0.2), ",")).toBe("Windup:Dash")
		expect(brain.state).toBe("Windup")
		expect(BossBrain.isHolding(brain)).toBe(true)
		expect(table.concat(run(brain, 0.8), ",")).toBe("Strike:Dash")
		expect(brain.state).toBe("Act") -- rushing for distance / speed = 0.5 s
		run(brain, 0.5)
		expect(brain.state).toBe("Recover")
		expect(table.concat(run(brain, 0.6), ",")).toBe("Done:Dash")
		expect(table.concat(run(brain, 1.1), ",")).toBe("Windup:Slam")
	end)

	it("skips attacks that are on cooldown or out of range", function()
		local brain = BossBrain.new(PLAN)
		local log = run(brain, 14, 1, 5)
		local slams = 0
		for _, entry in log do
			if entry == "Windup:Slam" then
				slams += 1
			end
		end
		expect(slams).toBe(2) -- every 6 s at most; Dashes fill the gaps
		local far = BossBrain.new(PLAN)
		local farLog = table.concat(run(far, 6, 1, 20), ",")
		expect(string.find(farLog, "Slam", 1, true)).toBe(nil) -- 20 studs: only the Dash reaches
		local none = BossBrain.new(PLAN)
		expect(#run(none, 5, 1, math.huge)).toBe(0) -- nobody alive: no attack
	end)

	it("changes phase between attacks and fires every burst of a ring", function()
		local brain = BossBrain.new(PLAN)
		run(brain, 1.1) -- Dash winds up
		local log = run(brain, 3, 0.4)
		expect(log[1]).toBe("Strike:Dash") -- the attack in progress finishes first
		expect(table.find(log, "Phase:2") ~= nil).toBe(true)
		local ring = run(brain, 3, 0.4)
		local strikes = 0
		for _, entry in ring do
			if entry == "Strike:Ring" then
				strikes += 1
			end
		end
		expect(strikes >= 3).toBe(true)
		expect(brain.phase).toBe(2)
	end)

	it("keeps walking during moving attacks and switches by time", function()
		local brain = BossBrain.new(PLAN)
		run(brain, 48, 0.9)
		expect(brain.phase).toBe(2)
		run(brain, 2, 0.1)
		expect(brain.phase).toBe(3)
		local guard = 100
		while brain.state ~= "Windup" and guard > 0 do
			guard -= 1
			run(brain, DT, 0.1)
		end
		expect(brain.attackId).toBe("Rain")
		expect(BossBrain.isHolding(brain)).toBe(false)
	end)

	it("runs both real bosses through all their phases", function()
		for id, boss in Config.Enemies.bosses do
			local brain = BossBrain.new(boss.boss)
			local strikes = 0
			for second = 1, 90 do
				local hp = 1 - second / 90
				for _, event in run(brain, 1, hp, 3) do
					if string.sub(event, 1, 7) == "Strike:" then
						strikes += 1
					end
				end
			end
			expect(brain.phase).toBe(#boss.boss.phases)
			expect(strikes > 20).toBe(true)
			expect(id ~= "").toBe(true)
		end
	end)
end)
