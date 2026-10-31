"""Launch art for Lanternfall (Paket 24): 3 icon variants (512x512) and 3 thumbnails (1920x1080).

Occult art deco key art in the game's look (DESIGN.md section 14): a warm brass lantern in the middle of a soot-black
horde with glowing eyes, sunburst rays, a stepped deco frame. Pure Python + Pillow, deterministic (fixed seeds).

    python3 tools/launch/art.py            # writes assets/launch/*.png

Real in-game screenshots (capture mode, F6/F7 in Studio) usually convert better as thumbnails; these are the fallback
and the base for icon tests (Creator Hub -> experience -> Places -> Icon/Thumbnails).
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "launch"
FONT_DIR = Path("/usr/share/fonts/opentype/inter")

NIGHT_TOP = (18, 10, 34)
NIGHT_MID = (34, 16, 58)
TEAL = (20, 64, 72)
BRASS = (201, 158, 82)
BRASS_LIGHT = (245, 214, 140)
BRASS_DARK = (110, 78, 36)
AMBER = (255, 176, 64)
SOOT = (12, 8, 16)
EYE_COLORS = [(170, 90, 255), (60, 230, 210), (255, 70, 110), (120, 255, 120)]

SS = 2  # supersampling factor


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size)


def radial_gradient(size: tuple[int, int], center: tuple[float, float], inner, outer, radius: float) -> Image.Image:
    w, h = size
    small = (max(1, w // 8), max(1, h // 8))
    img = Image.new("RGB", small)
    px = img.load()
    cx, cy = center[0] / 8, center[1] / 8
    r = radius / 8
    for y in range(small[1]):
        for x in range(small[0]):
            t = min(1.0, math.hypot(x - cx, y - cy) / r)
            t = t * t * (3 - 2 * t)
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return img.resize(size, Image.BICUBIC)


def glow(size, center, radius, color, strength=1.0) -> Image.Image:
    """An additive light blob as an RGBA layer."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 40
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(255 * strength * (1 - i / steps) ** 2 * 0.35)
        d.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=color + (a,))
    return layer.filter(ImageFilter.GaussianBlur(radius / 10))


def sunburst(draw: ImageDraw.ImageDraw, center, inner, outer, rays, color, width_deg=3.2):
    cx, cy = center
    for i in range(rays):
        a = 2 * math.pi * i / rays - math.pi / 2
        half = math.radians(width_deg if i % 2 == 0 else width_deg * 0.5)
        r_out = outer if i % 2 == 0 else outer * 0.82
        pts = [
            (cx + math.cos(a - half) * inner, cy + math.sin(a - half) * inner),
            (cx + math.cos(a) * r_out, cy + math.sin(a) * r_out),
            (cx + math.cos(a + half) * inner, cy + math.sin(a + half) * inner),
        ]
        draw.polygon(pts, fill=color)


