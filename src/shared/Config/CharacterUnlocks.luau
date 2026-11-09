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
)
local rules: { [string]: Challenge } = {
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
