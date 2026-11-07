# Original loot artwork

Four existing PNGs recovered from the previous unfinished content-parity task: Fruit, Crate, LegendaryCrate and Material. `manifest.json` records their original wiki URLs, dimensions and SHA-256 hashes. The recovered source bytes are unchanged.

`tools/art2d/sprites.json` references these sources directly. Entries marked `trimmed` accept tightly cropped rectangular originals; the existing importer pads and normalizes them before upload. `roblox-assets.json` records the prepared hashes, Roblox image IDs and successful native Studio Edit preload observed on 2026-11-06.

Regular pickup crates and the legacy elite-chest renderer share one uploaded image. The material image is shared by ground drops and currency counters. No new image was generated for this correction.
