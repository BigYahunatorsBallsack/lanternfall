# Spawn cross sprite

`SpawnCross.png` is the final transparent sprite for enemy spawn warnings. Created with the built-in Imagegen tool using the owner's screenshot, the owner selected the FIRST version without interior black strokes. AI recreation; pixel-exact equivalence is not claimed.

## Integration handoff

No Roblox upload or production code changes are included. On main, `src/client/Controllers/SpawnMarkerRenderer.luau` still builds the marker from four rounded Frames; adding a PNG alone does not change the game.

1. Upload `SpawnCross.png` through Studio's Asset Manager and record its asset ID.
2. Claude: use that image in `SpawnMarkerRenderer` instead of the generated bars. Preserve pooling, server timing and the spawn position. Keep the supplied red colors and baked dark outline; do not add another outline. Keep the upright, slightly tilted plus shape instead of rotating it into a diagonal X.
3. Test a run: markers should have a transparent background, the original first-version red fill without interior black strokes and no square around them. They must disappear when the enemies appear. Check solo, two clients and a small screen.

## Selected generation prompt

Recreate only the red spawn cross from the owner screenshot as an isolated transparent sprite. Match its crooked plus silhouette, proportions, colors, red inner streaks and thick nearly black exterior outline. No ground, stones, text, shadow or glow. The owner selected this first generation, without the later interior black strokes. Generated with built-in Imagegen.

## Validation

Inspect the actual PNG visually and check that it is square RGBA, with alpha values spanning 0 to 255 and transparent corners. Studio runtime validation remains pending until upload and integration. StyLua, Selene and Luau tests are not applicable to this asset-only change.
