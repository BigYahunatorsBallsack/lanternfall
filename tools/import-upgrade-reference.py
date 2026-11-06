"""Import the wiki's unchanged primary-stat and upgrade PNGs and its tier table."""

import hashlib
import io
import json
import re
import urllib.parse
import urllib.request
from datetime import date
from html.parser import HTMLParser
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/ui/stats/brotato"
SOURCE = "https://brotato.wiki.spellsandguns.com/Upgrades"
IDS = {
    "Max HP": "maxHp",
    "HP Regeneration": "hpRegen",
    "Life Steal": "lifeSteal",
    "Damage": "damage",
    "Melee Damage": "meleeDamage",
    "Ranged Damage": "rangedDamage",
    "Elemental Damage": "elementalDamage",
    "Attack Speed": "attackSpeed",
    "Crit Chance": "critChance",
    "Engineering": "engineering",
    "Range": "range",
    "Armor": "armor",
    "Dodge": "dodge",
    "Speed": "speed",
    "Luck": "luck",
    "Harvesting": "harvesting",
}


class WikiTables(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self.table = None
        self.row = None
        self.cell = None

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.table = []
            self.tables.append(self.table)
        elif tag == "tr" and self.table is not None:
            self.row = []
            self.table.append(self.row)
            self.cell = None
        elif tag in ("td", "th") and self.row is not None:
            self.cell = {"text": "", "images": []}
            self.row.append(self.cell)
        elif tag == "img" and self.cell is not None:
            self.cell["images"].append(dict(attrs)["src"])

    def handle_endtag(self, tag):
        if tag == "table":
            self.table = self.row = self.cell = None
        elif tag == "tr":
            self.row = self.cell = None
        elif tag in ("td", "th"):
            self.cell = None

    def handle_data(self, data):
        if self.cell is not None:
            self.cell["text"] += data


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Lanternfall-reference-import/1.0"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read()


def original_url(url):
    url = urllib.parse.urljoin(SOURCE, url)
    return re.sub(r"/images/thumb/(.+)/[^/]+$", r"/images/\1", url)


def save_image(url, relative):
    raw = fetch(url)
    path = DEST / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.open(io.BytesIO(raw))
    assert image.format == "PNG", url
    assert image.size == (96, 96), (url, image.size)
    assert "A" in image.getbands(), (url, image.mode)
    assert image.getchannel("A").getextrema() == (0, 255), url
    path.write_bytes(raw)  # Keep the source bytes, resolution, palette and alpha unchanged.
    return {"file": relative, "url": url, "sha256": hashlib.sha256(raw).hexdigest(), "width": 96, "height": 96}


def main():
    page = fetch(SOURCE)
    parser = WikiTables()
    parser.feed(page.decode("utf-8"))
    overview = next(t for t in parser.tables if [c["text"].strip() for c in t[0]] == ["Stat", "I", "II", "III", "IV"])
    upgrades = next(t for t in parser.tables if [c["text"].strip() for c in t[0]] == ["Stat", "Tier I", "Tier II", "Tier III", "Tier IV"])
    values = {r[0]["text"].strip(): [int(c["text"].strip()) for c in r[1:]] for r in overview[1:] if r}
    assert set(values) == set(IDS), values
    entries = []
    for row in upgrades[1:]:
        if not row:
            continue
        name = row[0]["text"].strip()
        stat_id = IDS[name]
        tier_urls = [original_url(c["images"][0]) for c in row[1:]]
        assert len(tier_urls) == 4 and len(set(tier_urls)) == 1, (name, tier_urls)
        entry = {
            "id": stat_id,
            "displayName": name,
            "upgradeValues": values[name],
            "stat": save_image(original_url(row[0]["images"][0]), f"stats/{stat_id}.png"),
            "upgrade": save_image(tier_urls[0], f"upgrades/{stat_id}.png"),
        }
        entries.append(entry)
        print(f"{stat_id}: {values[name]}, original stat + upgrade PNG", flush=True)
    assert len(entries) == 16
    manifest = {
        "source": SOURCE,
        "revision": "https://brotato.wiki.spellsandguns.com/index.php?title=Upgrades&oldid=" + re.search(r'title=Upgrades&amp;oldid=(\d+)', page.decode("utf-8")).group(1),
        "retrieved": date.today().isoformat(),
        "sourceHtmlSha256": hashlib.sha256(page).hexdigest(),
        "artwork": "Original Brotato sprites served by the wiki, unchanged; not Lanternfall original artwork.",
        "sameUpgradeImageForAllTiers": True,
        "entries": entries,
    }
    (DEST / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
