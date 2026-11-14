"""Compile stable weapon access facts used by character selection and shop eligibility."""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    facts = json.loads((ROOT / "docs/characters/weapon-access.json").read_text(encoding="utf-8"))
    spec = importlib.util.spec_from_file_location("character_catalog", ROOT / "tools/build-character-catalog.py")
    compiler = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(compiler)
    output = (
        "--!strict\n"
        "-- Native weapon access facts; CharacterAccess and PlayerDataService apply the original unlock conditions.\n"
        "-- Generated from docs/characters/weapon-access.json; no game scripts or artwork.\n"
        "export type Access = {\n"
        "\tfree: boolean,\n\tsource: string,\n\tsourceMd5: string,\n\tchallengeId: string?,\n"
        "\tchallengeSource: string?,\n\tchallengeSourceMd5: string?,\n\twinWith: string?,\n"
        "\tstat: string?,\n\tthreshold: number?,\n\teventChallenge: boolean?,\n"
        "\tsourceWeaponId: string?,\n\tzoneId: number?,\n\truleSource: string?,\n\truleSourceMd5: string?,\n"
        "}\n"
        "local records: { [string]: Access } = " + compiler.luau(facts["weapons"]) + "\n\n"
        "return table.freeze(records)\n"
    )
    path = ROOT / "src/shared/Config/CharacterWeaponAccess.luau"
    if args.check:
        assert path.read_text(encoding="utf-8") == output, "CharacterWeaponAccess is stale; regenerate it"
    else:
        path.write_text(output, encoding="utf-8", newline="\n")
    print(f"{len(facts['weapons'])} native weapon access records")


if __name__ == "__main__":
    main()
