"""Download the owner's requested original base-game weapon PNGs; keep exact source bytes."""
import hashlib
import json
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/weapons/brotato-base"
catalog = json.loads((OUT / "catalog.json").read_text(encoding="utf-8"))["weapons"]
(OUT / "sprites").mkdir(exist_ok=True)

def fetch(weapon):
    path = OUT / "sprites" / (weapon["id"] + ".png")
    if not path.exists():
        request = urllib.request.Request(weapon["imageUrl"], headers={"User-Agent": "LanternfallPrivateWeaponImport/1.0"})
        path.write_bytes(urllib.request.urlopen(request, timeout=30).read())
    with Image.open(path) as im:
        im.verify()
    with Image.open(path) as im:
        alpha = im.convert("RGBA").getchannel("A")
        assert alpha.getextrema()[0] == 0, weapon["name"]
        return {"id": weapon["id"], "name": weapon["name"], "source": weapon["imageUrl"],
                "file": "sprites/" + path.name, "size": list(im.size),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "transparent": True}

with ThreadPoolExecutor(max_workers=6) as pool:
    assets = list(pool.map(fetch, catalog))
(OUT / "sprites.json").write_bytes((json.dumps({"originalArt": "Brotato / Blobfish", "retrieved": "2026-11-06",
    "usage": "Owner-requested private game prototype", "assets": assets}, indent=2)+"\n").encode())

# Review sheet only. The source PNGs above are never resampled or redrawn.
cols, cell_w, cell_h = 8, 180, 160
sheet = Image.new("RGB", (cols*cell_w, ((len(assets)+cols-1)//cols)*cell_h), "#23262d")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 13)
for index, asset in enumerate(assets):
    x,y = index%cols*cell_w,index//cols*cell_h
    with Image.open(OUT/asset["file"]) as im:
        im = im.convert("RGBA")
        sheet.paste(im,(x+(cell_w-im.width)//2,y+8),im)
    draw.text((x+8,y+112),asset["name"],fill="#eeeeee",font=font)
sheet.save(OUT/"contact-sheet.jpg",quality=95)
print(f"Verified {len(assets)} original transparent PNGs; sizes: {sorted(set(tuple(a['size']) for a in assets))}")
