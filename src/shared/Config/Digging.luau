--!strict
-- Native Dig Site geometry, placement and progress facts; DiggingService and its renderer share this config.
-- Source and hashes: docs/characters/digging-source.json, stable PC1.2.0.1.
return table.freeze({
	minimumSeconds = 5,
	maximumSeconds = 6,
	halfSize = 9,
	playerBodyRadius = 2.4,
	playerBodyOffsetZ = -1.2,
	minimumSpacing = 35,
	minimumCenterDistance = 40,
	edgeMargin = 15,
	placementTries = 30,
	maxSites = 100, -- technical ceiling; follows the existing world-structure budget
	snapshotSeconds = 0.2,
	unlockCount = 10,
	challengeId = "chal_dig_site",
	item = "DigSite",
	visualSize = 25.6, -- five native AtlasTexture canvases are256x256 points
	depth = 0.05, -- floor layer, behind consumables and actors
	frames = 5,
})