def lantern(img: Image.Image, center, scale: float):
    """Brass deco lantern: stepped cap, ring, cage with glowing core, stepped base."""
    cx, cy = center
    s = scale
    size = img.size
    img.alpha_composite(glow(size, (cx, cy + 10 * s), 260 * s, AMBER, 1.0))
    img.alpha_composite(glow(size, (cx, cy + 10 * s), 120 * s, (255, 230, 170), 1.0))
    d = ImageDraw.Draw(img)

    def rect(x0, y0, x1, y1, fill):
        d.rectangle([cx + x0 * s, cy + y0 * s, cx + x1 * s, cy + y1 * s], fill=fill)

    # handle ring
    r = 26 * s
    d.ellipse([cx - r, cy - 150 * s - r, cx + r, cy - 150 * s + r], outline=BRASS, width=int(9 * s))
    # stepped cap (deco ziggurat)
    rect(-22, -128, 22, -116, BRASS_LIGHT)
    rect(-40, -116, 40, -102, BRASS)
    rect(-58, -102, 58, -86, BRASS_DARK)
    d.polygon(
        [(cx - 70 * s, cy - 86 * s), (cx + 70 * s, cy - 86 * s), (cx + 52 * s, cy - 66 * s), (cx - 52 * s, cy - 66 * s)],
        fill=BRASS,
    )
    # glass with flame
    core = Image.new("RGBA", size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    cd.rounded_rectangle([cx - 48 * s, cy - 66 * s, cx + 48 * s, cy + 70 * s], radius=int(10 * s), fill=(255, 196, 92, 255))
    cd.ellipse([cx - 30 * s, cy - 40 * s, cx + 30 * s, cy + 50 * s], fill=(255, 238, 190, 255))
    cd.polygon([(cx, cy - 52 * s), (cx + 16 * s, cy + 6 * s), (cx - 16 * s, cy + 6 * s)], fill=(255, 255, 240, 255))
    img.alpha_composite(core.filter(ImageFilter.GaussianBlur(3 * s)))
    d = ImageDraw.Draw(img)
    # cage bars and deco chevrons
    for x in (-50, -17, 17, 50):
        rect(x - 4, -66, x + 4, 70, BRASS_DARK if abs(x) < 30 else BRASS)
    for y in (-20, 28):
        d.line([(cx - 50 * s, cy + y * s), (cx, cy + (y - 14) * s), (cx + 50 * s, cy + y * s)], fill=BRASS, width=int(5 * s))
    # base
    d.polygon(
        [(cx - 52 * s, cy + 70 * s), (cx + 52 * s, cy + 70 * s), (cx + 70 * s, cy + 90 * s), (cx - 70 * s, cy + 90 * s)],
        fill=BRASS,
    )
    rect(-58, 90, 58, 104, BRASS_DARK)
    rect(-38, 104, 38, 116, BRASS_LIGHT)


def creature(draw: ImageDraw.ImageDraw, x, y, size, eye, rng: random.Random, eyes_layer: ImageDraw.ImageDraw):
    """A soot-black Gloom silhouette: hooded blob with horns or a crown and two glowing eyes."""
    w = size
    h = size * rng.uniform(1.1, 1.5)
    kind = rng.randint(0, 2)
    draw.ellipse([x - w / 2, y - h * 0.55, x + w / 2, y + h * 0.45], fill=SOOT)
    draw.rectangle([x - w / 2, y - h * 0.05, x + w / 2, y + h * 0.5], fill=SOOT)
    if kind == 0:  # horns
        for side in (-1, 1):
            draw.polygon(
                [(x + side * w * 0.2, y - h * 0.4), (x + side * w * 0.55, y - h * 0.85), (x + side * w * 0.38, y - h * 0.3)],
                fill=SOOT,
            )
    elif kind == 1:  # hood point
        draw.polygon([(x - w * 0.35, y - h * 0.35), (x, y - h * 0.9), (x + w * 0.35, y - h * 0.35)], fill=SOOT)
    else:  # crown spikes
        for i in range(3):
            px = x + (i - 1) * w * 0.25
            draw.polygon([(px - w * 0.1, y - h * 0.45), (px, y - h * 0.75), (px + w * 0.1, y - h * 0.45)], fill=SOOT)
    er = max(2, w * 0.08)
    for side in (-1, 1):
        ex, ey = x + side * w * 0.17, y - h * 0.18
        eyes_layer.ellipse([ex - er * 2.6, ey - er * 2.6, ex + er * 2.6, ey + er * 2.6], fill=eye + (70,))
        draw.ellipse([ex - er, ey - er * 0.7, ex + er, ey + er * 0.7], fill=eye)


def horde(img: Image.Image, center, inner: float, outer: float, count: int, seed: int, size_range=(30, 70)):
    rng = random.Random(seed)
    w, h = img.size
    eyes = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ed = ImageDraw.Draw(eyes)
    body = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    spots = []
    for _ in range(count):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(inner, outer)
        x = center[0] + math.cos(a) * r * 1.25
        y = center[1] + math.sin(a) * r * 0.9
        if -60 < x < w + 60 and -60 < y < h + 80:
            spots.append((y, x, r))
    spots.sort()  # back to front
    for y, x, r in spots:
        t = (r - inner) / max(1, outer - inner)
        size = (size_range[0] + (size_range[1] - size_range[0]) * t) * SS
        creature(bd, x, y, size, rng.choice(EYE_COLORS), rng, ed)
    img.alpha_composite(eyes.filter(ImageFilter.GaussianBlur(6 * SS)))
    img.alpha_composite(body)


def deco_frame(draw: ImageDraw.ImageDraw, size, inset, color, step=18):
    w, h = size
    for k, width in ((0, 3 * SS), (10 * SS, 1 * SS)):
        i = inset + k
        draw.rectangle([i, i, w - i, h - i], outline=color, width=width)
    s = step * SS
    for cx, cy, dx, dy in ((inset, inset, 1, 1), (w - inset, inset, -1, 1), (inset, h - inset, 1, -1), (w - inset, h - inset, -1, -1)):
        for n in range(3):
            o = s * (n + 1)
            draw.line([(cx + dx * o, cy), (cx + dx * o, cy + dy * (s * (3 - n)))], fill=color, width=2 * SS)
            draw.line([(cx, cy + dy * o), (cx + dx * (s * (3 - n)), cy + dy * o)], fill=color, width=2 * SS)


def spaced_text(img: Image.Image, text: str, center_x: float, top: float, fnt, tracking: float, fill, shadow=True):
    d = ImageDraw.Draw(img)
    widths = [d.textlength(ch, font=fnt) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = center_x - total / 2
    if shadow:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        xx = x
        for ch, cw in zip(text, widths):
            sd.text((xx, top + 4 * SS), ch, font=fnt, fill=(0, 0, 0, 200))
            xx += cw + tracking
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5 * SS)))
        d = ImageDraw.Draw(img)
    for ch, cw in zip(text, widths):
        d.text((x, top), ch, font=fnt, fill=fill)
        x += cw + tracking
    return total


