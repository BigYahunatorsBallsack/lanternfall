"""Draws Lanternfall's own shard (material) drop variants as 256 px PNGs into assets/loot/shards/.

Original artwork, generated from simple polygons: thick dark outline, green body, darker lower facet and a light
highlight. Run: python tools/art2d/draw_shards.py
"""

import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/loot/shards"
SIZE = 256
SUPER = 4  # drawn larger, then scaled down for smooth edges
OUTLINE = (24, 32, 22, 255)
BODY = (92, 206, 96, 255)
SHADE = (52, 150, 66, 255)
LIGHT = (196, 255, 176, 255)
OUTLINE_WIDTH = 22  # px at 256

# Each shard: body polygon, shaded facet polygon, highlight polygon. Coordinates on a 0..256 canvas.
SHARDS = {
    "Shard1": {  # chunky gem, five sides
        "body": [(70, 104), (128, 58), (190, 92), (180, 170), (104, 196)],
        "shade": [(104, 196), (180, 170), (190, 92), (150, 140)],
        "light": [(92, 108), (128, 80), (140, 92), (104, 124)],
    },
    "Shard2": {  # long sliver
        "body": [(62, 170), (170, 62), (200, 82), (96, 196)],
        "shade": [(96, 196), (200, 82), (186, 74), (88, 178)],
        "light": [(84, 162), (166, 80), (174, 86), (92, 170)],
    },
    "Shard3": {  # triangle splinter
        "body": [(66, 186), (136, 56), (196, 180)],
        "shade": [(66, 186), (196, 180), (140, 150)],
        "light": [(112, 132), (134, 88), (142, 104), (120, 142)],
    },
    "Shard4": {  # broken square chip
        "body": [(74, 84), (170, 70), (186, 150), (150, 192), (82, 176)],
        "shade": [(82, 176), (150, 192), (186, 150), (130, 156)],
        "light": [(92, 98), (150, 90), (146, 104), (98, 112)],
    },
    "Shard5": {  # diamond with a cut tip
        "body": [(128, 52), (190, 118), (156, 200), (98, 200), (66, 118)],
        "shade": [(98, 200), (156, 200), (190, 118), (128, 160)],
        "light": [(112, 88), (128, 70), (136, 80), (118, 108)],
    },
    "Shard6": {  # small double splinter
        "body": [(60, 150), (118, 70), (148, 96), (196, 84), (176, 178), (110, 196)],
        "shade": [(110, 196), (176, 178), (196, 84), (150, 150)],
        "light": [(84, 144), (116, 96), (124, 104), (94, 150)],
    },
}


def scaled(points):
    return [(x * SUPER, y * SUPER) for x, y in points]


def draw(spec):
    big = Image.new("RGBA", (SIZE * SUPER, SIZE * SUPER), (0, 0, 0, 0))
    pen = ImageDraw.Draw(big)
    body = scaled(spec["body"])
    width = OUTLINE_WIDTH * SUPER
    # Outline: the body polygon stroked thickly, with round joints.
    pen.polygon(body, fill=OUTLINE)
    pen.line(body + [body[0]], fill=OUTLINE, width=width, joint="curve")
    for x, y in body:
        r = width / 2
        pen.ellipse((x - r, y - r, x + r, y + r), fill=OUTLINE)
    pen.polygon(body, fill=BODY)
    pen.polygon(scaled(spec["shade"]), fill=SHADE)
    pen.polygon(scaled(spec["light"]), fill=LIGHT)
    return big.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in SHARDS.items():
        draw(spec).save(OUT / f"{name}.png")
        print("wrote", (OUT / f"{name}.png").relative_to(ROOT))


if __name__ == "__main__":
    main()
