"""Draws the few shared 2D pictures of the game: glows, orbs, bolts, the elite crown, chest, structures and lanterns.

They follow the look of the approved art: flat color, soft shading and a dark outline. White areas are tinted in the game
(ImageColor3) with the color of the object, so one picture serves every lantern or orb. Nothing is taken from other games.

Usage: python tools/art2d/generate_generic.py <output folder>
"""
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SCALE = 4
OUTLINE = (30, 26, 36, 255)


def canvas(size):
    image = Image.new("RGBA", (size * SCALE, size * SCALE), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def done(image, size):
    return image.resize((size, size), Image.LANCZOS)


def scaled(points):
    return [(x * SCALE, y * SCALE) for x, y in points]


def box(values):
    return [value * SCALE for value in values]


def white_with_alpha(alpha):
    full = np.full_like(alpha, 255)
    return Image.fromarray(np.dstack([full, full, full, alpha * 255]).astype(np.uint8), "RGBA")


def glow(size=128):
    """White with a soft fall-off: tinted for halos."""
    axis = np.linspace(-1, 1, size)
    x, y = np.meshgrid(axis, axis)
    return white_with_alpha(np.clip(1 - np.sqrt(x * x + y * y), 0, 1) ** 1.6)


def orb(size=128):
    unit = size / 128
    image, _ = canvas(size)
    margin, inner = 10 * unit, 17 * unit
    shade, shade_draw = canvas(size)
    shade_draw.ellipse(box([margin, margin, size - margin, size - margin]), fill=(150, 150, 165, 255))
    shade_draw.ellipse(box([inner - 8 * unit, inner - 12 * unit, size - inner - 10 * unit, size - inner - 14 * unit]),
                       fill=(255, 255, 255, 255))
    image.alpha_composite(shade.filter(ImageFilter.GaussianBlur(3 * SCALE * unit)))
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).ellipse(box([margin, margin, size - margin, size - margin]), fill=255)
    image.putalpha(mask)
    edge = ImageDraw.Draw(image)
    edge.ellipse(box([margin, margin, size - margin, size - margin]), outline=OUTLINE, width=int(6 * SCALE * unit))
    edge.ellipse(box([size * 0.30, size * 0.26, size * 0.46, size * 0.40]), fill=(255, 255, 255, 255))
    return done(image, size)


def bolt(size=128):
    """Points right; a long white streak with a soft edge."""
    x, y = np.meshgrid(np.linspace(-1, 1, size), np.linspace(-1, 1, size))
    body = np.clip(1 - np.sqrt((x / 0.95) ** 2 + (y / 0.3) ** 2), 0, 1) ** 0.8
    tail = np.where(x < 0, 0.45 + 0.55 * (x + 1), 1)
    return white_with_alpha(np.clip(body * tail * 1.4, 0, 1))


def crown(size=256):
    """The elite's sunburst; it turns in the game."""
    image, draw = canvas(size)
    center = size / 2
    points = []
    for index in range(24):
        angle = index * math.pi / 12
        radius = size * (0.47 if index % 2 == 0 else 0.24)
        points.append((center + math.cos(angle) * radius, center + math.sin(angle) * radius))
    draw.polygon(scaled(points), fill=(255, 255, 255, 235))
    draw.line(scaled(points + points[:1]), fill=OUTLINE, width=4 * SCALE, joint="curve")
    hole = size * 0.13
    draw.ellipse(box([center - hole, center - hole, center + hole, center + hole]), fill=(0, 0, 0, 0))
    return done(image, size)


def chest(size=256):
    image, draw = canvas(size)
    wood, wood_dark, gold = (132, 80, 36, 255), (92, 54, 26, 255), (255, 196, 87, 255)
    draw.rounded_rectangle(box([26, 92, 230, 228]), radius=14 * SCALE, fill=wood, outline=OUTLINE, width=7 * SCALE)
    draw.rounded_rectangle(box([26, 50, 230, 128]), radius=26 * SCALE, fill=wood_dark, outline=OUTLINE, width=7 * SCALE)
    draw.rectangle(box([24, 112, 232, 140]), fill=gold, outline=OUTLINE, width=5 * SCALE)
    draw.rounded_rectangle(box([108, 98, 148, 158]), radius=8 * SCALE, fill=gold, outline=OUTLINE, width=5 * SCALE)
    return done(image, size)


def beam(size=128):
    """A soft upright column of light."""
    x, y = np.meshgrid(np.linspace(-1, 1, size), np.linspace(0, 1, size))
    return white_with_alpha(np.clip(1 - np.abs(x) * 1.15, 0, 1) ** 1.3 * (0.15 + 0.85 * y))


