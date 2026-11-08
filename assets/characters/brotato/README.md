# Original Brotato character sprites

Owner request, 2026-11-08: use the linked [Characters Wiki](https://brotato.wiki.spellsandguns.com/Characters) images 1:1 for the new character catalog. This explicitly supersedes the earlier redraw-only instruction for **this character delivery**. These are original Brotato / Blobfish graphics, not newly drawn Lanternfall artwork.

The pack includes all 74 characters: 50 main game, 14 Abyssal Terrors and 10 Primal Dread. All PNGs are the original full-resolution 96 x 96 response bytes. No source sprite was cropped, resized, redrawn, traced or re-encoded. Every file has real alpha transparency and a unique hash. `contact-sheet.jpg` is a separate review composite; its checkerboard is not part of any PNG.

## Files

- `../../world2d/final/characters/<id>.png`: the 74 original sprites in the agreed delivery directory.
- `manifest.json`: exact original URL, character name, stable runtime id, original resource id, content set, byte length, SHA-1, SHA-256, alpha bounds and measured figure shares for every PNG.
- `import-fragment.json`: all 74 `characters.items` records ready for the existing art importer; each references its source PNG and sets `trimmed = true` so the importer can pad edge-touching original art.
- `validation.json`: results of source, transparency, catalog-coverage and importer checks.
- `contact-sheet.jpg`: every character labelled with its original name and runtime id.

## Stable ids

Ids match the current code agent's stable PC 1.2.0.1 character catalog. Nine historical profile aliases are retained; other ids use the original English name without spaces.

| Original character | Runtime id |
| --- | --- |
| Mage | SparkMage |
| Ranger | NightWatch |
| Multitasker | ManyHands |
| One Armed | SoleConductor |
| Gladiator | DuelMaestro |
| Hunter | FarSeer |
| Chunky | MarbleHost |
| Generalist | TwinLedger |
| Apprentice | CandleScholar |

`Bull.png` is a separate character. In particular, the old sprite brief's Marble Host / Bull association must not override the catalog's MarbleHost = Chunky mapping.

## Handoff to the code/upload agent

This PR delivers art and metadata only. No Roblox upload, image id, runtime change or catalog availability change is included. `docs/SPRITE-AUFTRAG.md` assigns upload and integration to the code agent. Keep the existing availability checks until real uploaded image ids and prepared image bounds are present.

1. Merge `import-fragment.json`'s `characters.items` into `tools/art2d/sprites.json`. Replace the nine old character records, including their `existing` fields, with the supplied source records; leave every other group unchanged.
2. Run `python tools/art2d/import_sprites.py check`, then `python tools/art2d/import_sprites.py build`.
3. Upload the prepared character images to the owner's Roblox account through the established workflow and pass the real returned map to `import_sprites.py apply`. Never use the raw source URL or a made-up asset id as an in-game image id.
4. Use the prepared record's measured shares in `SpriteImages`. `manifest.json.figureShares` describes the original 96-pixel canvas; these values must not be copied onto the padded/resized import result.
5. Update fixed nine-character artwork/roster expectations when integrating the larger roster. Only code-ready packages should become selectable. Use the existing animated feet; the delivered character images contain no feet or weapons.

## Verification

All 74 local files were compared with the Wiki's independent MediaWiki `imageinfo` API: original URL, SHA-1, byte count and dimensions match. Their SHA-256 values are also recorded. All PNGs decode, contain transparent pixels, and map one-to-one to the 74 code-catalog ids (including all nine aliases).

The unmodified importer accepted all 74 with `trimmed = true`. An in-memory copy of its character list was replaced with the fragment and the complete art check reported **111 final, 27 placeholder, 0 missing, 0 unusable**. All 74 also passed the real `prepare(..., 1024, False)` path with transparent margins and valid measured shares. This did not modify the repository's sprite list or the original PNGs.

`python tools/art2d/import_sprites.py check` against the unchanged main list also passes (**46 final, 27 placeholder, 0 missing, 0 unusable**). That main list still enumerates nine characters, so that check alone does not prove integration of the new roster.

`selene src` reports 0 errors, 11 existing warnings and 0 parse errors (exit 1 due to warnings). No Luau files changed, so StyLua does not apply.

Native Roblox solo/two-client/mobile tests and moderation/preload checks are pending upload and integration. No gameplay behavior was changed by this asset pack.

## Owner review

1. Open `contact-sheet.jpg` and compare the characters with the linked Wiki.
2. After the code agent uploads and integrates the pack, open character selection and select a code-ready new character. Its portrait and in-world body should match; verify feet animate once and accessories stay visible.
