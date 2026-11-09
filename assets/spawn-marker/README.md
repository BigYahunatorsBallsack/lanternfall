# Spawn cross sprite

`SpawnCross.png` is the final transparent sprite for enemy spawn warnings. Created with the built-in Imagegen tool using the owner's screenshot, then revised to add the requested dark interior ink lines. AI recreation; pixel-exact equivalence is not claimed.

## Integration handoff

No Roblox upload or production code changes are included. On main, `src/client/Controllers/SpawnMarkerRenderer.luau` still builds the marker from four rounded Frames; adding a PNG alone does not change the game.

1. Upload `SpawnCross.png` through Studio's Asset Manager and record its asset ID.
2. Claude: use that image in `SpawnMarkerRenderer` instead of the generated bars. Preserve pooling, server timing and the spawn position. Keep the supplied red colors and baked dark outline; do not add another outline. Keep the upright, slightly tilted plus shape instead of rotating it into a diagonal X.
3. Test a run: markers should have a transparent background, visible thin interior black strokes and no square around them. They must disappear when the enemies appear. Check solo, two clients and a small screen.

## Final edit prompt

Edit target: the isolated red cross sprite. Reference: the owner's small original screenshot. Keep the silhouette, tilt, red palette and thick black outer outline. Add thin, irregular near-black hand drawn interior ink strokes: a long slightly broken line down the vertical red arm, thin strokes along the horizontal red arm, a small rough intersecting junction near the middle and a few short parallel inner edge marks. Tone down large glossy highlight streaks so the interior reads flat cartoon red with dark sketchy contours. One isolated sprite, square PNG, real alpha transparency with margin. No ground, text, checkerboard, glow, shadow or extra symbols.

## Validation

Inspect the actual PNG visually and check that it is square RGBA, with alpha values spanning 0 to 255 and transparent corners. Studio runtime validation remains pending until upload and integration. StyLua, Selene and Luau tests are not applicable to this asset-only change.
