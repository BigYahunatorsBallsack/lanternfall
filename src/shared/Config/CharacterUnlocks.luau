--!strict
-- Verified native character challenges; PlayerDataService persists their flags and CharacterChoice shows requirements.
-- Further locked characters stay unavailable until their challenge and complete code package are connected.
export type Challenge = {
	challengeId: string,
	source: string,
	sourceMd5: string,
	stat: string,
	threshold: number,
	requirement: string,
}
local rules: { [string]: Challenge } = {
	Ghost = {
		challengeId = "chal_hallucination",
		source = "res://challenges/hallucination_data.tres",
		sourceMd5 = "ceb46e5084b26af1de591ec752828310",
		stat = "dodge",
		threshold = 60,
		requirement = "Reach +60 % Dodge",
	},
}
return table.freeze(rules)
