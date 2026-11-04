# Lanternfall stat sprites

`final/` contains one original, transparent 1254×1254 PNG for each of the 38 IDs in `src/shared/Config/Stats.luau`. The ID-to-file mapping is recorded in `manifest.json`. The same stat image is used for every level-up tier and for the shop's stat panel.

The first ten images were individually approved by the owner. The remaining 28 were created in one pass at the owner's request and visually checked in `gallery-core.png` and `gallery-extra.png`. The designs use the game's item-art palette and silhouette style. The [Brotato Upgrades wiki](https://brotato.wiki.spellsandguns.com/Upgrades) informed which stats needed clear symbols; no wiki images are copied.

## Roblox upload

All 38 PNGs were uploaded to the game's Roblox creator inventory on 04.11.2026. Their `rbxassetid://...` IDs are recorded in `final/roblox-assets.json` and `src/client/UI/StatImages.luau`. `Icons.draw` reads this map for both level-up cards and the shop stat panel; the existing drawn icon stays visible until the image loads.

Roblox Studio's Edit DataModel loaded all 38 assets successfully through temporary `ImageLabel` instances and `ContentProvider:PreloadAsync`. A gameplay view of the new UI still requires the merged code to be synchronized into Studio.
