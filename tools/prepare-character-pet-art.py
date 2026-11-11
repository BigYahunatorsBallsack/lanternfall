"""Prepare six original pet inventory icons locally; never upload or modify runtime IDs."""
from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import re
import sys
from pathlib import Path

from PIL import Image

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("pet_art_source", ROOT / "tools/character-source.py")
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
pck = source.Pck()
facts = json.loads((ROOT / "docs/characters/pet-source.json").read_text(encoding="utf-8"))
folder = ROOT / "assets/items/character-pets"
folder.mkdir(parents=True, exist_ok=True)
manifest = {"version": facts["version"], "steamBuild": facts["steamBuild"], "uploadedCount": 0, "runtimeChanged": False, "icons": [], "actorArtworkPrepared": False}
for row in facts["pets"]:
    icon = row["iconSource"]
    imported = pck.read(icon + ".import").decode("utf-8")
    texture = re.search(r'path="([^"]+\.stex)"', imported)[1]
    raw = pck.read(texture)
    assert raw[:4] == b"GDST", texture
    image = Image.open(io.BytesIO(raw[raw.index(b"RIFF"):])).convert("RGBA")
    assert image.size == (96, 96), (icon, image.size)
    output = folder / (row["id"] + ".png")
    image.save(output)
    assert Image.open(output).convert("RGBA").tobytes() == image.tobytes()
    manifest["icons"].append({"id": row["id"], "source": icon, "textureSource": texture, "textureMd5": pck.entries[texture]["md5"], "output": output.relative_to(ROOT).as_posix(), "pngSha256": hashlib.sha256(output.read_bytes()).hexdigest(), "rgbaSha256": hashlib.sha256(image.tobytes()).hexdigest(), "size": list(image.size), "alphaBounds": list(image.getbbox())})
(folder / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(f"{len(manifest['icons'])} original pet icons prepared locally; actor animations remain open; no uploads or runtime ID changes")
