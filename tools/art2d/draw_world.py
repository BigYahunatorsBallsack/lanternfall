"""Draws Lanternfall's own arena floor tile.

Original artwork from simple shapes: dusty mauve ground with small clusters of pebbles and dry yellow bits.
Writes assets/world2d/final/floors/Arena.png (512 px, seamless tile); tools/art2d/import_sprites.py prepares it
for upload. Run: python tools/art2d/draw_world.py
"""

import math
import pathlib
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
FINAL = ROOT / "assets/world2d/final"
SUPER = 2  # drawn larger, then scaled down for smooth edges


def s(value):
    return round(value * SUPER)


# Arena floor: dusty mauve ground with small clusters of pebbles and dry yellow bits, seamless at 512 px.
FLOOR_SIZE = 512
FLOOR = (120, 99, 96)
FLOOR_DARK = (110, 90, 88)
PEBBLE = (140, 119, 116)
PEBBLE_EDGE = (86, 68, 68)
PEBBLE_LIGHT = (160, 140, 136)
BIT = (220, 194, 112)
BIT_EDGE = (104, 80, 50)
BIT_SHADOW = (100, 82, 80)
FLOOR_SEED = 4117
CLUSTERS = 7
LONE_PEBBLES = 10


def wrapped(x, y, reach):
    """Draw positions of one element, repeated across the tile edges so the tile stays seamless."""
    size = s(FLOOR_SIZE)
    for dx in (-size, 0, size):
        for dy in (-size, 0, size):
            if -reach <= x + dx <= size + reach and -reach <= y + dy <= size + reach:
                yield x + dx, y + dy


def pebble(draw, x, y, r, squash):
    reach = r * 2
    for px, py in wrapped(x, y, reach):
        draw.ellipse((px - r - s(2), py - r * squash - s(1), px + r + s(2), py + r * squash + s(3)), fill=PEBBLE_EDGE)
        draw.ellipse((px - r, py - r * squash, px + r, py + r * squash), fill=PEBBLE)
        draw.ellipse((px - r * 0.6, py - r * squash * 0.8, px + r * 0.1, py - r * squash * 0.1), fill=PEBBLE_LIGHT)


def bit(draw, rng, x, y, size):
    """A small dry yellow bit: an irregular rounded blob with a dark rim and a shadow below."""
    count = 7
    radii = [size * rng.uniform(0.55, 1.0) for _ in range(count)]
    angle = rng.uniform(0, math.tau)
    stretch = rng.uniform(1.2, 1.7)
    shape = []
    for i, radius in enumerate(radii):
        t = i / count * math.tau
        px, py = radius * stretch * math.cos(t), radius * math.sin(t)
        shape.append((px * math.cos(angle) - py * math.sin(angle), px * math.sin(angle) + py * math.cos(angle)))
    for px, py in wrapped(x, y, size * 3):
        draw.polygon([(px + a, py + b + s(4)) for a, b in shape], fill=BIT_SHADOW)
        grown = [(a * 1.0 + (s(3) if a > 0 else -s(3)), b + (s(3) if b > 0 else -s(3))) for a, b in shape]
        draw.polygon([(px + a, py + b) for a, b in grown], fill=BIT_EDGE)
        draw.polygon([(px + a, py + b) for a, b in shape], fill=BIT)


def draw_floor():
    rng = random.Random(FLOOR_SEED)
    size = s(FLOOR_SIZE)
    image = Image.new("RGB", (size, size), FLOOR)
    draw = ImageDraw.Draw(image)

    # Faint darker patches so the ground is not perfectly flat.
    patches = Image.new("L", (size, size), 0)
    patch_draw = ImageDraw.Draw(patches)
    for _ in range(9):
        x, y, r = rng.uniform(0, size), rng.uniform(0, size), s(rng.uniform(30, 70))
        for px, py in wrapped(x, y, r):
            patch_draw.ellipse((px - r, py - r * 0.7, px + r, py + r * 0.7), fill=90)
    patches = patches.filter(ImageFilter.GaussianBlur(s(18)))
    image.paste(Image.new("RGB", (size, size), FLOOR_DARK), (0, 0), patches)

    # Cluster centres spread out on a jittered grid, so no two clusters clump together.
    cells = [(i % 3, i // 3) for i in range(9)]
    rng.shuffle(cells)
    for cx, cy in cells[:CLUSTERS]:
        x = (cx + rng.uniform(0.2, 0.8)) * size / 3
        y = (cy + rng.uniform(0.2, 0.8)) * size / 3
        for _ in range(rng.randint(2, 4)):
            pebble(draw, x + s(rng.uniform(-34, 34)), y + s(rng.uniform(-28, 28)), s(rng.uniform(5, 9)), 0.75)
        for _ in range(rng.randint(1, 3)):
            bit(draw, rng, x + s(rng.uniform(-30, 30)), y + s(rng.uniform(-30, 30)), s(rng.uniform(6, 9)))
    for _ in range(LONE_PEBBLES):
        pebble(draw, rng.uniform(0, size), rng.uniform(0, size), s(rng.uniform(4, 6)), 0.75)

    return image.resize((FLOOR_SIZE, FLOOR_SIZE), Image.LANCZOS)


def main():
    for group, name, image in (("floors", "Arena", draw_floor()),):
        target = FINAL / group / f"{name}.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        print("wrote", target.relative_to(ROOT))


if __name__ == "__main__":
    main()
