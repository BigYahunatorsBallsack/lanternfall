"""Compile saved approved charge targeting facts; never read a newer installed PCK."""
from __future__ import annotations
import argparse
import importlib.util
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    facts = json.loads((ROOT / 'docs/characters/jungle-around-charge-source.json').read_text(encoding='utf-8'))
    base = json.loads((ROOT / 'docs/characters/jungle-walkers-source.json').read_text(encoding='utf-8'))
    ref = json.loads((ROOT / 'docs/characters/reference.json').read_text(encoding='utf-8'))
    assert facts['version'] == base['version'] == ref['version']
    assert int(facts['steamBuild']) == int(base['steamBuild']) == int(ref['steamBuildId'])
    assert any(row['source'] == facts['source'] and row['sourceMd5'] == facts['sourceMd5'] for row in base['ruleSources'])
    assert facts['animation'] == base['spawningRules']['animations'][0]
    assert facts['frameRate'] == base['spawningRules']['frameRate']
    assert facts['minimumCooldownFrames'] == base['spawningRules']['minimumCooldownFrames']
    assert facts['massMultiplier'] == base['spawningRules']['chargeMassMultiplier']
    variant = facts['variant']
    assert variant['behaviorMd5'] == facts['sourceMd5']
    assert len(variant['sourceMd5']) == 32 and all(c in '0123456789abcdef' for c in variant['sourceMd5'])
    a = variant['effective']
    assert a['target'] == 1 and a['target_calculation_timing'] == 1
    assert not a['scale_charge_duration_with_range'] and a['long_cooldown_every_x_shoots'] == 0
    assert a['attack_anim_speed'] > 0 and a['charge_duration'] > 0
    assert not facts['familyActivated']
    helper = facts['rangeHelper']
    assert helper['distanceArgumentType'] == 'int' and helper['inclusive']
    assert len(helper['sourceMd5']) == 32 and all(c in '0123456789abcdef' for c in helper['sourceMd5'])
    assert all(a[key] == -1 or a[key] >= 0 for key in ['range_X', 'range_Y', 'rand_target_size'])
    assert 0 <= a['min_range'] <= a['max_range']
    around = facts['around']
    assert around['rangeDivisor'] > 0 and around['minimumDistanceDivisor'] > 0
    size = math.trunc(min(around['maximumDefaultRadiusPoints'], a['max_range'] / around['rangeDivisor']) if a['rand_target_size'] == -1 else a['rand_target_size'])
    # Point-valued fields are converted in the emitted module using the project's authoritative scale.
    rule = {
        'cooldown': a['cooldown'] / facts['frameRate'],
        'jitter': a['max_cd_randomization'] / facts['frameRate'],
        'minimumCooldown': facts['minimumCooldownFrames'] / facts['frameRate'],
        'fireAt': facts['animation']['fireAt'] / a['attack_anim_speed'],
        'duration': a['charge_duration'], 'recovery': a['recovery_duration'],
        'massMultiplier': facts['massMultiplier'],
        'target': {'atShoot': True, 'radius': size, 'coneHalfAngle': math.radians(around['coneDegrees'] / 2),
                   'minimumRadiusShare': 1 / around['minimumDistanceDivisor'],
                   'inMovementDirection': a['only_positions_in_target_direction']},
        'speed': a['charge_speed'], 'rangeX': a['range_X'], 'rangeZ': a['range_Y'],
        'minRange': a['min_range'], 'maxRange': a['max_range'],
    }
    spec = importlib.util.spec_from_file_location('charge_target_catalog', ROOT / 'tools/build-character-catalog.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    text = '--!strict\n-- Approved saved normal Ankylosaurus charge rules for NativeStraightCharge; full actor family remains pending.\n'
    text += 'local pixel = require(script.Parent.Stats).range.studsPerPoint\nlocal source = ' + module.luau(facts)
    text += '\nlocal rule = ' + module.luau(rule)
    text += '\nrule.speed *= pixel\nrule.rangeX *= pixel\nrule.rangeZ *= pixel\nrule.minRange *= pixel\nrule.maxRange *= pixel\nrule.target.radius *= pixel\nreturn { source = source, rule = rule }\n'
    with tempfile.TemporaryDirectory(dir=ROOT / 'build') as folder:
        temp = Path(folder) / 'JungleChargeTargets.luau'
        temp.write_text(text, encoding='utf-8')
        subprocess.run(['stylua', str(temp)], check=True)
        text = temp.read_text(encoding='utf-8')
    path = ROOT / 'src/shared/Config/JungleChargeTargets.luau'
    if args.check:
        assert path.read_text(encoding='utf-8') == text, 'Stale compiled charge target snapshot'
    else:
        path.write_text(text, encoding='utf-8', newline='\n')
    print('Approved normal charge targeting compiled; full Ankylosaurus family remains pending')


if __name__ == '__main__':
    main()
