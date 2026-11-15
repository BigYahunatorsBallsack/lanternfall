"""Compile source-hashed Oviraptor/Iguanodon crossing rules; actor registration is separate."""
from __future__ import annotations
import argparse
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def generate():
    source = module('crossing_source', 'tools/character-source.py')
    scenes = module('crossing_scenes', 'tools/build-character-pets.py')
    pck = source.Pck()
    reference = source.verify_reference(pck)
    movement = 'res://entities/units/movement_behaviors/go_towards_border_opposite_movement_behavior.gd'
    root_script = 'res://entities/units/enemies/jungle/basic/oviraptor/oviraptor.gd'
    families = {}
    for identity, warning in [('Oviraptor', 0.35), ('Iguanodon', 1.5)]:
        slug = identity.lower()
        path = f'res://entities/units/enemies/jungle/basic/{slug}/{slug}.tscn'
        scene = scenes.read_scene(pck, path)
        root = next(n for n in scene['nodes'] if n['parent'] is None)
        move = next(n for n in scene['nodes'] if n['name'] == 'MovementBehavior')
        assert root['scriptSource'] == root_script
        assert move['scriptSource'] == movement
        assert root['properties']['collision_mask'] == 0
        assert not root['properties']['should_collide_with_borders']
        assert move['properties']['max_Y_diff'] == 3
        assert move['properties']['warning_time'] == warning
        families[identity] = {
            'source': path, 'sourceMd5': pck.entries[path]['md5'],
            'rootScript': root_script, 'movementScript': movement,
            'warningSeconds': warning, 'maxYDiff': move['properties']['max_Y_diff'],
            'actorRegistered': False,
        }
    # Reviewed script literals; hashes below bind these semantics to the stable source.
    rules = {'initialJitterStuds': 100 / 10, 'exitOvershootStuds': 150 / 10,
             'warningShake': 1.2, 'timeoutEnablesBody': True,
             'warningArrowCalled': False, 'warningLineCalled': False,
             'genericEnemyMayEnableHiddenContact': True,
             'exitUsesDespawnNotKill': True}
    paths = [movement, root_script, 'res://singletons/zone_service.gd',
             'res://entities/units/enemies/enemy.gd',
             'res://entities/units/unit/unit.gd', 'res://overlap/hitbox.gd']
    return {
        'version': reference['version'], 'steamBuild': int(reference['steamBuildId']),
        'families': families, 'rules': rules,
        'ruleSources': [{'source': p.removesuffix('.gd') + '.gdc',
                         'sourceMd5': pck.entries[p.removesuffix('.gd') + '.gdc']['md5']} for p in paths],
        'worldConnected': False, 'worldAdapterConnected': True,
        'snapshotVisibilityConnected': True, 'rendererVisibilityConnected': True,
        'worldAdapterScope': 'World movement, shape filtering, rotated offsets, quiet removal and snapshot/renderer visibility; no registered actors or original-art acceptance.',
        'nativePresentationAccepted': False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = generate()
    compiler = module('crossing_catalog', 'tools/build-character-catalog.py')
    files = {
        ROOT / 'docs/characters/crossing-paths-source.json': json.dumps(data, indent=2) + '\n',
        ROOT / 'src/shared/Config/NativeCrossingPaths.luau':
            '--!strict\n-- Source crossing path and warning facts; NativeCrossing consumes these before actor registration.\nreturn '
            + compiler.luau(data) + '\n',
    }
    for path, text in files.items():
        if path.suffix == '.luau':
            with tempfile.TemporaryDirectory(dir=ROOT / 'build') as folder:
                temp = Path(folder) / path.name
                temp.write_text(text, encoding='utf-8')
                subprocess.run(['stylua', str(temp)], check=True)
                text = temp.read_text(encoding='utf-8')
        if args.check:
            assert path.read_text(encoding='utf-8') == text, f'Stale crossing facts: {path}'
        else:
            path.write_text(text, encoding='utf-8', newline='\n')
    print('2 crossing movement rules compiled; neither actor is registered by this compiler')


if __name__ == '__main__':
    main()
