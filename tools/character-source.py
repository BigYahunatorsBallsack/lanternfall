"""Extract factual character resource data from the owner's installed Brotato PCK.

This reads unencrypted Godot 3 PCK/TRES data only. It never extracts scripts,
textures, audio, scenes or other executable/art assets into the committed catalog.
Run: python tools/character-source.py [--pck PATH] [--output PATH]
Inspect a resource: python tools/character-source.py --resource res://...tres
The Pck.read and Pck.resource APIs are also usable through importlib.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_PCK = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Brotato\Brotato.pck")
TOKEN = re.compile(
    r'\s*(?:((?:"(?:\\.|[^"\\])*"))|([-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?)|([A-Za-z_][A-Za-z_0-9/]*)|([^\s]))'
)
HEADER = re.compile(r'^\[(\w+)(.*?)\]\s*$', re.S)
ATTRIBUTE = re.compile(r'(\w+)=("(?:\\.|[^"\\])*"|[^\s]+)')
VISUAL_FIELDS = {
    "icon", "item_appearances", "texture", "sprite", "sprites", "material", "animation",
    "sound", "sound_attack", "sound_hit", "sound_effect", "sound_effects", "outline",
    "shadow", "color", "rotation", "scale", "position", "offset", "z_index",
}


class ValueParser:
    """Small, non-evaluating Godot text Variant parser; unknown syntax fails closed."""

    def __init__(self, text: str):
        self.tokens = []
        cursor = 0
        while cursor < len(text):
            match = TOKEN.match(text, cursor)
            if not match:
                if text[cursor:].strip():
                    raise ValueError(f"Unsupported value syntax: {text[cursor:cursor + 80]}")
                break
            string, number, identifier, punctuation = match.groups()
            if string is not None:
                # Godot strings additionally permit escaped slash and single quotes.
                value = json.loads(string.replace("\\'", "'"))
                self.tokens.append(("string", value))
            elif number is not None:
                value = float(number) if any(c in number for c in ".eE") else int(number)
                self.tokens.append(("number", value))
            elif identifier is not None:
                self.tokens.append(("identifier", identifier))
            else:
                self.tokens.append((punctuation, punctuation))
            cursor = match.end()
        self.cursor = 0

    def peek(self, kind: str) -> bool:
        return self.cursor < len(self.tokens) and self.tokens[self.cursor][0] == kind

    def take(self, kind: str | None = None):
        if self.cursor >= len(self.tokens):
            raise ValueError("Unexpected end of Variant")
        token = self.tokens[self.cursor]
        self.cursor += 1
        if kind is not None and token[0] != kind:
            raise ValueError(f"Expected {kind}, received {token}")
        return token[1]

    def sequence(self, closing: str) -> list[Any]:
        result = []
        while not self.peek(closing):
            result.append(self.value())
            if not self.peek(closing):
                self.take(",")
        self.take(closing)
        return result

    def value(self):
        if self.peek("string") or self.peek("number"):
            return self.take()
        if self.peek("["):
            self.take("[")
            return self.sequence("]")
        if self.peek("{"):
            self.take("{")
            result = {}
            while not self.peek("}"):
                key = self.value()
                self.take(":")
                result[str(key)] = self.value()
                if not self.peek("}"):
                    self.take(",")
            self.take("}")
            return result
        name = self.take("identifier")
        if name in ("true", "false", "null"):
            return {"true": True, "false": False, "null": None}[name]
        self.take("(")
        args = self.sequence(")")
        if name in ("ExtResource", "SubResource"):
            assert len(args) == 1
            return {"reference": name, "id": str(args[0])}
        if name.startswith("Pool") and name.endswith("Array"):
            return args
        return {"variantType": name, "values": args}

    def parse(self):
        result = self.value()
        if self.cursor != len(self.tokens):
            raise ValueError(f"Trailing Variant tokens: {self.tokens[self.cursor:]}")
        return result


def parse_tres(text: str, path: str = "") -> dict[str, Any]:
    """Return parsed properties and explicit resource references without loading Godot."""
    sections = []
    current = None
    pending = []

    def flush():
        if not pending:
            return
        statement = "\n".join(pending)
        pending.clear()
        key, separator, value = statement.partition("=")
        if not separator or current is None:
            raise ValueError(f"Invalid property in {path}: {statement[:100]}")
        current["properties"][key.strip()] = ValueParser(value).parse()

    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith(";"):
            continue
        match = HEADER.match(line)
        if match:
            flush()
            attrs = {k: ValueParser(v).parse() for k, v in ATTRIBUTE.findall(match[2])}
            current = {"kind": match[1], "attributes": attrs, "properties": {}}
            sections.append(current)
        elif re.match(r"^[A-Za-z_][A-Za-z_0-9/]*\s*=", line):
            flush()
            pending.append(line)
        else:
            pending.append(line)
    flush()
    if not sections or sections[0]["kind"] != "gd_resource":
        raise ValueError(f"Not a text resource: {path}")
    external = {
        str(s["attributes"]["id"]): s["attributes"]
        for s in sections if s["kind"] == "ext_resource"
    }
    subs = {
        str(s["attributes"]["id"]): s
        for s in sections if s["kind"] == "sub_resource"
    }

    def resolve(value):
        if isinstance(value, list):
            return [resolve(v) for v in value]
        if isinstance(value, dict):
            if value.get("reference") == "ExtResource":
                target = external[value["id"]]
                return {"resource": target["path"], "resourceType": target["type"]}
            if value.get("reference") == "SubResource":
                target = subs[value["id"]]
                return {"resource": f"{path}::{value['id']}", "resourceType": target["attributes"]["type"]}
            return {k: resolve(v) for k, v in value.items()}
        return value

    root = next(s for s in sections if s["kind"] == "resource")
    return {
        "path": path,
        "resourceType": sections[0]["attributes"]["type"],
        "properties": resolve(root["properties"]),
        "subresources": {
            key: {"resourceType": s["attributes"]["type"], "properties": resolve(s["properties"])}
            for key, s in subs.items()
        },
        "externalResources": list(external.values()),
    }


class Pck:
    """Read-only unencrypted Godot 3 PCK v1 index with integrity-checked reads."""

    def __init__(self, path: Path | str = DEFAULT_PCK):
        self.path = Path(path)
        self.entries = {}
        self.cache = {}
        with self.path.open("rb") as stream:
            header = stream.read(84)
            if header[:4] != b"GDPC" or struct.unpack_from("<I", header, 4)[0] != 1:
                raise ValueError("Only unencrypted Godot PCK version 1 is supported")
            self.engine = list(struct.unpack_from("<III", header, 8))
            count = struct.unpack("<I", stream.read(4))[0]
            for _ in range(count):
                length = struct.unpack("<I", stream.read(4))[0]
                name = stream.read(length).rstrip(b"\0").decode("utf-8")
                offset, size = struct.unpack("<QQ", stream.read(16))
                digest = stream.read(16).hex()
                self.entries[name] = {"offset": offset, "size": size, "md5": digest}

    def exists(self, path: str) -> bool:
        return path in self.entries or f"{path}.remap" in self.entries

    def read(self, path: str) -> bytes:
        entry = self.entries[path]
        with self.path.open("rb") as stream:
            stream.seek(entry["offset"])
            data = stream.read(entry["size"])
        if len(data) != entry["size"] or hashlib.md5(data).hexdigest() != entry["md5"]:
            raise ValueError(f"PCK integrity mismatch: {path}")
        return data

    def resource(self, path: str) -> dict[str, Any]:
        base, _, sub = path.partition("::")
        if base not in self.cache:
            self.cache[base] = parse_tres(self.read(base).decode("utf-8"), base)
        result = self.cache[base]
        if sub:
            return {"path": path, **result["subresources"][sub]}
        return result


def verify_reference(pck: Pck) -> dict[str, Any]:
    """Reject unreviewed installed versions before any source compiler writes new facts."""
    expected = json.loads((Path(__file__).resolve().parents[1] / "docs/characters/reference.json").read_text(encoding="utf-8"))
    versions = {s.decode() for s in re.findall(rb"[ -~]{4,}", pck.read("res://singletons/progress_data.gdc")) if re.fullmatch(rb"1\.\d+\.\d+\.\d+", s)}
    version = max(versions, key=lambda value: tuple(map(int, value.split("."))))
    assert version == expected["version"], f"Installed version {version} differs from approved {expected['version']}"
    manifest = (pck.path.parent.parent.parent / "appmanifest_1942280.acf").read_text(encoding="utf-8")
    build = re.search(r'"buildid"\s*"(\d+)"', manifest).group(1)
    assert build == str(expected["steamBuildId"]), f"Installed Steam build {build} needs a source audit"
    return expected


def references(value):
    if isinstance(value, dict):
        if "resource" in value:
            yield value
        else:
            for nested in value.values():
                yield from references(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from references(nested)


def factual_properties(props):
    return {
        key: value for key, value in props.items()
        if key not in VISUAL_FIELDS
        and not any(word in key for word in ("appearance", "texture", "animation", "sound", "sprite"))
        and not any(r["resourceType"] in ("Texture", "AudioStream", "PackedScene", "Shader", "Material") for r in references(value))
    }


def generate(pck: Pck) -> dict[str, Any]:
    approved_reference = verify_reference(pck)
    resources = {}

    def include(path: str):
        if path in resources:
            return
        parsed = pck.resource(path)
        props = factual_properties(parsed["properties"])
        script = props.pop("script", None)
        base = path.split("::", 1)[0]
        data = pck.read(base)
        resources[path] = {
            "md5": pck.entries[base]["md5"],
            "sha256": hashlib.sha256(data).hexdigest(),
            "resourceType": parsed["resourceType"],
            "effectType": script["resource"] if script else None,
            "properties": props,
        }
        for reference in references(props):
            target = reference["resource"]
            if not pck.exists(target.split("::", 1)[0]):
                raise ValueError(f"Missing reference {target} from {path}")
            if reference["resourceType"] == "Resource" and target.split("::", 1)[0].endswith(".tres"):
                include(target)

    def summary(reference):
        path = reference["resource"]
        include(path)
        props = resources[path]["properties"]
        return {
            "source": path,
            "id": props.get("my_id"),
            "nameKey": props.get("name"),
            "tier": props.get("tier"),
        }

    characters = []
    candidates = [
        path for path in pck.entries
        if "/characters/" in path and path.endswith("_data.tres")
        and "/effects/" not in path and "/appearances/" not in path
    ]
    for path in sorted(candidates):
        props = pck.resource(path)["properties"]
        if not str(props.get("my_id", "")).startswith("character_"):
            continue
        include(path)
        set_name = "abyssalTerrors" if path.startswith("res://dlcs/dlc_1/") else "mainGame"
        if any(f"/{slug}/" in path for slug in (
            "veteran", "archaeologist", "droid", "time_shifter", "variant", "caveman", "arsonist",
            "mad_scientist", "poacher", "survivor",
        )):
            set_name = "primalDread"
        characters.append({
            "id": props["my_id"],
            "slug": props["my_id"].removeprefix("character_"),
            "nameKey": props["name"],
            "contentSet": set_name,
            "source": path,
            "sourceMd5": pck.entries[path]["md5"],
            "effects": props.get("effects", []),
            "startingWeapons": [summary(r) for r in props.get("starting_weapons", [])],
            "startingItems": [summary(r) for r in props.get("starting_items", [])],
            "selectionRules": {k: v for k, v in props.items() if k in (
                "unlocked_by_default", "required_item_set", "wanted_tags", "tags", "minimum_difficulty",
                "banned_item_groups", "banned_items", "banned_upgrades", "banned_meca_stats",
            )},
        })
    assert len(characters) == 74, f"Expected 74 playable characters, found {len(characters)}"
    assert len({c["id"] for c in characters}) == 74

    # These are fixed grants in addition to the selectable starting equipment lists.
    fixed = {}
    for character in characters:
        grants = []
        for reference in character["effects"]:
            effect = resources[reference["resource"]]["properties"]
            if effect.get("custom_key") in ("starting_item", "cursed_starting_item", "starting_weapon"):
                grants.append({
                    "id": effect["key"], "count": effect["value"],
                    "kind": "Weapon" if effect["custom_key"] == "starting_weapon" else "Item",
                    "cursed": effect["custom_key"] == "cursed_starting_item",
                    "effectSource": reference["resource"],
                })
                fixed[effect["key"]] = None
        character["guaranteedEquipment"] = grants
    for path in pck.entries:
        if not path.endswith(".tres") or not any(s in path for s in ("/items/", "/weapons/")):
            continue
        match = re.search(rb'^my_id\s*=\s*"([^"]+)"', pck.read(path), re.M)
        if match and match[1].decode() in fixed:
            fixed[match[1].decode()] = path
    for character in characters:
        for grant in character["guaranteedEquipment"]:
            target = fixed[grant["id"]]
            assert target, f"Missing fixed equipment {grant['id']}"
            grant.update(summary({"resource": target}))

    # Read literal metadata only; no bytecode instructions or scripts enter the output.
    version_path = "res://singletons/progress_data.gdc"
    versions = sorted({s.decode() for s in re.findall(rb"[ -~]{4,}", pck.read(version_path)) if re.fullmatch(rb"1\.\d+\.\d+\.\d+", s)})
    version = max(versions, key=lambda s: tuple(int(n) for n in s.split(".")))
    assert version == approved_reference["version"], f"Installed version changed: {versions}"
    steam_manifest = pck.path.parent.parent.parent / "appmanifest_1942280.acf"
    manifest = steam_manifest.read_text(encoding="utf-8")
    build_id = re.search(r'"buildid"\s*"(\d+)"', manifest).group(1)
    last_updated = int(re.search(r'"LastUpdated"\s*"(\d+)"', manifest).group(1))
    digest = hashlib.sha256()
    with pck.path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return {
        "schemaVersion": 1,
        "scope": "Neutral character rules, values, resource identities and starting equipment; no scripts or art assets.",
        "interpretation": {
            "startingWeapons": "Selectable starting weapon alternatives, not a grant of every listed weapon.",
            "startingItems": "Selectable starting item alternatives, not a grant of every listed item.",
            "guaranteedEquipment": "Fixed grants from starting_item, cursed_starting_item or starting_weapon effects.",
            "tiers": "Original serialized zero-based tiers: 0=I, 1=II, 2=III, 3=IV.",
            "limits": "Serialized resource facts only. Script defaults, runtime algorithms, scenes and visual fields are not reproduced.",
        },
        "provenance": {
            "source": "Owner-installed Steam copy of Brotato",
            "steamAppId": 1942280,
            "steamBuildId": build_id,
            "steamLastUpdatedUtc": datetime.fromtimestamp(last_updated, timezone.utc).isoformat(),
            "version": version,
            "versionEvidence": {"resource": version_path, "literals": versions, "method": "Highest semantic-version ASCII literal plus Steam build/update metadata; no decompilation"},
            "pckFile": pck.path.name,
            "pckSha256": digest.hexdigest(),
            "pckVersion": 1,
            "godotVersion": pck.engine,
        },
        "characterCount": len(characters),
        "characters": sorted(characters, key=lambda c: c["id"]),
        "resources": dict(sorted(resources.items())),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pck", type=Path, default=DEFAULT_PCK)
    parser.add_argument("--output", type=Path, default=Path("docs/characters/source.json"))
    parser.add_argument("--resource", help="Print one parsed TRES resource; does not regenerate the catalog")
    args = parser.parse_args()
    pck = Pck(args.pck)
    if args.resource:
        print(json.dumps(pck.resource(args.resource), indent=2, ensure_ascii=False))
        return
    catalog = generate(pck)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"Verified {catalog['characterCount']} characters and {len(catalog['resources'])} factual resources from Brotato {catalog['provenance']['version']}")


if __name__ == "__main__":
    main()
