"""Verify source PNG bytes, all wiki tier amounts and the uploaded artwork maps offline."""

import hashlib
import json
import re
import subprocess
from datetime import date
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/ui/stats/brotato"


def main():
    manifest = json.loads((ART / "manifest.json").read_text(encoding="utf-8"))
    uploads = json.loads((ART / "roblox-assets.json").read_text(encoding="utf-8"))
    preload = json.loads((ART / "studio-preload.json").read_text(encoding="utf-8"))
    config = (ROOT / "src/shared/Config/Stats.luau").read_text(encoding="utf-8")
    runtime = (ROOT / "src/client/UI/PrimaryStatArt.luau").read_text(encoding="utf-8")
    stat_text, upgrade_text = runtime.split("local upgrades:")
    maps = {
        "stat": dict(re.findall(r'(\w+) = "(rbxassetid://\d+)"', stat_text)),
        "upgrade": dict(re.findall(r'(\w+) = "(rbxassetid://\d+)"', upgrade_text)),
    }
    uploaded = {entry["file"]: entry for entry in uploads["entries"]}
    assert len(uploaded) == 32
    assert len({entry["assetId"] for entry in uploaded.values()}) == 32
    assert preload["ok"] and preload["count"] == 32
    assert all(result["status"] == "Success" for result in preload["results"])
    assert {result["asset"] for result in preload["results"]} == {entry["assetId"] for entry in uploaded.values()}
    report = {
        "date": date.today().isoformat(),
        "baseMain": subprocess.check_output(["git", "rev-parse", "origin/main"], cwd=ROOT, text=True).strip(),
        "source": manifest["revision"],
        "images": [],
        "upgradeAmountsChecked": 0,
        "uploadedImages": 32,
        "allImageIdsUnique": True,
        "successfulStudioPreloads": 32,
    }
    for entry in manifest["entries"]:
        stat_id = entry["id"]
        pattern = r'stat\("' + re.escape(stat_id) + r'",[^\n]*\{ ([0-9, ]+) \}'
        match = re.search(pattern, config)
        assert match, stat_id
        assert [int(value.strip()) for value in match[1].split(",")] == entry["upgradeValues"], stat_id
        report["upgradeAmountsChecked"] += 4
        for kind in ("stat", "upgrade"):
            info = entry[kind]
            path = ART / info["file"]
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            assert digest == info["sha256"] == uploaded[info["file"]]["sha256"], path
            assert maps[kind][stat_id] == uploaded[info["file"]]["assetId"], path
            assert uploaded[info["file"]]["moderation"] == "Approved", path
            with Image.open(path) as image:
                assert image.size == (96, 96) and image.format == "PNG", path
                assert image.getchannel("A").getextrema() == (0, 255), path
            report["images"].append({"file": info["file"], "sha256MatchesSource": True, "size": [96, 96], "alpha": [0, 255]})
    assert len(report["images"]) == 32 and report["upgradeAmountsChecked"] == 64
    assert all(len(mapping) == 16 for mapping in maps.values())
    (ART / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("32 original PNGs, 32 uploaded image mappings, 32 successful preloads and all 64 upgrade amounts verified")


if __name__ == "__main__":
    main()
