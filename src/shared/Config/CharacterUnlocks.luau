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
	| { kind: "WaveLivingTrees", threshold: number }
	| { kind: "Inventory", count: string, threshold: number, stat: string?, statThreshold: number? }
	| { kind: "RunConsumables", threshold: number }
)
local rules: { [string]: Challenge } = {
	TwinLedger = {
		kind = "MaterialsCollected",
		threshold = 2000,
		challengeId = "chal_gatherer_2",
		source = "res://challenges/gatherer_2_data.tres",
		sourceMd5 = "f519b2d5eda82fc4c6ca18ef38090cad",
		requirement = "Collect 2000 materials",
	},
	Farmer = {
		kind = "Stat",
		stat = "harvesting",
		threshold = 200,
		challengeId = "chal_agriculture",
		source = "res://challenges/agriculture_data.tres",
		sourceMd5 = "2b22e9d2623a1203fd4991db4cc4c405",
		requirement = "Reach +200 Harvesting",
	},
	Saver = {
		kind = "MaterialsCollected",
		threshold = 20000,
		challengeId = "chal_gatherer_5",
		source = "res://challenges/gatherer_5_data.tres",
		sourceMd5 = "8edfd66dec592078aaf791b1c13a9540",
		requirement = "Collect 20000 materials",
	},
	Glutton = {
		kind = "RunConsumables",
		threshold = 20,
		challengeId = "chal_hungry",
		source = "res://challenges/hungry_data.tres",
		sourceMd5 = "aac07fbeffc27b341495cbb52d256afa",
		requirement = "Pick up 20 consumables during a run",
	},
	Technomage = {
		kind = "Inventory",
		count = "structures",
		threshold = 3,
		stat = "elementalDamage",
		statThreshold = 10,
		challengeId = "chal_magic_and_machinery",
		source = "res://challenges/magic_and_machinery_data.tres",
		sourceMd5 = "006ba18830e853f72908971b34983e7f",
		requirement = "Have 10 Elemental Damage and 3 structures at the same time",
	},
	Renegade = {
		kind = "Inventory",
		count = "distinctItemsTier1",
		threshold = 10,
		challengeId = "chal_scavenger",
		source = "res://challenges/scavenger_data.tres",
		sourceMd5 = "b1e0f226f4b75ae47c1a33c02e4e5f9d",
		requirement = "Have 10 different tier I items during a run",
	},
	Cryptid = {
		kind = "WaveLivingTrees",
		challengeId = "chal_forest",
		threshold = 10,
		source = "res://challenges/forest_data.tres",
		sourceMd5 = "8ba3b54e7327462d38d5fae9abd0da7d",
		requirement = "Finish a wave with 10 or more living trees",
	},
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
