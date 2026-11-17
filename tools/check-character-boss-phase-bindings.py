"""Check boss phase extraction refuses unresolved defaults and child-node contamination."""
from __future__ import annotations
import importlib.util, sys, unittest
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
compiler=module('phase_binding_compiler','tools/build-character-boss-phases.py')
source=module('phase_binding_source','tools/character-source.py')
SCENE='''[gd_scene load_steps=2 format=2]
[ext_resource path="res://entities/units/enemies/bosses/boss_state.tscn" type="PackedScene" id=1]
[node name="Boss" type="Node2D"]
[node name="State1" parent="States" index="0" instance=ExtResource( 1 )]
hp_start = 0.4
timer_start = 30.0
[node name="AttackBehavior" parent="States/State1"]
hp_start = 0.99
timer_start = 1.0
'''
class PhaseBindings(unittest.TestCase):
    def test_child_properties_do_not_override_phase_root(self):
        self.assertEqual(compiler.phase_nodes(SCENE,'fixture.tscn',source),[{'node':'State1','hpStart':0.4,'timerStart':30.0}])
    def test_missing_threshold_requires_explicit_inheritance_review(self):
        with self.assertRaisesRegex(AssertionError,'Missing explicit phase threshold'):
            compiler.phase_nodes(SCENE.replace('timer_start = 30.0\n',''),'fixture.tscn',source)
    def test_unexpected_child_order_is_rejected(self):
        with self.assertRaisesRegex(AssertionError,'phase child order'):
            compiler.phase_nodes(SCENE.replace('index="0"','index="1"'),'fixture.tscn',source)
    def test_unexpected_packed_scene_is_rejected(self):
        with self.assertRaisesRegex(AssertionError,'Unexpected phase scene binding'):
            compiler.phase_nodes(SCENE.replace('boss_state.tscn','other_state.tscn'),'fixture.tscn',source)
if __name__=='__main__':unittest.main()
