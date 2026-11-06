# Original Brotato primary-stat and upgrade sprites

On the owner's explicit request of 6 November 2026, these replace the earlier Lanternfall illustrations for the 16 primary stats that have level-up upgrades. `stats/` contains the 16 stat-panel symbols; `upgrades/` contains the 16 different card illustrations (heart, lungs, teeth, arms, brain, etc.). The wiki uses the same upgrade illustration for all four tiers of a stat.

These are the original 96 x 96 PNG bytes served by the [Brotato Upgrades wiki](https://brotato.wiki.spellsandguns.com/Upgrades), with their original alpha and colors. They are Brotato artwork, not newly drawn Lanternfall artwork. `manifest.json` records every original URL, SHA-256, wiki revision and all 64 upgrade amounts. `Preview.png` shows the two image types next to each other.

Re-import with `python tools/import-upgrade-reference.py` (Pillow required). The importer validates the complete table and downloads the original files rather than the wiki thumbnails. It does not upload assets or alter the game code.

The 22 other existing stat entries have no level-up cards in the base-game table. Their existing illustrations remain available; no new upgrade types are invented for them.
