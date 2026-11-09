--!strict
-- Verified native character challenges; PlayerDataService persists their flags and CharacterChoice shows requirements.
-- Further locked characters stay unavailable until their challenge and complete code package are connected.
export type Challenge = {
	challengeId: string,
	source: string,
	sourceMd5: string,
	requirement: string,
} & (
	{ kind: "Stat", stat: string, threshold: number }
	| { kind: "WinDanger", danger: number }
	| { kind: "WaveHealing", threshold: number }
	| { kind: "MaterialsCollected", threshold: number }
	| { kind: "ExplosionKills", threshold: number }
	| { kind: "RunRecycledWeapons", threshold: number }
	| { kind: "EnemiesKilled", threshold: number }
)
local rules: { [string]: Challenge } = {
	Wildling = {
		kind = "EnemiesKilled",
		challengeId = "chal_survivor_4",
		threshold = 10000,
		source = "res://challenges/survivor_4_data.tres",
		sourceMd5 = "c74b21a1bf0a5e008aeb7a7f9f21da6c",
		requirement = "Kill 10000 enemies",
	},
	ArmsDealer = {
		kind = "RunRecycledWeapons",
		challengeId = "chal_recycling",
		threshold = 12,
		source = "res://challenges/recycling_data.tres",
		sourceMd5 = "3c3885a6022db105e0991b10a0bb926a",
		requirement = "Recycle 12 weapons during a run",
	},
	Artificer = {
		kind = "ExplosionKills",
		challengeId = "chal_fireworks",
		threshold = 15,
		source = "res://challenges/starship_beam_data.tres",
		sourceMd5 = "e2b05687c302bd9517bf957939a85336",
		requirement = "Kill 15 enemies with a single explosion",
	},
	Pacifist = {
		kind = "MaterialsCollected",
		challengeId = "chal_gatherer_4",
		source = "res://challenges/gatherer_4_data.tres",
		sourceMd5 = "bbfb8c62a6cc4d4fa92b05fc9e0f9cd1",
		threshold = 10000,
		requirement = "Collect 10000 materials",
	},
	Doctor = {
		kind = "WaveHealing",
		challengeId = "chal_medicine",
		source = "res://challenges/medicine_data.tres",
		sourceMd5 = "a98aac978b4ff7e7605e179527034075",
		threshold = 200,
		requirement = "Heal 200 HP in one wave",
	},
	Ghost = {
		kind = "Stat",
		challengeId = "chal_hallucination",
		source = "res://challenges/hallucination_data.tres",
		sourceMd5 = "ceb46e5084b26af1de591ec752828310",
		stat = "dodge",
		threshold = 60,
		requirement = "Reach +60 % Dodge",
	},
	Bull = {
		kind = "WinDanger",
		challengeId = "chal_difficulty_1",
		source = "res://challenges/chal_difficulty_1_data.tres",
		sourceMd5 = "6a20708c5b6432e135b3266c6125a507",
		danger = 1,
		requirement = "Win a run in Danger 1",
	},
}
return table.freeze(rules)
