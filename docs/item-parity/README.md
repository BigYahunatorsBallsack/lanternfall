# Item replacement — 6 November 2026

The owner's request replaces the **125 existing catalog entries** with 125 distinct items from Brotato's main game. It does not add the rest of Brotato's catalog. Original names, prices, rarity, ownership limits, stat packages and the represented special effects replace the previous Lanternfall variants. DLC equivalents Baby Squid, Bone Dice, Cauldron, Coral, Goblet and Ashes are replaced by Bat, Tentacle, Lemonade, Mushroom, Sunglasses and Warrior Helmet.

Historical ids remain internal for existing achievement unlocks, evolution requirements, checkpoints, structure weapon sources and the compact structure feed. For example `Focus` now displays Coffee, `LoneFlame` displays Focus, and `Armor` displays Metal Plate. No profile schema change is needed. Unlock conditions remain Lanternfall's existing achievements and characters.

`catalog.json` records the source facts in **Brotato units** and maps them to internal ids. Runtime Max HP and healing use **original Brotato units (x1)**, following the owner decision now merged on main. Main-game source: [Items](https://brotato.wiki.spellsandguns.com/Items), retrieved 6 November 2026, table marked version 1.1.15.4. The table repeats Candy Bag; the replacement catalog has no duplicate original names. Names and item numbers were checked directly against that table.

## Special effects corrected

- Blood Donation and Bloody Hand inflict lethal self-damage, consume Tardigrade, trigger Hurt and give no hit protection. Armor, dodge and timed hit protection do not stop the damage. [Blood Donation](https://brotato.wiki.spellsandguns.com/Blood_Donation), [Bloody Hand](https://brotato.wiki.spellsandguns.com/Bloody_Hand).
- Ghost Outfit raises only its owner's dodge cap to 70%, and the stat panel reports that cap.
- Ball and Chain imposes a 0.75-second minimum on weapons and attacking structures after Attack Speed is applied. [Ball and Chain](https://brotato.wiki.spellsandguns.com/Ball_and_Chain).
- Candy Bag has an authoritative 10% roll per wave for an additional random champion, using the existing spawn warning, current-wave growth, kill rewards and enemy budget. [Candy Bag](https://brotato.wiki.spellsandguns.com/Candy_Bag).
- Giant Belt computes its bonus from the target's pre-hit HP. Percentage damage is not increased by Damage or Silver Bullet; its endless reduction uses `floor(health * share / max(1, endlessFactor * 0.2))`. [Giant Belt](https://brotato.wiki.spellsandguns.com/Giant_Belt), [Endless Mode](https://brotato.wiki.spellsandguns.com/Endless_Mode#Health_Percent_Damage).
- Baby Elephant and Cyberball select one random non-tree target per event; independently successful copies hit that same target.
- Missing Engineering, Knockback and other downsides are restored. Barricade has no ownership limit; Rip and Tear has the source limit of five.

## Integration limits

This is a replacement of item content within Lanternfall's existing game: its characters, achievements, cooperative rules, enemies, 3D ranges and simulation budgets still apply. There is no Nightmare fog system, so the Campfire/Candle fog-only rules have no applicable mode. Structures continue using the project's bounded ray-based simulation rather than reproducing Brotato's 2D projectile travel. No claim is made that Lanternfall as a whole is a frame-identical Brotato simulation.

The owner explicitly authorized the item-related changes in the Strang A combat and boss services on 6 November 2026. The changed item assertions in `Smoke.spec.luau` and the text expectations in `RunStats.spec.luau` only follow the replaced item values/names; new integration coverage lives in `ItemParity.spec.luau`.

## Owner test

1. Sync this branch with Rojo, start a solo test, and open the shop after wave 1. Check original names and images; for example Cake gives +3 Max HP / -1% Damage, Injection gives +7% Damage / -2 Max HP.
2. Use the debug item buttons and inspect the inventory/tooltips. Check Banner's -5 Knockback, Acid's -2 Knockback, Exoskeleton's +5 Engineering, and Robot Arm's Engineering growth.
3. With Ball and Chain, add Attack Speed: weapons still wait at least 0.75 seconds. With Ghost Outfit, the dodge tooltip permits 70%; a second client without the item stays capped at 60%.
4. Take Bloody Hand or Blood Donation and reduce HP. Self-damage continues through timed hit protection and can down the player. A Tardigrade absorbs one such tick. In solo, dying ends the run; in a two-client test, the teammate can revive the player.
5. With Candy Bag, start repeated waves: each has a 10% chance of an extra champion with a warning marker. Its appearance is random; it is covered deterministically by the automated test.
6. Repeat shop/inventory inspection in a two-client session and at phone resolution. Confirm readable card effects and that each player receives only their own item bonuses.

## Original sprites

All 125 PNGs in `assets/ui/items/` are unchanged original files from the linked Wiki. `manifest.json` records each source URL, size and SHA-256. The old custom PNGs were replaced at their existing paths; no orphaned PNGs remain. `sprite-gallery.png` is a contact sheet for visual inspection, with thumbnails fitted to the cells; it does not modify the source files. Run `python tools/verify-item-assets.py` to verify the original files.

## Validation

Current base: `fc17890` (enemy values and enemy sprite package merged). Baseline: **747 passed / 31 failed in 73 specs**. Full branch run: **887 passed / the same 31 failed in 75 specs**, with identical failures in every existing spec. Final targeted checks: **136/0 ItemParity**, **5/0 ItemSprites**; the fifth sprite fallback test was added after the full run. Selene: 0 errors / 11 pre-existing warnings. Own changed modules pass StyLua; Rojo build and diff checks pass. Run each spec separately with Lune as documented in the test runner.

All **125** original PNG hashes were verified and all **125** assets were uploaded. Studio Edit preloading of detached ImageLabels succeeded for **124** sprites. **Eyes Surgery (`Bellows`, asset 101596251956695) is Rejected by Roblox moderation**, confirmed through the Assets API. The original file is retained unchanged, the uploaded id remains traceable, and the UI shows a stat fallback when the image cannot load. There was no alternate upload to bypass moderation. The owner must resolve that asset's moderation outcome with Roblox before its exact sprite can display. Evidence: `assets/ui/items/roblox-validation.json`.

The Studio asset check did not install branch scripts, change the place, or publish it. A full branch run, real two-client test and phone test remain for the owner. The two-player item rules and sprite bindings/pool cleanup were tested in the isolated Luau mock.

## Final main update

The weapon package on main `5a1ec54` is also merged. Original weapon minimum timing and Ball and Chain's 0.75-second restriction are both retained. Latest complete comparison: **933 passed / 31 failed in 76 specs**, against main **792 / 31 in 74 specs**. The current report supersedes the preceding earlier-base totals. Both new specs are fully included in this final run.

The independently randomized full runs differ in two existing specs: the branch avoids the previously flaky mine count failure and has a fluctuating enemy-distance failure in Smoke. A controlled Smoke comparison using seed 1234 in both test loaders gives **14 passed / 29 identical failures on each side**. No production files were changed for that comparison. Remaining failures include the old Wand/Spark Bolt and other weapon/evolution expectations in the shared smoke test; they are outside the item change.

## Merge compatibility with upgrade artwork

The subsequently merged main `0a841e5` is included before the approved merge. All 185 affected checks across ItemParity, ItemSprites, PrimaryStatArt, UpgradeReference, EffectRules and WeaponStats pass. Original card artwork, Engineering IV +5 and item-image failure handling coexist; the two item-only limit stats reuse the Attack Speed / Dodge symbols without adding upgrade cards. StyLua, Selene, Rojo and diff checks pass. The full-suite figures above remain tied to their explicitly recorded earlier base.

## Neutral Eyes Surgery sprite — owner choice, 6 November 2026

This section supersedes the previous blocked-image status. The owner explicitly requested a neutral replacement instead of the original Eyes Surgery artwork. Built-in image_gen created an original illustration of intact optician glasses and a small adjustment tool, without blood, anatomical eyes or injuries. The different design was uploaded with an accurate neutral description as asset **110223481359323**; Roblox reports **Approved**, and Studio Edit image preloading reports **Success**.

The active catalog now contains **124 unchanged Wiki sprites and one approved original replacement**. All 125 active images have successful preload evidence. The old rejected asset is recorded as history; it was not altered or re-uploaded. Item name, stats, price, tier, limit and effects are unchanged. The full generation prompt, provenance, alpha check, SHA-256 and native checks are recorded in `neutral-eye-sprite.json`.

Owner test: start a new test after syncing the branch, obtain Eyes Surgery from the shop/debug items, and check that the optician glasses appear in its card and inventory. The item should retain +1 Elemental Damage, -10 Range and +20% Burning Speed.

Final replacement checks: all **125/125** active image IDs preloaded together with **Success** in Studio Edit; 5/0 item-sprite tests; 125 PNG manifest checks; StyLua, Rojo and diff checks pass; Selene 0 errors / 11 existing warnings. No branch scripts installed into the concurrently edited Studio place, no live publish and no full gameplay run claimed.