def plinth(size=256):
    """The stone foot of sentries and gardens; the top part is a separate tinted picture."""
    image, draw = canvas(size)
    draw.ellipse(box([34, 176, 222, 244]), fill=(62, 52, 42, 255), outline=OUTLINE, width=7 * SCALE)
    draw.rectangle(box([44, 140, 212, 210]), fill=(86, 73, 57, 255))
    draw.line(box([44, 140, 44, 210]), fill=OUTLINE, width=7 * SCALE)
    draw.line(box([212, 140, 212, 210]), fill=OUTLINE, width=7 * SCALE)
    draw.ellipse(box([40, 108, 216, 172]), fill=(112, 96, 76, 255), outline=OUTLINE, width=7 * SCALE)
    return done(image, size)


def structure_block(size=256):
    """A tinted block (mines and gardens) with outline and a darker lower half."""
    image, draw = canvas(size)
    draw.rounded_rectangle(box([48, 48, 208, 208]), radius=20 * SCALE, fill=(255, 255, 255, 255), outline=OUTLINE,
                           width=8 * SCALE)
    draw.rounded_rectangle(box([56, 138, 200, 200]), radius=14 * SCALE, fill=(196, 196, 208, 255))
    return done(image, size)


def corner_ruin(size=512):
    """The lobby's corner tower seen from the game camera: stone block, brass cap (colors of Config/LobbyArt)."""
    image, draw = canvas(size)
    stone, top, brass = (91, 83, 77, 255), (145, 132, 115, 255), (111, 78, 45, 255)
    width = 9 * SCALE
    draw.rectangle(box([70, 170, 442, 490]), fill=stone, outline=OUTLINE, width=width)
    draw.rectangle(box([56, 76, 456, 190]), fill=top, outline=OUTLINE, width=width)
    draw.rectangle(box([56, 176, 456, 214]), fill=brass, outline=OUTLINE, width=width)
    for x0, y0, x1, y1 in ((120, 260, 230, 330), (280, 340, 400, 420), (110, 400, 190, 460)):
        draw.rectangle(box([x0, y0, x1, y1]), outline=(70, 64, 60, 255), width=5 * SCALE)
    return done(image, size)


def lantern(shape, part, size=256):
    """The three lantern shapes from the front; frame and core are separate so each lantern tints its own colors."""
    image, draw = canvas(size)
    cx = size / 2
    white = (255, 255, 255, 255)
    width = 7 * SCALE

    def rect(x0, y0, x1, y1, radius=6):
        draw.rounded_rectangle(box([x0, y0, x1, y1]), radius=radius * SCALE, fill=white, outline=OUTLINE, width=width)

    if part == "Glow":
        if shape == "Cage":
            draw.ellipse(box([cx - 50, 78, cx + 50, 178]), fill=white, outline=OUTLINE, width=width)
        elif shape == "Orb":
            draw.ellipse(box([cx - 68, 60, cx + 68, 196]), fill=white, outline=OUTLINE, width=width)
        else:
            rect(cx - 36, 56, cx + 36, 204, radius=14)
    elif shape == "Cage":
        rect(cx - 62, 204, cx + 62, 230)
        rect(cx - 52, 40, cx + 52, 64)
        rect(cx - 18, 14, cx + 18, 42)
        for side in (-1, 1):
            rect(cx + side * 56 - 7, 60, cx + side * 56 + 7, 208, radius=2)
    elif shape == "Orb":
        rect(cx - 36, 28, cx + 36, 56)
        rect(cx - 36, 200, cx + 36, 228)
        for side in (-1, 1):
            rect(cx + side * 74 - 13, 115, cx + side * 74 + 13, 141)
    else:
        rect(cx - 56, 206, cx + 56, 240)
        points = [(cx, 2), (cx + 28, 34), (cx, 66), (cx - 28, 34)]
        draw.polygon(scaled(points), fill=white)
        draw.line(scaled(points + points[:1]), fill=OUTLINE, width=width, joint="curve")
        for side in (-1, 1):
            rect(cx + side * 48 - 7, 60, cx + side * 48 + 7, 210, radius=2)
    return done(image, size)


def main():
    output = pathlib.Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)
    pictures = {
        "glow": glow(),
        "orb": orb(),
        "bolt": bolt(),
        "crown": crown(),
        "chest": chest(),
        "beam": beam(),
        "plinth": plinth(),
        "structureBall": orb(256),
        "structureBlock": structure_block(),
        "cornerRuin": corner_ruin(),
    }
    for shape in ("Cage", "Orb", "Spire"):
        for part in ("Frame", "Glow"):
            pictures[f"lantern{shape}{part}"] = lantern(shape, part)
    for name, image in pictures.items():
        image.save(output / f"{name}.png")
    print(sorted(pictures))


if __name__ == "__main__":
    main()
