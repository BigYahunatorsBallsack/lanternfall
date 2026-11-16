--!strict
-- Source Jungle boss phase thresholds; NativeBossPhases handles base Timer callbacks only, custom timers and production controllers remain pending.
return {
	version = "1.2.0.3",
	steamBuild = 26642464,
	elapsedPerTimeout = 1,
	initialState = -1,
	timerScene = "res://entities/units/enemies/bosses/boss.tscn",
	timerSceneMd5 = "6018962cd6605773a1e63165e73a4dbc",
	ruleSources = {
		{
			source = "res://entities/units/enemies/bosses/boss.gdc",
			sourceMd5 = "a3cc583e1e8521d2899b6b7c56734685",
		},
		{
			source = "res://entities/units/enemies/bosses/boss_state.gdc",
			sourceMd5 = "7f6f65ae801262a06b954dbe7daaeddc",
		},
		{
			source = "res://entities/units/enemies/jungle/bosses/brachiosaurus/brachiosaurus.gdc",
			sourceMd5 = "c6e796b45d913450339d57f1997d3cdf",
		},
		{
			source = "res://entities/units/enemies/jungle/bosses/tyrannosaurus/tyranosaurus.gdc",
			sourceMd5 = "f44f413a22a26308968fd4575860cabf",
		},
		{
			source = "res://entities/units/enemies/jungle/elites/carnotaurus/carnotaurus.gdc",
			sourceMd5 = "372e3bb1b2aa3bd24d0bea3c65ee6fbc",
		},
		{
			source = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.gdc",
			sourceMd5 = "3dc7ae8b914cefbc9cc1c0174cbda70c",
		},
		{
			source = "res://entities/units/enemies/jungle/elites/therizinosaurus/therizinosaurus.gdc",
			sourceMd5 = "53e588213796a45ee4727f7a9205ea07",
		},
		{
			source = "res://entities/units/enemies/jungle/elites/diplodocus/diplodocus.gdc",
			sourceMd5 = "af84fabc22f46610936179144ddf33bf",
		},
	},
	actors = {
		Brachiosaurus = {
			source = "res://entities/units/enemies/jungle/bosses/brachiosaurus/brachiosaurus.tscn",
			sourceMd5 = "6c4e272aa68f9a47d91ee6fe7234ea3e",
			usesBasePhaseTimer = false,
			states = {
				{
					node = "State1",
					hpStart = 0.7,
					timerStart = 15,
				},
				{
					node = "State2",
					hpStart = 0.3,
					timerStart = 75,
				},
			},
		},
		Tyranosaurus = {
			source = "res://entities/units/enemies/jungle/bosses/tyrannosaurus/tyranosaurus.tscn",
			sourceMd5 = "99756375db500a4b0d146a6b08671342",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.7,
					timerStart = 15,
				},
			},
		},
		Baryonyx = {
			source = "res://entities/units/enemies/jungle/elites/baryonyx/baryonyx_neutral.tscn",
			sourceMd5 = "7b3be98c6ad6ad9dc390073f6dcba71b",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.5,
					timerStart = 30,
				},
			},
		},
		Carnotaurus = {
			source = "res://entities/units/enemies/jungle/elites/carnotaurus/carnotaurus_neutral.tscn",
			sourceMd5 = "e2baaa04dabeb191234049ac1bd32681",
			usesBasePhaseTimer = false,
			states = {
				{
					node = "State1",
					hpStart = 0.5,
					timerStart = 40,
				},
			},
		},
		Diplodocus = {
			source = "res://entities/units/enemies/jungle/elites/diplodocus/diplodocus.tscn",
			sourceMd5 = "d0805671ab5fe90cb3359c9fa9f56843",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.5,
					timerStart = 25,
				},
			},
		},
		Silesaurus = {
			source = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.tscn",
			sourceMd5 = "7c0b1ed5c7b0596267d328dde443ac4b",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.85,
					timerStart = 10,
				},
				{
					node = "State2",
					hpStart = 0.5,
					timerStart = 35,
				},
			},
		},
		Therizinosaurus = {
			source = "res://entities/units/enemies/jungle/elites/therizinosaurus/therizinosaurus.tscn",
			sourceMd5 = "526ab1bac95d7acc87a9fa5f701de07f",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.45,
					timerStart = 30,
				},
			},
		},
	},
	productionAdapterImplemented = false,
	nativeFullParityAccepted = false,
	audit = {
		elapsedBeforeSelection = true,
		hpInclusive = true,
		timeInclusive = true,
		everyEligibleLaterChildInOrder = true,
		synchronousCallbackBeforeNextChild = true,
		sourceIndicesStartAtZero = true,
		Carnotaurus = "Timer requests a deferred phase switch after the current jump has landed; not the base HP/time loop.",
		Brachiosaurus = "Timer directly calls on_state_changed(current_state) and increments that custom index; not the base HP/time loop.",
	},
}
