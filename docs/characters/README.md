# Character source: stable PC 1.2.0.1

The owner selected stable PC version 1.2.0.1 with every DLC. The installed Steam copy provides the missing and outdated Wiki facts. `source.json` records all 74 character resources: 50 main game, 14 Abyssal Terrors and 10 Primal Dread. Original zero-based tiers become tiers I–IV in `CharacterCatalog.luau`. Historical Lanternfall profile ids remain internal aliases for the nine existing characters.

Provenance includes Steam build 26406319, update date 2026-11-03, the installed version literal 1.2.0.1, the complete PCK SHA-256, resource paths and individual hashes. `tools/character-source.py` reads the unencrypted local PCK and parses text resources without executing them. It does not commit game scripts, images, audio or scenes. Scratch inspection files and tools stay in ignored `build/character-source`.

`startingWeapons` and `startingItems` are **selection alternatives**; `guaranteedEquipment` contains additional fixed grants. For example, Beast Master chooses a starting pet and separately receives Lootworm and Ratzilla. Treating all selectable pets as fixed grants would be incorrect.

`tools/build-character-catalog.py` compiles the neutral facts into typed Luau configuration. The catalog preserves every effect, separates plain stats and supported conversions, and explicitly lists rules awaiting runtime integration. A complete source record is **not** a claim that the character is playable or implemented. `Classes.luau` keeps new characters unavailable until their dependencies, server rules and selection paths are verified. Existing active packages keep their delivered behavior during the incremental integration.

Checks:

- `python tools/character-source.py --output build/character-source/recheck.json` regenerates the neutral source from the installed copy.
- `python tools/build-character-catalog.py --check` checks the runtime data against the checked-in facts.
- `lune run tools/luau-test-runner/lune-runner.luau tests/CharacterCatalog.spec.luau` checks count, original HP, stable ids, equipment separation and native class-bonus units.
- Source tiers and modifier lists must be used exactly: Ghost's +10 is flat weapon damage, Crazy's weapon range is not halved as an ordinary melee Range modifier, and One Armed's damage-gain multiplier applies to every stat listed by its source effect.

The 1.2.0.1 native resources differ from older Wiki entries and sometimes from prose release notes; the serialized stable build is the deciding reference. The source compiler currently reports required weapon/item families missing from the older project catalog. They remain implementation work, alongside the explicit policy rules. Sprite creation remains assigned to the other agent.
