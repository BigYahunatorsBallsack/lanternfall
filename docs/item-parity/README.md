# Item replacement — 6 November 2026

The owner's request replaces the **124 existing catalog entries** with 124 distinct items from Brotato's main game. It does not add the rest of Brotato's catalog. Original names, prices, rarity, ownership limits, stat packages and the represented special effects replace the previous Lanternfall variants. DLC equivalents Baby Squid, Bone Dice, Cauldron, Coral, Goblet and Ashes are replaced by Bat, Tentacle, Lemonade, Mushroom, Sunglasses and Warrior Helmet.

Historical ids remain internal for existing achievement unlocks, evolution requirements, checkpoints, structure weapon sources and the compact structure feed. For example `Focus` now displays Coffee, `LoneFlame` displays Focus, and `Armor` displays Metal Plate. No profile schema change is needed. Unlock conditions remain Lanternfall's existing achievements and characters.

`catalog.json` records the source facts in **Brotato units** and maps them to internal ids. Runtime Max HP and healing retain the established **x10 HP conversion**. Main-game source: [Items](https://brotato.wiki.spellsandguns.com/Items), retrieved 6 November 2026, table marked version 1.1.15.4. The table repeats Candy Bag; the replacement catalog has no duplicate original names. Names and item numbers were checked directly against that table.

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

The owner explicitly authorized the item-related changes in the Strang A combat and boss services on 6 November 2026. The four changed assertions in `Smoke.spec.luau` and the text expectations in `RunStats.spec.luau` only follow the replaced item values/names; new integration coverage lives in `ItemParity.spec.luau`.

## Owner test

1. Sync this branch with Rojo, start a solo test, and open the shop after wave 1. Check original names and images; for example Cake gives +30 Max HP / -1% Damage, Injection gives +7% Damage / -20 Max HP.
2. Use the debug item buttons and inspect the inventory/tooltips. Check Banner's -5 Knockback, Acid's -2 Knockback, Exoskeleton's +5 Engineering, and Robot Arm's Engineering growth.
3. With Ball and Chain, add Attack Speed: weapons still wait at least 0.75 seconds. With Ghost Outfit, the dodge tooltip permits 70%; a second client without the item stays capped at 60%.
4. Take Bloody Hand or Blood Donation and reduce HP. Self-damage continues through timed hit protection and can down the player. A Tardigrade absorbs one such tick. In solo, dying ends the run; in a two-client test, the teammate can revive the player.
5. With Candy Bag, start repeated waves: each has a 10% chance of an extra champion with a warning marker. Its appearance is random; it is covered deterministically by the automated test.
6. Repeat shop/inventory inspection in a two-client session and at phone resolution. Confirm readable card effects and that each player receives only their own item bonuses.
