"""Extract Brotato's Crash Zone wave spawn data and compile Config/EnemyWaves.luau.

Reads the owner's installed, unencrypted Brotato PCK (stable 1.2.0.1) through tools/character-source.py's
non-evaluating parser. Only numeric spawn facts are kept (timings, repeats, areas, counts, chances, danger and wave
limits); no scripts, scenes, art or audio are copied. Enemy scenes map to Lanternfall's internal enemy ids.

  python tools/build-enemy-waves.py --refresh [--pck PATH]   reread the PCK into docs/enemy-waves/source.json
  python tools/build-enemy-waves.py                           regenerate src/shared/Config/EnemyWaves.luau
  python tools/build-enemy-waves.py --check                   fail if the Luau file is out of date
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "enemy-waves" / "source.json"
OUTPUT = ROOT / "src" / "shared" / "Config" / "EnemyWaves.luau"
ZONE = "res://zones/zone_1_crash/zone_crash_data.tres"

# Brotato scene file -> Lanternfall enemy id (docs/B9C-GEGNERWERTE.md).
# Implemented Nightmare families retain their difficulty-6 gates; unimplemented families stay nil.
ENEMY_IDS = {
    "baby_alien.tscn": "Shadeling",
    "chaser.tscn": "AbyssShadeling",
    "spitter.tscn": "Spitter",
    "charger.tscn": "Charger",
    "pursuer.tscn": "Stalker",
    "bruiser.tscn": "Brute",
    "buffer.tscn": "Herald",
    "fly.tscn": "Thornback",
    "healer.tscn": "Mender",
    "looter.tscn": "Looter",
    "helmet_alien.tscn": "IronHusk",
    "fin_alien.tscn": "Splitling",
    "spawner.tscn": "Splitter",
    "junkie.tscn": "Skulker",
    "horned_bruiser.tscn": "AbyssBrute",
    "horned_charger.tscn": "HornedRusher",
    "slasher_egg.tscn": "BroodEgg",
    "slasher.tscn": "Reaper",
    "tentacle.tscn": "DreadTendril",
    "lamprey.tscn": "Hookfang",
    "evil_mob.tscn": "Gobbler",
    "tree.tscn": "Tree",
    "bloated_spawner.tscn": "BloatedSpawner",
    "dire_junkie.tscn": "DireJunkie",
    "horned_fly.tscn": "HornedFly",
    "horned_spitter.tscn": "HornedSpitter",
    "corrupted_buffer.tscn": "CorruptedBuffer",
    "infected_slasher_egg.tscn":"InfectedSlasherEgg",
    "mad_slasher.tscn":"MadSlasher",
}

GROUP_FIELDS = [
    "spawn_chance", "spawn_timing", "repeating", "repeating_interval", "reduce_repeating_interval",
    "min_repeating_interval", "area", "spawn_dist_away_from_edges", "spawn_edge_of_map",
    "spawn_edge_of_map_together", "spawn_at_player_vertically", "is_neutral", "is_boss", "is_horde", "is_loot",
    "prevent_if_elite", "prevent_if_horde", "min_difficulty", "max_difficulty", "min_wave", "max_wave",
]
# Defaults of res://zones/wave_group_data.gd for fields a resource leaves out.
GROUP_DEFAULTS = {
    "spawn_chance": 1.0, "spawn_timing": 1, "repeating": 999, "repeating_interval": 3,
    "reduce_repeating_interval": 0, "min_repeating_interval": 1, "area": -1, "spawn_dist_away_from_edges": 0,
    "spawn_edge_of_map": False, "spawn_edge_of_map_together": False, "spawn_at_player_vertically": False,
    "is_neutral": False, "is_boss": False, "is_horde": False, "is_loot": False, "prevent_if_elite": False,
    "prevent_if_horde": False, "min_difficulty": 0, "max_difficulty": 9999, "min_wave": 0, "max_wave": 9999,
}
UNIT_DEFAULTS = {"type": 1, "min_number": 1, "max_number": 1, "spawn_chance": 1.0,
                 "additional_min_distance_from_player": 0.0}


def load_pck(path: str | None):
    spec = importlib.util.spec_from_file_location("character_source", ROOT / "tools" / "character-source.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.Pck(path) if path else module.Pck()


def refresh(pck_path: str | None) -> dict:
    pck = load_pck(pck_path)
    hashes: dict[str, str] = {}

    def resource(path: str) -> dict:
        base = path.split("::", 1)[0]
        hashes[base] = pck.entries[base]["md5"]
        return pck.resource(path)

    def unit(reference) -> dict | None:
        if not isinstance(reference, dict) or "resource" not in reference:
            return None  # an empty slot in the original resource (`null`)
        props = resource(reference["resource"])["properties"]
        scene = props.get("unit_scene")
        scene_name = scene["resource"].rsplit("/", 1)[-1] if isinstance(scene, dict) else None
        data = {key: props.get(key, default) for key, default in UNIT_DEFAULTS.items()}
        data["scene"] = scene_name
        return data

    def group(reference) -> dict:
        path = reference["resource"]
        props = resource(path)["properties"]
        data = {key: props.get(key, GROUP_DEFAULTS[key]) for key in GROUP_FIELDS}
        data["source"] = path
        data["units"] = [u for u in (unit(r) for r in props.get("wave_units_data", [])) if u is not None]
        return data

    zone = resource(ZONE)["properties"]
    waves = []
    for reference in zone["waves_data"]:
        props = resource(reference["resource"])["properties"]
        waves.append({
            "source": reference["resource"],
            "wave_duration": props["wave_duration"],
            "max_enemies": props["max_enemies"],
            "groups": [group(r) for r in props["groups_data"]],
            "conditional_groups": [[group(r) for r in choice] for choice in props.get("conditional_groups_data", [])],
        })
    coop = pck.read("res://singletons/coop_service.tscn").decode("utf-8")
    coop_values = {}
    for line in coop.splitlines():
        for key in ("additional_enemies_per_coop_player", "additional_enemy_health_per_coop_player",
                    "additional_enemy_damage_per_coop_player"):
            if line.startswith(key + " = "):
                coop_values[key] = float(line.split(" = ", 1)[1])
    hashes["res://singletons/coop_service.tscn"] = pck.entries["res://singletons/coop_service.tscn"]["md5"]
    for script in ("res://zones/wave_manager.gdc", "res://global/entity_spawner.gdc", "res://singletons/zone_service.gdc",
                   "res://singletons/entity_service.gdc", "res://singletons/run_data.gdc"):
        hashes[script] = pck.entries[script]["md5"]
    pck_sha = hashlib.sha256()
    with Path(pck.path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            pck_sha.update(chunk)
    return {
        "version": "1.2.0.1",
        "pckSha256": pck_sha.hexdigest(),
        "zone": ZONE,
        "zoneSizeTiles": [zone["width"], zone["height"]],
        "tileSizePixels": 64,
        "waves": waves,
        "groupsInAllWaves": [group(r) for r in zone["groups_data_in_all_waves"]],
        "hordeGroups": [group(r) for r in zone["horde_groups"]],
        "lootAlienGroups": [group(r) for r in zone["loot_alien_groups"]],
        "coop": coop_values,
        "resources": dict(sorted(hashes.items())),
    }


def lua_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return repr(round(value, 6)).rstrip("0").rstrip(".") if value != int(value) else str(int(value))
    return str(value)


def lua_group(data: dict, indent: str) -> str:
    units = []
    for u in data["units"]:
        enemy = ENEMY_IDS.get(u["scene"])
        units.append(
            "{ enemy = %s, min = %s, max = %s, chance = %s, neutral = %s, extraDistance = %s }" % (
                f'"{enemy}"' if enemy else "nil", u["min_number"], u["max_number"], lua_value(float(u["spawn_chance"])),
                lua_value(u["type"] == 2), lua_value(float(u["additional_min_distance_from_player"])),
            )
        )
    fields = [
        f"timing = {data['spawn_timing']}", f"repeating = {data['repeating']}",
        f"interval = {data['repeating_interval']}", f"reduceInterval = {data['reduce_repeating_interval']}",
        f"minInterval = {data['min_repeating_interval']}", f"area = {data['area']}",
        f"edgeMargin = {data['spawn_dist_away_from_edges']}", f"edge = {lua_value(data['spawn_edge_of_map'])}",
        f"chance = {lua_value(float(data['spawn_chance']))}", f"loot = {lua_value(data['is_loot'])}",
        f"neutral = {lua_value(data['is_neutral'])}", f"boss = {lua_value(data['is_boss'])}",
        f"preventIfElite = {lua_value(data['prevent_if_elite'])}",
        f"preventIfHorde = {lua_value(data['prevent_if_horde'])}",
        f"minDanger = {data['min_difficulty']}", f"maxDanger = {data['max_difficulty']}",
        f"minWave = {data['min_wave']}", f"maxWave = {data['max_wave']}",
    ]
    source = data["source"].replace("res://zones/zone_1_crash/", "")
    inner = indent + "\t"
    return (
        f"{indent}group({{ -- {source}\n{inner}" + f",\n{inner}".join(fields) + f",\n{inner}units = {{\n"
        + "".join(f"{inner}\t{u},\n" for u in units) + f"{inner}}},\n{indent}}}),\n"
    )


def compile_luau(source: dict) -> str:
    for data in [g for w in source["waves"] for g in w["groups"]] + source["groupsInAllWaves"] + source["hordeGroups"]:
        if data["spawn_edge_of_map_together"] or data["spawn_at_player_vertically"]:
            raise ValueError(f"{data['source']}: edge-together spawns are not implemented")
    if any(w["conditional_groups"] for w in source["waves"]):
        raise ValueError("conditional groups are not implemented")
    width, height = source["zoneSizeTiles"]
    tile = source["tileSizePixels"]
    coop = source["coop"]
    lines = [
        "--!strict",
        "-- GENERATED by tools/build-enemy-waves.py from docs/enemy-waves/source.json; do not edit by hand.",
        "-- Brotato 1.2.0.1 Crash Zone spawn data: every wave's spawn groups, the groups of every wave (trees, Looter,",
        "-- Gobbler), the horde groups and the co-op factors. Distances and areas are Brotato pixels (Config.Run.spawn",
        "-- turns them into studs); times are seconds into the wave. Read by SpawnDirector/SpawnRules and RunSchedule.",
        "",
        "export type Unit = {",
        "\tenemy: string?, -- nil: a Nightmare-only kind without a Lanternfall counterpart (difficulty 6 groups)",
        "\tmin: number,",
        "\tmax: number,",
        "\tchance: number,",
        "\tneutral: boolean,",
        "\textraDistance: number,",
        "}",
        "",
        "export type Group = {",
        "\ttiming: number,",
        "\trepeating: number,",
        "\tinterval: number,",
        "\treduceInterval: number,",
        "\tminInterval: number,",
        "\tarea: number,",
        "\tedgeMargin: number,",
        "\tedge: boolean,",
        "\tchance: number,",
        "\tloot: boolean,",
        "\tneutral: boolean,",
        "\tboss: boolean,",
        "\tpreventIfElite: boolean,",
        "\tpreventIfHorde: boolean,",
        "\tminDanger: number,",
        "\tmaxDanger: number,",
        "\tminWave: number,",
        "\tmaxWave: number,",
        "\tunits: { Unit },",
        "}",
        "",
        "export type Wave = { durationSeconds: number, maxEnemies: number, groups: { Group } }",
        "",
        "local function group(data: any): Group",
        "\tfor _, unit in data.units do",
        "\t\ttable.freeze(unit)",
        "\tend",
        "\ttable.freeze(data.units)",
        "\treturn table.freeze(data)",
        "end",
        "",
        "local waves: { Wave } = {",
    ]
    for wave in source["waves"]:
        lines.append(f"\ttable.freeze({{ -- {wave['source'].replace('res://zones/zone_1_crash/', '')}")
        lines.append(f"\t\tdurationSeconds = {wave['wave_duration']},")
        lines.append(f"\t\tmaxEnemies = {wave['max_enemies']},")
        lines.append("\t\tgroups = table.freeze({")
        lines.append("".join(lua_group(g, "\t\t\t") for g in wave["groups"]).rstrip("\n"))
        lines.append("\t\t}),")
        lines.append("\t}),")
    lines.append("}")
    lines.append("")
    for name, key in (("allWaves", "groupsInAllWaves"), ("horde", "hordeGroups")):
        lines.append(f"local {name}: {{ Group }} = {{")
        lines.append("".join(lua_group(g, "\t") for g in source[key]).rstrip("\n"))
        lines.append("}")
        lines.append("")
    lines += [
        "return table.freeze({",
        "\twaves = table.freeze(waves),",
        "\tallWaves = table.freeze(allWaves), -- added to every wave (Tree, Looter, Gobbler)",
        "\thorde = table.freeze(horde), -- added in horde waves, filtered by minWave/maxWave",
        f"\tzoneSizePixels = table.freeze({{ {width * tile}, {height * tile} }}),",
        "\tcoop = table.freeze({",
        f"\t\tenemiesPerPlayer = {lua_value(coop['additional_enemies_per_coop_player'])},",
        f"\t\thealthPerPlayer = {lua_value(coop['additional_enemy_health_per_coop_player'])},",
        f"\t\tdamagePerPlayer = {lua_value(coop['additional_enemy_damage_per_coop_player'])},",
        "\t}),",
        "})",
        "",
    ]
    return "\n".join(lines)


def format_luau(text: str) -> str:
    """Run StyLua (repo stylua.toml) over the output so formatting the repo never changes it."""
    stylua = shutil.which("stylua") or str(Path.home() / ".cargo/bin/stylua")
    try:
        done = subprocess.run(
            [stylua, "--stdin-filepath", str(OUTPUT), "-"],
            input=text, capture_output=True, text=True, check=True, cwd=ROOT,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"stylua is needed to format {OUTPUT}: {error}")
    return done.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--pck")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.refresh:
        SOURCE.parent.mkdir(parents=True, exist_ok=True)
        SOURCE.write_text(json.dumps(refresh(args.pck), indent=1) + "\n", encoding="utf-8")
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    text = format_luau(compile_luau(source))
    if args.check:
        if OUTPUT.read_text(encoding="utf-8") != text:
            print(f"{OUTPUT} is out of date; run tools/build-enemy-waves.py", file=sys.stderr)
            return 1
        return 0
    OUTPUT.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
