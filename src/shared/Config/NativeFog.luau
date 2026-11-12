--!strict
-- Verified stable1.2.0.2 fog rules and visual-source identities; graphics/runtime acceptance remains open.
return {
	targetVersion = "1.2.0.2",
	targetSteamBuild = 26615634,
	installedVisualCandidateVersion = "1.2.0.2",
	installedSteamBuild = 26615634,
	originalRulesVerified = true,
	originalVisualIdentitiesVerified = true,
	sources = {
		{
			source = "res://visual_effects/fog_viewport.gdc",
			sourceMd5 = "92b0c65d331d391bf44ef76c0d990d0e",
			origin = "approved installed stable1.2.0.2 reference",
		},
		{
			source = "res://visual_effects/shader_noise_displacement_add.tres",
			sourceMd5 = "b4e06e0e64658af64eff321cffb60366",
			origin = "approved installed stable1.2.0.2 reference",
		},
		{
			source = "res://main.tscn",
			sourceMd5 = "efcb4d44256907d4ca88d41d0dad0311",
			origin = "approved installed stable1.2.0.2 reference",
		},
		{
			source = "res://main.gdc",
			sourceMd5 = "7fe126c48998aaa276685bdfc4746e0a",
			origin = "approved installed stable1.2.0.2 reference",
		},
		{
			source = "res://particles/burning/burning_particles.gdc",
			sourceMd5 = "022970f9405dc39c1bdd570e58a40555",
			origin = "approved installed stable1.2.0.2 reference",
		},
		{
			source = "res://entities/units/unit/unit.gdc",
			sourceMd5 = "aa94391f2d9681ac36b7f8617b82ff13",
			origin = "approved installed stable1.2.0.2 reference",
		},
		{
			source = "res://entities/gpe/fire_puddle/fire_puddle.gdc",
			sourceMd5 = "a31c18617860b08b845c0c5d82430604",
			origin = "approved installed stable1.2.0.2 reference",
		},
		{
			source = "res://visual_effects/player_light_in_shadow.tscn",
			sourceMd5 = "6a44504778ff5a4673adb17678ac8941",
			origin = "approved installed stable1.2.0.2 reference",
		},
		{
			source = "res://visual_effects/elemental_light_in_shadow.tscn",
			sourceMd5 = "cb2252c0ad963800780381aa7f5eed6f",
			origin = "approved installed stable1.2.0.2 reference",
		},
		{
			source = "res://visual_effects/structure_and_pet_light_in_shadow.tscn",
			sourceMd5 = "867f7fd2bca66f91b39d8a1cb02e4cb7",
			origin = "approved installed stable1.2.0.2 reference",
		},
	},
	rules = {
		viewport = {
			1920,
			1080,
		},
		waveCap = 20,
		waveScaleBase = 2.75,
		waveScaleLoss = 1.75,
		visibilityMin = -100,
		visibilityMax = 9999,
		fadeSeconds = 0.25,
		explosionHoldSeconds = 0.25,
		permanentLossBase = 15,
		permanentLossPerWave = 1.5,
		permanentLossMax = 45,
	},
	lights = {
		player = {
			layers = {
				{
					scale = {
						1,
						1,
					},
					color = {
						1,
						1,
						1,
						0.254902,
					},
					rotation = {
						length = 40,
						keyEnd = 40,
					},
				},
				{
					scale = {
						0.741909,
						0.741909,
					},
					color = {
						1,
						1,
						1,
						0.196078,
					},
					rotation = {
						length = 220,
						keyEnd = 220,
					},
				},
				{
					scale = {
						0.623581,
						0.596635,
					},
					color = {
						1,
						1,
						1,
						1,
					},
					rotation = {
						length = 365,
						keyEnd = 366,
					},
				},
			},
			pulse = {
				length = 1.4,
				times = {
					0,
					0.7,
					1.4,
				},
				values = {
					1.5,
					1.55,
					1.5,
				},
				interpolation = 2,
			},
			warp = {
				["shader_param/wave_speed"] = 0.233,
				["shader_param/wave_size"] = 5.671,
				["shader_param/wave_strenght"] = 0.017,
			},
		},
		fire = {
			layers = {
				{
					scale = {
						1,
						1,
					},
					color = {
						1,
						0.552941,
						0.415686,
						0.254902,
					},
					rotation = {
						length = 16,
						keyEnd = 16,
					},
				},
				{
					scale = {
						0.536357,
						0.536357,
					},
					color = {
						1,
						0.937255,
						0.596078,
						0.196078,
					},
					rotation = {
						length = 120,
						keyEnd = 120,
					},
				},
			},
			pulse = {
				length = 1.4,
				times = {
					0,
					0.7,
					1.4,
				},
				values = {
					0.5,
					0.6,
					0.5,
				},
				interpolation = 2,
			},
			warp = {
				["shader_param/wave_speed"] = 1.049,
				["shader_param/wave_size"] = 1.471,
				["shader_param/wave_strenght"] = 0.114,
			},
		},
		structure = {
			layers = {
				{
					scale = {
						1,
						1,
					},
					color = {
						1,
						1,
						1,
						0.254902,
					},
					rotation = {
						length = 16,
						keyEnd = 16,
					},
				},
				{
					scale = {
						0.536357,
						0.536357,
					},
					color = {
						1,
						0.937255,
						0.596078,
						0.196078,
					},
					rotation = {
						length = 120,
						keyEnd = 120,
					},
				},
			},
			pulse = {
				length = 1.4,
				times = {
					0,
					0.7,
					1.4,
				},
				values = {
					0.5,
					0.6,
					0.5,
				},
				interpolation = 2,
			},
			warp = {
				["shader_param/wave_speed"] = 1.049,
				["shader_param/wave_size"] = 1.471,
				["shader_param/wave_strenght"] = 0.114,
			},
		},
	},
	runtimeCompatibility = {
		maskSize = 128,
		renderHeight = 108,
		fallbackHeight = 36,
		updatesPerSecond = 10,
		displayOrder = -2,
		nativeTextureSize = 512,
		nativeGraphicsAccepted = false,
		openGraphics = {
			"OpenSimplex UV displacement",
			"per-channel colored multiply",
			"native animation/process ordering",
			"native resolution and device performance",
			"burning-emitter native position offsets and snapshot latency",
		},
	},
}
