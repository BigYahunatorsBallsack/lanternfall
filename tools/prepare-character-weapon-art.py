"""Prepare original starting-weapon icons locally; never upload or alter runtime IDs.

Reads the installed stable PCK with integrity checks and decodes its embedded
WebP pixels. Output PNGs preserve the decoded RGBA pixels, including transparency.
"""
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
spec = importlib.util.spec_from_file_location("character_source", ROOT / "tools/character-source.py")
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
facts = json.loads((ROOT / "docs/characters/weapon-source.json").read_text(encoding="utf-8"))
pck = source.Pck()
folder = ROOT / "assets/weapons/character-starts"
folder.mkdir(parents=True, exist_ok=True)
manifest = {"version": facts["version"], "steamBuild": facts["steamBuild"], "uploadedCount": 0, "runtimeChanged": False, "weapons": []}
for weapon in facts["weapons"]:
    data = pck.resource(weapon["tiers"][0]["source"])["properties"]
    icon = data["icon"]["resource"]
    imported = pck.read(icon + ".import").decode("utf-8")
    texture = re.search(r'path="([^"]+\.stex)"', imported)[1]
    raw = pck.read(texture)
    assert raw[:4] == b"GDST", texture
    offset = raw.find(b"RIFF")
    assert offset >= 0, f"Unsupported native icon encoding: {texture}"
    image = Image.open(io.BytesIO(raw[offset:])).convert("RGBA")
    assert image.size == (96, 96), image.size
    output = folder / (weapon["id"] + ".png")
    image.save(output)
    checked = Image.open(output).convert("RGBA")
    assert checked.tobytes() == image.tobytes(), output
    manifest["weapons"].append({"id": weapon["id"], "name": weapon["name"], "source": icon, "textureSource": texture, "textureMd5": pck.entries[texture]["md5"], "output": output.relative_to(ROOT).as_posix(), "pngSha256": hashlib.sha256(output.read_bytes()).hexdigest(), "rgbaSha256": hashlib.sha256(image.tobytes()).hexdigest(), "size": list(image.size), "alphaBounds": list(image.getbbox())})
# Distinct projectile and world pictures, separate from held weapon identities.
projectiles = []
if any(w["id"] == "StickyGrenade" for w in facts["weapons"]):
    projectiles.extend([("StickyGrenadeThrown","res://projectiles/grenade_mine/grenade.png"),("StickyGrenadeGround","res://projectiles/grenade_mine/grenade_on_ground.png")])
if any(w["id"] == "Molotov" for w in facts["weapons"]):
    projectiles.append(("MolotovThrown", "res://projectiles/molotov/molotov.png"))
    for n in range(3):
        projectiles.extend([(f"FirePuddle{n}",f"res://entities/gpe/puddle/puddle_{n}.png"),(f"FirePuddleOutline{n}",f"res://entities/gpe/puddle/puddle_outline_{n}.png")])
if projectiles:
    manifest["projectiles"] = []
    for ident, icon in projectiles:
        imported = pck.read(icon + ".import").decode("utf-8")
        texture = re.search(r'path="([^"]+\.stex)"', imported)[1]
        raw = pck.read(texture)
        image = Image.open(io.BytesIO(raw[raw.index(b"RIFF"):])).convert("RGBA")
        output = folder / (ident + ".png")
        image.save(output)
        assert Image.open(output).convert("RGBA").tobytes() == image.tobytes()
        manifest["projectiles"].append({"id":ident, "source":icon, "textureSource":texture, "textureMd5":pck.entries[texture]["md5"], "output":output.relative_to(ROOT).as_posix(), "pngSha256":hashlib.sha256(output.read_bytes()).hexdigest(), "rgbaSha256":hashlib.sha256(image.tobytes()).hexdigest(), "size":list(image.size), "alphaBounds":list(image.getbbox())})
(folder / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(f"{len(manifest['weapons'])} native icons prepared; no uploads or runtime ID changes")
