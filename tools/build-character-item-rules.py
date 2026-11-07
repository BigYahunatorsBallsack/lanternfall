"""Compile stable native item identities and character ban groups, without scripts or artwork."""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    facts = json.loads((ROOT / "docs/characters/item-groups.json").read_text(encoding="utf-8"))
    spec = importlib.util.spec_from_file_location("character_catalog", ROOT / "tools/build-character-catalog.py")
    compiler = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(compiler)
    groups = facts["groups"]
    aliases = {runtime: record["nativeId"] for runtime, record in facts["runtimeItems"].items()}
    output = (
        "--!strict\n"
        "-- Stable native item identities/ban groups; ShopRules filters shop and crate pools with these facts.\n"
        "-- Generated from docs/characters/item-groups.json; original scripts and artwork are not included.\n"
        "local groups: { [string]: { string } } = " + compiler.luau(groups) + "\n\n"
        "local nativeIds: { [string]: string } = " + compiler.luau(aliases) + "\n\n"
        "return table.freeze({\n\tgroups = groups,\n\tnativeIds = nativeIds,\n\tendlessBannedItems = "
        + compiler.luau(facts["endlessBannedItems"], 1) + ",\n})\n"
    )
    path = ROOT / "src/shared/Config/CharacterItemRules.luau"
    if args.check:
        assert path.read_text(encoding="utf-8") == output, "CharacterItemRules is stale; regenerate it"
    else:
        path.write_text(output, encoding="utf-8", newline="\n")
    print(f"{len(groups)} native groups; {len(aliases)} verified runtime item identities")


if __name__ == "__main__":
    main()