def background(size, light_center, vignette=True) -> Image.Image:
    w, h = size
    img = radial_gradient(size, light_center, NIGHT_MID, NIGHT_TOP, max(w, h) * 0.75).convert("RGBA")
    img.alpha_composite(glow(size, (w * 0.15, h * 0.95), w * 0.5, TEAL, 0.8))
    img.alpha_composite(glow(size, (w * 0.9, h * 0.1), w * 0.4, (90, 30, 120), 0.8))
    if vignette:
        v = Image.new("L", size, 0)
        vd = ImageDraw.Draw(v)
        vd.ellipse([-w * 0.25, -h * 0.25, w * 1.25, h * 1.25], fill=255)
        v = v.filter(ImageFilter.GaussianBlur(w // 8))
        dark = Image.new("RGBA", size, (4, 2, 8, 255))
        img = Image.composite(img, dark, v)
    return img


def embers(img: Image.Image, count: int, seed: int):
    rng = random.Random(seed)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h = img.size
    for _ in range(count):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(1.5, 4) * SS
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, rng.randint(150, 210), 90, rng.randint(120, 230)))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.2 * SS)))


def title_shade(img: Image.Image, height: float):
    """Darkens the top of the picture so the title reads over the horde."""
    w, _ = img.size
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(shade)
    steps = 30
    for i in range(steps):
        a = int(210 * (1 - i / steps))
        d.rectangle([0, height * i / steps, w, height * (i + 1) / steps], fill=(8, 4, 14, a))
    img.alpha_composite(shade)


def finish(img: Image.Image, size, path: Path):
    out = img.convert("RGB").resize(size, Image.LANCZOS)
    out.save(path, optimize=True)
    print(f"wrote {path.relative_to(ROOT)}")


def icon(variant: str):
    n = 512 * SS
    size = (n, n)
    c = (n / 2, n * 0.52)
    img = background(size, c)
    rays = Image.new("RGBA", size, (0, 0, 0, 0))
    sunburst(ImageDraw.Draw(rays), c, 150 * SS, 330 * SS, 28, BRASS + (90,))
    img.alpha_composite(rays)
    if variant == "a":  # lantern alone against the horde
        horde(img, c, 210 * SS, 330 * SS, 46, 11, (36, 64))
        lantern(img, (c[0], c[1] - 10 * SS), 1.15 * SS)
    elif variant == "b":  # with the name
        horde(img, c, 200 * SS, 320 * SS, 40, 23, (30, 56))
        lantern(img, (c[0], c[1] - 40 * SS), 0.95 * SS)
        spaced_text(img, "LANTERNFALL", n / 2, n * 0.80, font("InterDisplay-Black.otf", 52 * SS), 6 * SS, BRASS_LIGHT)
    else:  # close: one huge Gloom face behind the lantern
        d = ImageDraw.Draw(img)
        eyes = Image.new("RGBA", size, (0, 0, 0, 0))
        creature(d, n / 2, n * 0.62, 470 * SS, (170, 90, 255), random.Random(5), ImageDraw.Draw(eyes))
        img.alpha_composite(eyes.filter(ImageFilter.GaussianBlur(14 * SS)))
        lantern(img, (n / 2, n * 0.66), 0.9 * SS)
    embers(img, 40, 3)
    deco_frame(ImageDraw.Draw(img), size, 14 * SS, BRASS)
    finish(img, (512, 512), OUT / f"icon-{variant}.png")


