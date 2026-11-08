"""Draws Lanternfall's own arena tree and arena floor tile.

Original artwork from simple shapes, in the game's look: thick near-black outline, flat colors, one darker and one
lighter tone. Writes assets/world2d/final/enemies/Tree.png (1024 px, transparent) and
assets/world2d/final/floors/Arena.png (512 px, seamless tile). tools/art2d/import_sprites.py then prepares both
for upload. Run: python tools/art2d/draw_world.py
"""

import math
import pathlib
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
FINAL = ROOT / "assets/world2d/final"
SUPER = 2  # drawn larger, then scaled down for smooth edges

OUTLINE = (18, 15, 20, 255)

# Tree: two lumpy slate-blue crowns on a thin forked trunk, dotted with glowing lime leaves.
TREE_SIZE = 1024
TREE_OUTLINE = 26  # px at 1024
CROWN = (96, 114, 146, 255)
CROWN_SHADE = (72, 84, 116, 255)
CROWN_LIGHT = (132, 152, 178, 255)
TRUNK = (58, 44, 52, 255)
LEAF = (118, 236, 92, 255)
LEAF_EDGE = (34, 118, 44, 255)
LEAF_SHINE = (214, 255, 190, 255)
LEAF_GLOW = (120, 255, 100)

# Each crown: (x, y, radius) circles on the 1024 canvas; their union is the crown.
CROWNS = [
    [(380, 390, 150), (250, 450, 105), (330, 270, 110), (470, 300, 115), (520, 420, 110), (400, 500, 120)],
    [(700, 520, 100), (790, 560, 80), (640, 590, 80), (730, 440, 80), (800, 480, 60)],
]
# Trunk and branches as (from, to, width) at 1024.
BRANCHES = [
    ((520, 940), (512, 720), 34),
    ((512, 730), (430, 520), 24),
    ((512, 730), (680, 600), 22),
    ((470, 610), (360, 560), 14),
    ((600, 660), (640, 760), 12),
    ((520, 900), (440, 950), 16),
    ((520, 900), (610, 950), 16),
    ((514, 820), (470, 765), 12),
    ((455, 600), (405, 640), 11),
]
# Leaves as (x, y, size) at 1024, mostly on the crown rims like the reference look.
LEAVES = [
    (150, 450, 34), (205, 360, 30), (250, 230, 32), (350, 165, 34), (470, 190, 30), (580, 290, 32),
    (620, 420, 30), (200, 540, 32), (300, 590, 30), (430, 380, 28), (330, 420, 26), (470, 480, 28),
    (650, 380, 30), (790, 400, 28), (870, 500, 32), (860, 610, 30), (760, 650, 30), (600, 650, 30),
    (720, 530, 26), (400, 642, 32), (465, 762, 32), (640, 770, 30),
]


def s(value):
    return round(value * SUPER)


def union_mask(circles, grow, size):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    for x, y, r in circles:
        r += grow
        draw.ellipse((s(x - r), s(y - r), s(x + r), s(y + r)), fill=255)
    return mask


def fill(image, mask, color):
    image.paste(Image.new("RGBA", image.size, color), (0, 0), mask)


def draw_branches(draw, grow, color):
    for (x0, y0), (x1, y1), width in BRANCHES:
        w = width + grow * 2
        draw.line((s(x0), s(y0), s(x1), s(y1)), fill=color, width=s(w))
        for x, y in ((x0, y0), (x1, y1)):
            r = w / 2
            draw.ellipse((s(x - r), s(y - r), s(x + r), s(y + r)), fill=color)


def leaf_shape(x, y, size, grow):
    """A small rounded leaf, a bit wider than tall and tilted by its position."""
    angle = math.radians((x * 7 + y * 3) % 60 - 30)
    rx, ry = size * 0.62 + grow, size * 0.46 + grow
    points = []
    for step in range(24):
        t = step / 24 * math.tau
        px, py = rx * math.cos(t), ry * math.sin(t)
        points.append((s(x + px * math.cos(angle) - py * math.sin(angle)), s(y + px * math.sin(angle) + py * math.cos(angle))))
    return points


def draw_tree():
    size = s(TREE_SIZE)
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Outlines first: trunk, crowns and leaves grown by the outline width, all in one dark silhouette.
    draw_branches(draw, TREE_OUTLINE / 2, OUTLINE)
    for crown in CROWNS:
        fill(image, union_mask(crown, TREE_OUTLINE, size), OUTLINE)
    for x, y, leaf in LEAVES:
        draw.polygon(leaf_shape(x, y, leaf, TREE_OUTLINE * 0.55), fill=OUTLINE)

    draw_branches(draw, 0, TRUNK)

    for crown in CROWNS:
        body = union_mask(crown, 0, size)
        fill(image, body, CROWN_SHADE)
        # Lighter upper part: the same circles moved up and shrunk, kept inside the crown.
        upper = union_mask([(x - r * 0.08, y - r * 0.16, r * 0.82) for x, y, r in crown], 0, size)
        fill(image, ImageChops.multiply(body, upper), CROWN)
        # One soft highlight on the two biggest lumps only, so the crown does not look spotted.
        biggest = sorted(crown, key=lambda c: -c[2])[:2]
        shine = union_mask([(x - r * 0.25, y - r * 0.4, r * 0.4) for x, y, r in biggest], 0, size)
        fill(image, ImageChops.multiply(body, shine), CROWN_LIGHT)

    # Soft lime glow behind the leaves.
    glow = Image.new("L", (size, size), 0)
    glow_draw = ImageDraw.Draw(glow)
    for x, y, leaf in LEAVES:
        glow_draw.polygon(leaf_shape(x, y, leaf, 10), fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(s(10)))
    silhouette = image.getchannel("A")
    glow = ImageChops.multiply(glow, silhouette)  # stays on the tree, no halo past the outline
    glow_layer = Image.new("RGBA", (size, size), LEAF_GLOW + (0,))
    glow_layer.putalpha(glow)
    image = Image.alpha_composite(image, glow_layer)
    draw = ImageDraw.Draw(image)

    for x, y, leaf in LEAVES:
        draw.polygon(leaf_shape(x, y, leaf, 4), fill=LEAF_EDGE)
        draw.polygon(leaf_shape(x, y, leaf, -2), fill=LEAF)
        r = leaf * 0.16
        cx, cy = x - leaf * 0.18, y - leaf * 0.14
        draw.ellipse((s(cx - r), s(cy - r * 0.8), s(cx + r), s(cy + r * 0.8)), fill=LEAF_SHINE)

    return image.resize((TREE_SIZE, TREE_SIZE), Image.LANCZOS)


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
    for group, name, image in (("enemies", "Tree", draw_tree()), ("floors", "Arena", draw_floor())):
        target = FINAL / group / f"{name}.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        print("wrote", target.relative_to(ROOT))


if __name__ == "__main__":
    main()
