"""Measures where the egg body sits inside each approved character sprite (assets/characters-r15/*/reference.png).

The sprites are already transparent and are used unchanged. The printed shares go into Config/Sprites.luau:
center = horizontal middle of the body, ground = empty share below the body, height = body height share.

Usage: python tools/art2d/character_bounds.py
"""
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
for folder in sorted(path for path in (ROOT / "assets" / "characters-r15").iterdir() if path.is_dir()):
    alpha = np.asarray(Image.open(folder / "reference.png"))[:, :, 3] > 128
    size = alpha.shape[0]
    best_width, center = 0, size / 2
    for row in range(size):
        solid = np.concatenate([[0], alpha[row].astype(np.int8), [0]])
        changes = np.diff(solid)
        for start, stop in zip(np.where(changes == 1)[0], np.where(changes == -1)[0]):
            if stop - start > best_width:
                best_width, center = stop - start, (start + stop - 1) / 2
    column = np.where(alpha[:, int(center)])[0]
    top, bottom = column[0], column[-1]
    print(
        f"{folder.name} = {{ center = {center / size:.3f}, ground = {1 - (bottom + 1) / size:.3f}, "
        f"height = {(bottom - top + 1) / size:.3f} }},"
    )
