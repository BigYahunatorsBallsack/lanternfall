"""Brings finished sprites into the game. The list of every sprite is tools/art2d/sprites.json.

Takes assets/world2d/final/<group>/<Name>.png when it exists, otherwise assets/world2d/placeholder/<group>/<Name>.png.
Each picture is cut to its figure and centered on a square canvas with its feet on one line, so differently framed
pictures still fit. Groups marked `raw` (tinted pictures, icons) are only scaled, `tile` groups are floor tiles.

  python tools/art2d/import_sprites.py check            lists missing and unusable pictures
  python tools/art2d/import_sprites.py build            writes prepared pictures to build/world2d and the upload list
  python tools/art2d/import_sprites.py apply <map.json> records uploaded ids and writes Config/SpriteImages.luau
  python tools/art2d/import_sprites.py brief            writes the sprite list of docs/SPRITE-AUFTRAG.md

Uploading between build and apply: serve build/world2d (python -m http.server 34880 --directory build/world2d), upload
the urls of build/world2d/upload.txt with the Studio MCP tool upload_image and store its answer as <map.json>. Pictures
already uploaded (same content, see assets/world2d/uploaded.json) are not uploaded again.
"""
import hashlib
import json
import pathlib
import re
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
LIST = json.loads((ROOT / "tools/art2d/sprites.json").read_text("utf-8"))
FINAL = ROOT / "assets/world2d/final"
PLACEHOLDER = ROOT / "assets/world2d/placeholder"
UPLOADED = ROOT / "assets/world2d/uploaded.json"
BUILD = ROOT / "build/world2d"
OUTPUT = ROOT / "src/shared/Config/SpriteImages.luau"
BRIEF = ROOT / "docs/SPRITE-AUFTRAG.md"
BRIEF_MARK = "<!-- SPRITE-LIST -->"
PORT = 34880

MARGIN = 0.04  # share of the canvas left around a figure
ALPHA_SOLID = 40  # alpha above this counts as part of the figure
MIN_TRANSPARENT = 0.05  # share of pixels that must be see-through, else the background was not removed


def source_of(group, name):
    for folder in (FINAL, PLACEHOLDER):
        path = folder / group / f"{name}.png"
        if path.exists():
            return path
    return None


def problem_of(path, plain):
    """Why a picture cannot be used, or None. Plain pictures (tiles, raw) keep their framing."""
    image = Image.open(path)
    if image.width != image.height:
        return f"not square ({image.width}x{image.height})"
    if plain:
        return None
    if "A" not in image.convert("RGBA").getbands():
        return "no transparency"
    alpha = np.asarray(image.convert("RGBA"))[:, :, 3]
    if (alpha < ALPHA_SOLID).mean() < MIN_TRANSPARENT:
        return "background is not transparent"
    edge = np.concatenate([alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1]])
    if (edge >= ALPHA_SOLID).mean() > 0.02:
        return "figure touches the edge of the picture (cut off?)"
    return None