def thumbnail(index: int):
    w, h = 1920 * SS, 1080 * SS
    size = (w, h)
    title_font = font("InterDisplay-Black.otf", 150 * SS)
    tag_font = font("InterDisplay-Bold.otf", 46 * SS)
    small_font = font("InterDisplay-SemiBold.otf", 38 * SS)
    if index == 1:  # key art: title + lantern in the horde
        c = (w * 0.5, h * 0.6)
        img = background(size, c)
        rays = Image.new("RGBA", size, (0, 0, 0, 0))
        sunburst(ImageDraw.Draw(rays), c, 200 * SS, 900 * SS, 40, BRASS + (60,), 2.2)
        img.alpha_composite(rays)
        horde(img, c, 330 * SS, 900 * SS, 140, 41, (34, 80))
        title_shade(img, h * 0.36)
        lantern(img, (c[0], c[1] + 40 * SS), 1.7 * SS)
        spaced_text(img, "LANTERNFALL", w / 2, h * 0.06, title_font, 16 * SS, BRASS_LIGHT)
        spaced_text(img, "HOLD THE LIGHT AGAINST THE GLOOM", w / 2, h * 0.22, tag_font, 8 * SS, (235, 225, 255))
    elif index == 2:  # co-op: four lanterns back to back
        c = (w * 0.5, h * 0.58)
        img = background(size, c)
        rays = Image.new("RGBA", size, (0, 0, 0, 0))
        sunburst(ImageDraw.Draw(rays), c, 260 * SS, 900 * SS, 36, BRASS + (50,), 2.0)
        img.alpha_composite(rays)
        horde(img, c, 380 * SS, 950 * SS, 170, 77, (30, 74))
        title_shade(img, h * 0.34)
        for dx, dy in ((-170, -60), (170, -60), (-90, 120), (90, 120)):
            lantern(img, (c[0] + dx * SS, c[1] + dy * SS), 0.7 * SS)
        spaced_text(img, "1–4 PLAYER CO-OP", w / 2, h * 0.07, font("InterDisplay-Black.otf", 120 * SS), 10 * SS, BRASS_LIGHT)
        spaced_text(img, "REVIVE YOUR FRIENDS • SHARE THE LIGHT", w / 2, h * 0.21, tag_font, 8 * SS, (235, 225, 255))
    else:  # content: 20 waves, boss, numbers
        c = (w * 0.7, h * 0.55)
        img = background(size, c)
        d = ImageDraw.Draw(img)
        eyes = Image.new("RGBA", size, (0, 0, 0, 0))
        creature(d, c[0], c[1] + 120 * SS, 760 * SS, (255, 70, 110), random.Random(9), ImageDraw.Draw(eyes))
        img.alpha_composite(eyes.filter(ImageFilter.GaussianBlur(20 * SS)))
        horde(img, (w * 0.45, h * 1.25), 150 * SS, 420 * SS, 45, 5, (34, 64))
        lantern(img, (w * 0.62, h * 0.72), 0.9 * SS)
        left = w * 0.26
        spaced_text(img, "20 WAVES", left, h * 0.16, font("InterDisplay-Black.otf", 130 * SS), 8 * SS, BRASS_LIGHT)
        spaced_text(img, "+ A BOSS", left, h * 0.31, font("InterDisplay-Black.otf", 130 * SS), 8 * SS, (255, 120, 140))
        lines = ["24 WEAPONS TO MERGE", "100+ ITEMS", "10 CHARACTERS • 6 DANGER LEVELS", "ENDLESS MODE"]
        for i, line in enumerate(lines):
            spaced_text(img, line, left, h * (0.52 + i * 0.075), small_font, 5 * SS, (235, 225, 255))
    embers(img, 160, index)
    deco_frame(ImageDraw.Draw(img), size, 26 * SS, BRASS, 24)
    finish(img, (1920, 1080), OUT / f"thumbnail-{index}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for variant in ("a", "b", "c"):
        icon(variant)
    for index in (1, 2, 3):
        thumbnail(index)


if __name__ == "__main__":
    main()
