# B10: all Brotato characters, stable PC 1.2.0.1

The owner requests all 74 characters, including both DLCs, with original mechanics and values. Sprites belong to another agent. Target is stable 1.2.0.1, not the live beta. Start from GitHub main and preserve other work. The owner authorizes character-specific hooks in Strang A. Rules and the initial parity audit are committed first.

Implement complete, tested slices. The existing modifier/effect/weapon systems remain the foundations. Character-specific state must be checkpointed for retry and cleared between runs. Client messages remain intents; validation and all mechanics stay authoritative. Original internal profile ids remain resolvable. Do not label a character complete while its dependency or behavior is missing.

1. Extract factual character/start/effect resources from the owner's unencrypted local game; verify stable version, hashes and all 74 entries. Do not commit game scripts, sprites or compiled files.
2. Extend the existing character contracts and deliver simple stat/class/tier/slot restrictions with real source-based start choices. Validate no weapon and 24-slot characters, server restrictions, acquisition/merge paths and compatible ids.
3. Implement character healing/damage/missing-health rules (including regeneration) and live event effects. Verify Golem, Wounded, Lich, Sick, Vampire, Bull, Masochist, Speedy and Soldier.
4. Implement XP/card/level and wave-end policies; capture survivors before clearing. Verify Mutant, Baby, Technomage, Captain, Pacifist, Cryptid and growth/economy characters.
5. Implement shop, inventory, recycling and HP currency policies, including guaranteed offers and steal consequences. Verify Arms Dealer, Demon, Fisherman, King, Renegade, Gangster and Curious.
6. Implement authoritative arena/enemy/wave and structure/pet policies. Verify Old, Explorer, Jack, Engineer, Streamer, Cyborg, Beast Master and Builder.
7. Implement DLC dependencies and character mechanics: cursed gear/enemies, charmed enemies, step/overkill/burn effects, digs, hunting zones, time shift, fog, evolution/mechanization/mutation, crate weapons. Include required starting gear using behavior modules; preserve Arsenal.
8. Integrate catalog, unlock rules, selection UI and placeholder-safe art mappings. Validate all 74 can be chosen/started, two-client isolation, retry and new-run reset. Sprite delivery stays separate.
9. Run source and behavior tests, compare the existing failing baseline, lint changed files, build with Rojo, review the diff and publish the branch/PR. Report exact manual runtime limitations and owner test steps. The owner authorizes future merges without another approval (08 November 2026).

Acceptance: every listed character has all source rules connected to runtime behavior, every required dependency works, no placeholder mechanic is presented as 1:1, and baseline failures are distinguished from regressions.