def prepare(path, pixels, plain):
    """Returns the prepared picture and its shares (none for plain pictures)."""
    image = Image.open(path).convert("RGBA")
    if plain:
        return image.resize((pixels, pixels), Image.LANCZOS), {}
    data = np.asarray(image)
    solid = data[:, :, 3] >= ALPHA_SOLID
    rows, cols = np.where(solid.any(axis=1))[0], np.where(solid.any(axis=0))[0]
    box = (cols[0], rows[0], cols[-1] + 1, rows[-1] + 1)
    figure = image.crop(box)
    longest = max(figure.size)
    inner = round(pixels * (1 - 2 * MARGIN))
    scale = inner / longest
    size = (max(1, round(figure.width * scale)), max(1, round(figure.height * scale)))
    figure = figure.resize(size, Image.LANCZOS)
    canvas = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    bottom = round(pixels * MARGIN)
    canvas.alpha_composite(figure, ((pixels - size[0]) // 2, pixels - bottom - size[1]))
    return canvas, {
        "pixels": pixels,
        "center": 0.5,
        "ground": round(bottom / pixels, 3),
        "width": round(size[0] / pixels, 3),
        "height": round(size[1] / pixels, 3),
    }


def main_color(image):
    """The figure's most colorful average, for its death burst."""
    data = np.asarray(image.convert("RGBA")).astype(float)
    solid = data[data[:, :, 3] >= ALPHA_SOLID][:, :3]
    if len(solid) == 0:
        return (255, 255, 255)
    saturation = solid.max(axis=1) - solid.min(axis=1)
    picked = solid[saturation >= np.percentile(saturation, 70)]
    return tuple(int(value) for value in picked.mean(axis=0))


def entries():
    """Every (group, name, pixels, plain, optional, existing) of the list."""
    for group, info in LIST.items():
        plain = info.get("tile", False) or info.get("raw", False)
        for name, item in info["items"].items():
            yield group, name, info["pixels"], plain, info.get("optional", False), item.get("existing")


def check():
    missing, bad, final, placeholder = [], [], 0, 0
    for group, name, _, plain, optional, existing in entries():
        path = source_of(group, name)
        if path is None:
            if not existing and not optional:
                missing.append(f"{group}/{name}.png")
            continue
        if path.is_relative_to(FINAL):
            final += 1
        else:
            placeholder += 1
        problem = problem_of(path, plain)
        if problem:
            bad.append(f"{path.relative_to(ROOT)}: {problem}")
    print(f"final {final}, placeholder {placeholder}, missing {len(missing)}, unusable {len(bad)}")
    for line in missing:
        print("missing:", line)
    for line in bad:
        print("unusable:", line)
    return not missing and not bad


def build():
    if not check():
        sys.exit(1)
    uploaded = json.loads(UPLOADED.read_text("utf-8")) if UPLOADED.exists() else {}
    prepared, urls = {}, []
    for group, name, pixels, plain, _, _ in entries():
        path = source_of(group, name)
        if path is None:
            continue
        image, shares = prepare(path, pixels, plain)
        relative = f"{group}/{name}.png"
        target = BUILD / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        if shares:
            shares["color"] = main_color(image)
        prepared[relative] = {"group": group, "name": name, "hash": digest, **shares}
        if digest not in uploaded:
            urls.append(f"http://localhost:{PORT}/{relative}")
    (BUILD / "prepared.json").write_text(json.dumps(prepared, indent=1), "utf-8")
    (BUILD / "upload.txt").write_text("\n".join(urls), "utf-8")
    print(f"{len(prepared)} pictures prepared, {len(urls)} to upload (build/world2d/upload.txt)")


def luau_entry(asset, record):
    if "pixels" not in record:
        return f'"{asset}"'
    fields = [f'image = "{asset}"', f"pixels = {record['pixels']}"]
    for key in ("center", "ground", "width", "height"):
        if key in record:
            fields.append(f"{key} = {record[key]}")
    if "color" in record:
        fields.append("color = {{ {}, {}, {} }}".format(*record["color"]))
    return "table.freeze({ " + ", ".join(fields) + " })"


def apply(map_path):
    uploaded = json.loads(UPLOADED.read_text("utf-8")) if UPLOADED.exists() else {}
    prepared = json.loads((BUILD / "prepared.json").read_text("utf-8"))
    for url, asset in json.loads(pathlib.Path(map_path).read_text("utf-8")).items():
        relative = re.sub(r"^https?://[^/]+/", "", url)
        if relative in prepared:
            uploaded[prepared[relative]["hash"]] = asset
    UPLOADED.parent.mkdir(parents=True, exist_ok=True)
    UPLOADED.write_text(json.dumps(uploaded, indent=1, sort_keys=True) + "\n", "utf-8")

    groups = {group: {} for group in LIST}
    for group, name, _, _, _, existing in entries():
        if existing and f"{group}/{name}.png" not in prepared:
            groups[group][name] = dict(existing, asset=existing["image"])
    missing = []
    for relative, record in prepared.items():
        asset = uploaded.get(record["hash"])
        if asset is None:
            missing.append(relative)
            continue
        groups[record["group"]][record["name"]] = dict(record, asset=asset)
    if missing:
        print("no id yet:", ", ".join(missing))
        sys.exit(1)

    lines = [
        "--!strict",
        "-- Generated by tools/art2d/import_sprites.py, do not edit: image id and figure shares of every world sprite.",
        "-- Read by Config/Sprites and the UI portraits. Shares are parts of the square picture: `ground` lies below the",
        "-- feet, `center` is the middle of the figure, `width` and `height` its size, `color` its main { red, green, blue }.",
        "return table.freeze({",
    ]
    for group in sorted(groups):
        lines.append(f"\t{group} = table.freeze({{")
        for name in sorted(groups[group]):
            lines.append(f"\t\t{name} = {luau_entry(groups[group][name]['asset'], groups[group][name])},")
        lines.append("\t}),")
    lines.append("})")
    OUTPUT.write_text("\n".join(lines) + "\n", "utf-8", newline="\n")
    print(f"wrote {OUTPUT.relative_to(ROOT)}")


def brief():
    rows = []
    for group, info in LIST.items():
        rows.append(f"\n### {info['title']}\n")
        rows.append("| Datei | Was |")
        rows.append("| --- | --- |")
        for name, item in info["items"].items():
            rows.append(f"| `assets/world2d/final/{group}/{name}.png` | {item['text']} |")
    text = BRIEF.read_text("utf-8").replace("\r\n", "\n")
    head = text.split(BRIEF_MARK)[0]
    BRIEF.write_text(head + BRIEF_MARK + "\n" + "\n".join(rows) + "\n", "utf-8", newline="\n")
    print(f"wrote {BRIEF.relative_to(ROOT)}")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    if command == "check":
        sys.exit(0 if check() else 1)
    if command == "build":
        build()
    elif command == "apply":
        apply(sys.argv[2])
    elif command == "brief":
        brief()
    else:
        print(__doc__)
