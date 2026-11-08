# Shard drop variants (own art)

Six original green shard pictures for materials lying on the floor, drawn from simple polygons by
`tools/art2d/draw_shards.py` (re-run it to regenerate). 256 x 256 px, transparent background.

Not uploaded yet. After uploading them as Roblox images, put the six ids into `Config.Sprites.material.variants`
(`src/shared/Config/Sprites.luau`) as `"rbxassetid://<id>"`. Until then every drop uses `images.material`, but already
turned, mirrored and resized per drop (`Util/MaterialLook`).
