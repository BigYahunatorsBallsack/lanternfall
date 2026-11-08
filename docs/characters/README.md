# Character source: stable PC 1.2.0.1

The owner selected stable PC version 1.2.0.1 with every DLC. The installed Steam copy provides the missing and outdated Wiki facts. `source.json` records all 74 character resources: 50 main game, 14 Abyssal Terrors and 10 Primal Dread. Original zero-based tiers become tiers I–IV in `CharacterCatalog.luau`. Historical Lanternfall profile ids remain internal aliases for the nine existing characters.

Provenance includes Steam build 26406319, update date 2026-11-03, the installed version literal 1.2.0.1, the complete PCK SHA-256, resource paths and individual hashes. `tools/character-source.py` reads the unencrypted local PCK and parses text resources without executing them. It does not commit game scripts, images, audio or scenes. Scratch inspection files and tools stay in ignored `build/character-source`.

`startingWeapons` and `startingItems` are **selection alternatives**; `guaranteedEquipment` contains additional fixed grants. For example, Beast Master chooses a starting pet and separately receives Lootworm and Ratzilla. Treating all selectable pets as fixed grants would be incorrect.

`tools/build-character-catalog.py` compiles the neutral facts into typed Luau configuration. The catalog preserves every effect, separates plain stats and supported conversions, and keeps other policy inputs explicit in `remainingRules`. Some of those inputs now have runtime handlers; that field is not a count of outstanding work. A complete source record is **not** a claim that the character is playable or implemented. `Classes.luau` keeps new characters unavailable until their dependencies, server rules and selection paths are verified. Existing active packages keep their delivered behavior during the incremental integration.

Checks:

- `python tools/character-source.py --output build/character-source/recheck.json` regenerates the neutral source from the installed copy.
- `python tools/build-character-catalog.py --check` checks the runtime data against the checked-in facts.
- `lune run tools/luau-test-runner/lune-runner.luau tests/CharacterCatalog.spec.luau` checks count, original HP, stable ids, equipment separation and native class-bonus units.
- Source tiers and modifier lists must be used exactly: Ghost's +10 is flat weapon damage, Crazy's weapon range is not halved as an ordinary melee Range modifier, and One Armed's damage-gain multiplier applies to every stat listed by its source effect.

The 1.2.0.1 native resources differ from older Wiki entries and sometimes from prose release notes; the serialized stable build is the deciding reference. The source compiler currently reports required weapon/item families missing from the older project catalog. They remain implementation work, alongside the explicit policy rules. Sprite creation remains assigned to the other agent.

Crazy, Brawler and Ghost are the first three code-ready native packages. Their original starting alternatives,
guaranteed equipment and character rules are connected. `nativeCodeReady` is separate from `available`: original sprites
with measured bounds remain a dependency assigned to the other agent. When those records arrive in `SpriteImages`,
the packages become available on the next server start. No placeholder image or weaker artwork check is introduced.
The sprite integration must also update the old fixed nine-character roster assertions in its artwork tests.

`crazy-text.json` records only the English wording needed by these packages, with the installed language-resource
hash and native text-formatting rule. The full recovered language catalog stays ignored. A shared
`CharacterRules.weaponBonuses` helper applies class/kind modifiers identically in combat and the shop preview.
Server-sent stat metadata includes native level and weapon-local modifiers for that read-only preview, including
full synchronization; these modifiers do not enter item/structure stats.

Native level starts at LV.0. Required XP uses `(L + 4)^2` and retains fractional character multipliers. The actual
source `weapon_slot_upgrade` adds one slot only when chosen; Baby does not gain capacity immediately upon receiving
XP. Its single slot card is replaced by ordinary stat cards at 24 slots. Captain modifies card amounts before stat
gain multipliers, and character-banned stat cards are excluded before wave 20. New stat/card artwork is still an
integration dependency of the packages which remain unavailable.

`item-groups.json` records the 13 native item ban groups and the exact original identity of every current item.
`weapon-access.json` records default access and original unlock requirements for all 91 current/required weapon
families. The corresponding generators accept `--check`. Native weapon access overrides the older invented weapon
locks: Hand is free, Claw requires a Cryptid win, and Vorpal Sword requires 100 Crit Chance. Stat challenge flags use
the existing string-keyed achievement map; existing data is retained without a profile schema change. The two event
challenges for Shovel and Flail remain tied to their outstanding DLC mechanic implementations.

Native starting selection respects weapon access on both client and server. Locked alternatives remain visible but
cannot be chosen. The shop/crate normal pools apply the source's explicit groups and item exclusions before wave 20;
character exclusions lift at wave 20 while Crown/Piggy Bank are removed. The same-tier backup keeps the original
exception which can reintroduce an excluded item if its normal pool is empty. General shop distribution, all item
unlock rules and the other character economy policies still require their separate parity work.

The original serialized tags of all 125 current items are preserved alongside their identities. Native packages
match their `wanted_tags` against these source tags (for example `stat_dodge`), rather than the older inferred
runtime stat aliases. The installed ItemService's ordinary preference chance is 0.05, matching the existing config.

Completed waves now capture survivors and settle effects/harvesting before either cleanup or result observers.
The installed `res://main.gdc` calls its wave-end effects and `manage_harvesting()` before `clean_up_room()` decides
the win/loss scene. `RunDirector.WaveRewards` follows `WaveEnding` after capture, including direct final victory;
`ExperienceService.addWaveReward` is a server-only settlement call because the flow may already be Ended. Ordinary
XP grants keep their ongoing-run guard. An endless vote cannot pay a wave twice, and an endless defeat labelled as
overall Victory does not count as clearing its failed wave. Retrying a failed wave retains no survivor reward.
Level gains during settlement enter the result summary before it is published. Real-service scenarios cover the
different outcomes, but native Roblox Studio acceptance remains outstanding.

Ghost's original Hallucination challenge is in `CharacterUnlocks`: reaching +60 % Dodge permanently sets its
existing-profile challenge flag. New native character packages consume an authoritative character-access mask;
legacy packages retain their existing access policy until their separate source adoption. Explicit saved grants
remain valid. The locked requirement and the Ghost rule text use the installed English formatting, including
the percent suffix of `EFFECT_DODGE_CAP`. The challenge survives saving/rejoining and does not affect another player.
Ghost's +10 flat Ethereal damage is weapon-local and agrees with the client preview; its 90% cap is tested through
actual hit resolution alongside a peer's ordinary cap. Native item preferences use serialized source tags.

Bull's hurt-explosion runtime is connected, while the package remains unavailable and is not `nativeCodeReady`.
`CharacterExplosions` records the original 30 base damage, triple Melee/Ranged/Elemental scaling, 3% base critical
chance, x1.5 critical multiplier and source collision geometry/hashes. The native calculation truncates flat
scaling and then rounds additive Damage/Explosion Damage bonuses. An actual lost-HP event resolves the blast
before the owner is marked down; dodges and absorbed hits do not emit it, and it does not life steal. Existing
Arsenal code is unchanged. The full package still needs the original Danger-1 win access, weaponless menu flow,
original rule display and simultaneous lethal/boss-death interaction verification. Common DLC effects and physics
timing remain subject to the overall parity audit.
The verified Bull access resource is `res://challenges/chal_difficulty_1_data.tres`
(MD5 `6a20708c5b6432e135b3266c6125a507`), rewarding Bull for the original Danger-1 win challenge.
