"""Check item PNGs against their provenance manifest; run from the repository root."""
import hashlib
import json
import struct
from pathlib import Path


def main():
    catalog = json.loads(Path("docs/item-parity/catalog.json").read_text(encoding="utf-8"))
    manifest = json.loads(Path("assets/ui/items/manifest.json").read_text(encoding="utf-8"))
    expected = {row["id"]: row for row in catalog["items"]}
    observed = {}
    for row in manifest["items"]:
        item_id = row["id"]
        assert item_id not in observed, f"Duplicate image id: {item_id}"
        assert row["name"] == expected[item_id]["name"], item_id
        path = Path(row["file"])
        assert path == Path("assets/ui/items") / f"{item_id}.png", path
        data = path.read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n", path
        width, height = struct.unpack(">II", data[16:24])
        assert (width, height) == (row["width"], row["height"]), path
        assert len(data) == row["bytes"], path
        assert hashlib.sha256(data).hexdigest() == row["sha256"], path
        observed[item_id] = row
    assert expected.keys() == observed.keys(), "Missing or unexpected item images"
    files = {p.stem for p in Path("assets/ui/items").glob("*.png")}
    assert files == expected.keys(), "Orphaned or missing PNG files"
    print(f"Verified {len(observed)} item PNGs: names, dimensions, bytes and SHA-256.")


if __name__ == "__main__":
    main()
