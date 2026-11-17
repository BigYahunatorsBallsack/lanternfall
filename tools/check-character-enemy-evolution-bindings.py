"""Verify evolution root bindings without the pet parser's property whitelist; reads the installed reference only."""
import importlib.util, sys, unittest
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('evolution',ROOT/'tools/build-character-enemy-evolution.py')
compiler=importlib.util.module_from_spec(spec);spec.loader.exec_module(compiler)
SCENE='''[gd_scene load_steps=3 format=2]
[ext_resource path="res://effect_behaviors/scenes/evolution_scene_effect_behavior.gd" type="Script" id=1]
[ext_resource path="res://expected.tres" type="Resource" id=2]
[node name="Evolution" type="Node"]
script = ExtResource( 1 )
hp_boost_meca = 73
meca_enemy_effect_behavior_data = ExtResource( 2 )
[node name="Unrelated" type="Node" parent="."]
hp_boost_meca = 999
meca_enemy_effect_behavior_data = null
'''
class Bindings(unittest.TestCase):
 def test_root_keeps_bound_resources_and_numeric_overrides(self):
  props=compiler.root_properties(SCENE,'res://test.tscn')
  self.assertEqual(props['hp_boost_meca'],73)
  self.assertEqual(props['meca_enemy_effect_behavior_data'],{'resource':'res://expected.tres','resourceType':'Resource'})
 def test_root_without_script_is_rejected(self):
  with self.assertRaises(AssertionError):compiler.root_properties(SCENE.replace('script = ExtResource( 1 )',''),'res://test.tscn')
 def test_installed_scene_binds_both_concrete_effect_scenes(self):
  data=compiler.generate()
  self.assertEqual(set(data['behaviorData']),{'meca_enemy_effect_behavior_data','mutant_enemy_effect_behavior_data'})
  for variant in ['Meca','Mutant']:
   row=data['effects'][variant]
   self.assertEqual(row['bonusGold'],0.33)
   self.assertEqual(row['healOnKill'],1 if variant=='Mutant' else 0)
   self.assertTrue(row['scene'].endswith(variant.lower()+'_enemy_effect_behavior.tscn'))
   self.assertEqual(len(row['sourceMd5']),32)
   self.assertEqual(len(row['sceneMd5']),32)
   self.assertFalse(data['productionAdapterImplemented'])
if __name__=='__main__':unittest.main()
