# Weapon shop design review

This is a standalone, clickable review page. It does not connect to Roblox gameplay. The same card hierarchy and uploaded weapon images are now used in the in-game shop.

## References

- [Brotato shop screenshot, Steam Community](https://steamcommunity.com/app/1942280): four tall offer cards, visible prices and locks, currency, stats panel and bottom equipment row.
- [Brotato wave 9 shop screenshot, Metabrotato](https://www.metabrotato.com/blog/brotato-farmer-build-the-ultimate-guide): card hierarchy, reroll action and next-wave action.
- Existing Lanternfall item icon contact sheet was used as a style reference. No item art is used on this page.
- [`HeldModels.luau`](../../src/client/Controllers/WeaponRenderer/HeldModels.luau) and [`HeldMeshCatalog.luau`](../../src/client/Controllers/WeaponRenderer/HeldMeshCatalog.luau): current weapon silhouettes, materials and authored mesh IDs.

The four weapon illustrations were created with the built-in image generation tool, using the item contact sheet as a style reference and the current weapon model descriptions as subject constraints. All four have transparent backgrounds. Prompts requested one weapon per icon, chunky asymmetrical shape, dark ink contour, broad painted lighting, no frame or text. The icon files live in `assets/`.

The Orbit Blades image was corrected after checking the authored mesh in Studio: its current held model is a circular saw, not a sword.

The four cards and their stats are a sample view, not a captured live shop state. Buying, locking and rerolling demonstrate visual states only. Prices and the level 8 sidebar are illustrative. The in-game shop uses the actual server shop state and current stat calculations.
