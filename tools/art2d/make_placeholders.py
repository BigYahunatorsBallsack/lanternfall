"""Draws simple stand-in pictures for every sprite of tools/art2d/sprites.json that nobody has delivered yet.

They only show size, draw order and the name of the thing while the code is tested; the real pictures replace them in
assets/world2d/final. Usage: python tools/art2d/make_placeholders.py
"""
import colorsys
import json
import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
LIST = json.loads((ROOT / "tools/art2d/sprites.json").read_text("utf-8"))
OUT = ROOT / "assets/world2d/placeholder"
SIZE = 256
INK = (34, 28, 38, 255)
WIDE = {"Brute", "AbyssBrute", "Thornback", "Gobbler", "Splitter", "BroodMatron", "MireJaw", "Monolith", "Crate"}
TALL = {"Stalker", "Reaper", "Flayer", "Abbot", "SickleWraith", "HollowSeer", "Tree", "Lamp", "Beacon", "Arch", "Portal"}
FACELESS = {"BroodEgg", "Crate", "LegendaryCrate", "Chest", "Arch", "Beacon", "Lamp", "CornerRuin", "Portal"}


def color_of(name, index):
    hue = (index * 0.381966) % 1
    red, green, blue = colorsys.hsv_to_rgb(hue, 0.55, 0.85)
    return (int(red * 255), int(green * 255), int(blue * 255), 255)


def font(size):
    for path in ("C:/Windows/Fonts/arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def figure(name, color):
    image = Image.new("RGBA", (SIZE * 2, SIZE * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    half_w = 200 if name in WIDE else 120 if name in TALL else 160
    top = 40 if name in TALL else 90
    bottom = 470
    cx = SIZE
    if name in FACELESS:
        draw.rounded_rectangle([cx - half_w, top, cx + half_w, bottom], radius=30, fill=color, outline=INK, width=16)
    else:
        draw.ellipse([cx - half_w, top, cx + half_w, bottom], fill=color, outline=INK, width=16)
        eye_y = (top + bottom) // 2 - 30
        for side in (-1, 1):
            draw.ellipse([cx + side * 55 - 26, eye_y - 32, cx + side * 55 + 26, eye_y + 32], fill=(255, 255, 255, 255), outline=INK, width=8)
            draw.ellipse([cx + side * 55 - 2, eye_y - 12, cx + side * 55 + 22, eye_y + 14], fill=INK)
    label = name[:9]
    text_font = font(62)
    width = draw.textlength(label, font=text_font)
    draw.text((cx - width / 2, bottom - 110), label, font=text_font, fill=(255, 255, 255, 255), stroke_width=7, stroke_fill=INK)
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def floor(index):
    base = {"Arena": (168, 158, 132), "Lobby": (140, 136, 128)}[index]
    image = Image.new("RGBA", (SIZE, SIZE), base + (255,))
    draw = ImageDraw.Draw(image)
    dark = tuple(max(0, value - 14) for value in base) + (255,)
    for x, y, radius in ((40, 60, 7), (180, 40, 5), (120, 150, 9), (220, 210, 6), (60, 220, 5)):
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=dark)
    return image


def main():
    index = 0
    for group, info in LIST.items():
        if info.get("optional"):
            continue
        for name, item in info["items"].items():
            if item.get("existing"):
                continue
            target = OUT / group / f"{name}.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            picture = floor(name) if info.get("tile") else figure(name, color_of(name, index))
            picture.save(target)
            index += 1
    print(f"{index} placeholders in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
