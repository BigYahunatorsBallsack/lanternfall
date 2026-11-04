# Lanternfall stat sprites

`final/` contains one original, transparent 1254×1254 PNG for each of the 38 IDs in `src/shared/Config/Stats.luau`. The ID-to-file mapping is recorded in `manifest.json`. The same stat image is used for every level-up tier and for the shop's stat panel.

The first ten images were individually approved by the owner. The remaining 28 were created in one pass at the owner's request and visually checked in `gallery-core.png` and `gallery-extra.png`. The designs use the game's item-art palette and silhouette style. The [Brotato Upgrades wiki](https://brotato.wiki.spellsandguns.com/Upgrades) informed which stats needed clear symbols; no wiki images are copied.

## Roblox upload

The PNGs must be uploaded to the game's Roblox creator inventory before the UI can display them. Add their `rbxassetid://...` IDs to `src/client/UI/StatImages.luau`, using the `id`/`file` pairs in `manifest.json`. `Icons.draw` already reads this map for both level-up cards and the shop stat panel. Until an ID is set and loaded, the existing drawn icon remains visible.

The image upload is still pending because no Roblox Studio instance was connected during this work. The `final/` files and the UI hook are ready for the IDs.
