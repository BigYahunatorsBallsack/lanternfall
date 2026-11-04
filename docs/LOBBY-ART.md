# Hub lobby artwork (Paket 21d)

The hub keeps its 80 × 80 stud playable floor, central `LobbySpawn` and the three existing portal prompts. `LobbyArtService` adds a decorative model after `MapService` creates the map. It runs on both places so the waiting lobby has the same spawn landmark; portal artwork and paths appear only on the hub.

## Look

- Original cartoon meshes use broad stone and brass forms, dark outlines, warm lantern accents and a small number of readable details. They borrow the approved enemy artwork's compact, painted feel without using another game's assets.
- A stone and brass arrival sigil marks the 20 × 20 stud spawn pad. The lantern beacon sits 24 studs behind it, leaving the pad clear for arrivals.
- Stone paths lead to the existing Solo, Party and Quick Join gates. Each has a textured arch and its own small colored keystone light. The gate planes remain visible at lower opacity; their `ProximityPrompt` and signs remain unchanged.
- Six original street lantern models replace the old visual posts. A low perimeter and four corner ruins establish the edge of the hub. All added geometry has collision, touch and query disabled. Optional lights carry the existing graphics tag.

## Asset provenance

The following models were generated as original assets in Roblox Studio's mesh generation tool on 4 November 2026. The mesh and texture IDs are configured in `src/shared/Config/LobbyArt.luau`. No Creator Store model or imported game artwork is used.

| Model | Mesh IDs | Texture IDs |
| --- | --- | --- |
| Carved portal arch | `116085205083415` | `77687836357460` |
| Vigil beacon lantern + pedestal | `71409837852268`, `126662315018038` | `127873625713955`, `87225033949185` |
| Street lantern foot + post + cage | `107288581818143`, `71661305773600`, `76232616460057` | `138767202260381`, `104482715065355`, `72220127240473` |

Mesh generation prompts specified chunky original stone and brass cartoon lobby props, clear silhouettes from the game's elevated camera, broad painted color regions and no text or copied characters. The generated parts were inspected individually in Studio. A temporary 80 × 80 stud preview used the actual `LobbyArtService` source with a minimal map stub to check spacing and asset loading; that preview was separate from the loaded game code.

## Owner test in Studio

1. Synchronize this branch to the **Hub place** and start a solo playtest. Check that the arrival circle is legible, the beacon stands behind it, and the three portals show their own colors and labels.
2. Walk from the spawn pad to each portal. Each prompt should still appear and start Solo, Party or Quick Join as before.
3. In **Test → Clients and Servers**, join with two clients. Both should see the same scene; neither should be blocked by the new artwork.
4. Switch to a phone viewport and inspect the scene from the spawn position. Report any missing meshes or frame rate drop. If the place is published, also check that each generated mesh and texture loads for a normal player account.

Rojo build, StyLua and Selene cover source validity. A full run of this branch in the actual Hub place and phone performance measurement need the Owner's Studio test after synchronization.
