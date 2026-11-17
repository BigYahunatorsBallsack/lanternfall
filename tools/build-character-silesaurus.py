"""Compile the concrete normal Silesaurus source bindings; never inherit one child phase from another."""
from __future__ import annotations
import argparse,importlib.util,json,subprocess,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def generate():
    source=module('sile_source','tools/character-source.py');scene=module('sile_scene','tools/build-character-pets.py');art=module('sile_art','tools/prepare-character-jungle-art.py');phases=module('sile_phases','tools/build-character-boss-phases.py')
    pck=source.Pck();reference=source.verify_reference(pck)
    facts=json.loads((ROOT/'docs/characters/boss-phases-source.json').read_text(encoding='utf-8'));actor=facts['actors']['Silesaurus'];path=actor['source'];raw=pck.read(path).decode()
    assert facts['version']==reference['version'] and facts['steamBuild']==int(reference['steamBuildId'])
    assert pck.entries[path]['md5']==actor['sourceMd5']=='7c0b1ed5c7b0596267d328dde443ac4b'
    hashes={'res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.gdc':'3dc7ae8b914cefbc9cc1c0174cbda70c',
        'res://entities/units/enemies/attack_behaviors/spawning_attack_behavior.gdc':'cbddd1b76bf3363315729d319a34798d',
        'res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gdc':'43d5ebd849396509ff38632915c988a2',
        'res://entities/units/movement_behaviors/target_rand_pos_around_player_movement_behavior.gdc':'faa12faf0ccf2d3d86cc56d8dee2f21f',
        'res://entities/units/movement_behaviors/movement_behavior.gdc':'545124c6bbc946d5a542876cd568078b'}
    for p,h in hashes.items():assert pck.entries[p]['md5']==h,'Re-audit changed Silesaurus rules: '+p
    for row in facts['ruleSources']:assert pck.entries[row['source']]['md5']==row['sourceMd5']
    def node(name,parent):return phases.node_properties(raw,path,source,name,parent)
    root=node('AttackBehavior','.')
    assert root['script']['resource']=='res://entities/units/enemies/attack_behaviors/spawning_attack_behavior.gd'
    assert root['max_nb_of_spawns']==-1 and root['spawn_random_pos_area']==-1 and not root['spawn_at_random_pos'] and not root['spawn_at_player_range']
    assert root['spawn_in_radius_around_unit']==600
    assert root['enemy_to_spawn']['resource']=='res://entities/units/enemies/jungle/basic/enigmacursor/enigmacursor.tscn'
    basePath='res://entities/units/enemies/bosses/boss_state.tscn';baseRaw=pck.read(basePath).decode()
    base=phases.node_properties(baseRaw,basePath,source,'AttackBehavior','.')
    assert base['script']['resource']=='res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd'
    # Defaults audited in the pinned shooting script, applied separately to each independent PackedScene.
    defaults={'cooldown':60,'max_cd_randomization':10,'initial_cooldown':0,'long_cooldown_every_x_shoots':0,'long_cooldown':0,'attack_anim_speed':1,'min_range':0,'max_range':500,'damage':1,'damage_increase_each_wave':1,'number_projectiles':1,'projectile_spread':0,'constant_spread':False,'projectile_spawn_spread':0,'speed_change_after_each_projectile':0,'shoot_from_proj_pos_towards_player':False,'random_rotation':0,'use_transform_offset':False,'projectile_speed_randomization':0,'move_locked':False,'recovery_cooldown':0,'projectile_spawn_only_on_borders':False,'spawn_projectiles_on_target':False}
    attacks=[]
    for parent in ['States/State1','States/State2']:
        overrides=node('AttackBehavior',parent)
        assert 'script' not in overrides and 'projectile_scene' not in overrides and 'projectile_scene' not in base
        props={**defaults,**base,**overrides}
        assert props['damage_increase_each_wave']==1.15 and props['damage']==1
        assert not any(props[k] for k in ['move_locked','recovery_cooldown','projectile_speed_randomization','projectile_spawn_only_on_borders','spawn_projectiles_on_target'])
        attacks.append(props)
    movements=[]
    for parent in ['.','States/State1','States/State2']:
        m=node('MovementBehavior',parent)
        assert m['script']['resource']=='res://entities/units/movement_behaviors/target_rand_pos_around_player_movement_behavior.gd' and m['range_randomization']==0
        movements.append({k:v for k,v in m.items() if isinstance(v,(int,float,bool))})
    cache,chain={},[]
    def resolve(p):
        d=scene.read_scene(pck,p);cache[p]=d;chain.append(p)
        nodes=resolve(d['baseScene']) if d.get('baseScene') else {}
        nodes={k:{'properties':dict(v['properties']),'scriptSource':v.get('scriptSource')} for k,v in nodes.items()}
        for n in d['nodes']:
            key=(n['parent'] or '@',n['name'] if n['parent'] else '@');before=nodes.get(key,{})
            nodes[key]={'scriptSource':n.get('scriptSource') or before.get('scriptSource'),'properties':{**before.get('properties',{}),**n['properties']}}
        return nodes
    nodes=resolve(path);r=nodes[('@','@')]['properties'];assert r['can_be_boosted'] is False
    def circle(nodes,parent):
        p=nodes[(parent,'Collision')]['properties'];file,ident=p['shape']['resource'].split('::');shape=cache[file]['shapes'][ident];assert shape['resourceType']=='CircleShape2D'
        offset=p.get('position',{}).get('values',[0,0])
        if parent!='.':
            pp=nodes[('.',parent)]['properties'];assert pp.get('scale',{}).get('values',[1,1])==[1,1]
            offset=[a+b for a,b in zip(offset,pp.get('position',{}).get('values',[0,0]))]
        return {'radiusPoints':shape['properties']['radius'],'offsetPoints':offset}
    body,hurt,hit=circle(nodes,'.'),circle(nodes,'Hurtbox'),circle(nodes,'Hitbox')
    statsPath=r['stats']['resource'];stats={k:v for k,v in pck.resource(statsPath)['properties'].items() if isinstance(v,(int,float,bool))}
    bulletPath='res://projectiles/bullet_enemy/enemy_projectile.tscn';bullet=circle(resolve(bulletPath),'Hitbox')
    return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'source':path,'sourceMd5':actor['sourceMd5'],
        'ruleSources':[{'source':p,'sourceMd5':h} for p,h in hashes.items()],
        'sceneChain':[{'source':p,'sourceMd5':pck.entries[p]['md5']} for p in chain],
        'phaseBaseScene':basePath,'phaseBaseSceneMd5':pck.entries[basePath]['md5'],
        'statsSource':statsPath,'statsMd5':pck.entries[statsPath]['md5'],'stats':stats,'body':body,'hurt':hurt,'hit':hit,
        'mass':r.get('mass',1),'bodyLayer':r['collision_layer'],'bodyMask':r['collision_mask'],'bodyBorders':r.get('should_collide_with_borders',True),
        'sprite':art.texture_metadata(pck,art.body_texture(pck,path)),'movements':movements,
        'spawn':{'source':root['enemy_to_spawn']['resource'],'count':root['nb_to_spawn'],'minimumCount':1,'areaPoints':root['spawn_in_radius_around_unit'],'properties':{k:v for k,v in root.items() if isinstance(v,(int,float,bool))}},
        'shooting':attacks,'bullet':{'source':bulletPath,'sourceMd5':pck.entries[bulletPath]['md5'],**bullet},
        'speedReset':{'sourceChildIndex':1,'percent':75},'normalActorRegistered':True,'evolutionProfilesImplemented':False,'nativeFullParityAccepted':False}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();data=generate();catalog=module('sile_catalog','tools/build-character-catalog.py')
    text='--!strict\n-- Concrete normal Silesaurus source rules; independent child attacks, square summons and original second-child speed reset.\nlocal POINT=require(script.Parent.Stats).range.studsPerPoint\nlocal C=require(script.Parent.NativeBossPhases)\nlocal J=require(script.Parent.JungleWalkers)\nlocal data='+catalog.luau(data)+'''
local clock=C.shootingClockRules
local spawn=data.spawn.properties
data.shootingRules={frameRate=clock.frameRate,minimumCooldownFrames=clock.minimumCooldownFrames,
 fireAt=clock.animationFireAt,animationSeconds=clock.animationSeconds,
 profiles={{cooldown=spawn.cooldown,randomization=spawn.max_cd_randomization,initial=0,longEvery=0,longFrames=0,
 animationSpeed=spawn.attack_anim_speed,minRange=0,maxRange=0,unrestricted=true}}}
data.volleys={}
for index,a in data.shooting do
 table.insert(data.shootingRules.profiles,{cooldown=a.cooldown,randomization=a.max_cd_randomization,initial=a.initial_cooldown,
 longEvery=a.long_cooldown_every_x_shoots,longFrames=a.long_cooldown,animationSpeed=a.attack_anim_speed,
 minRange=a.min_range*POINT,maxRange=a.max_range*POINT})
 data.volleys[index]={count=a.number_projectiles,spread=a.projectile_spread,constantSpread=a.constant_spread,
 offsetX=a.position.values[1]*POINT,offsetZ=a.position.values[2]*POINT,speedStep=a.speed_change_after_each_projectile*POINT,
 spawnSquare=a.projectile_spawn_spread*POINT,baseAimFromSpawn=true,
 aimFromSpawn=if a.shoot_from_proj_pos_towards_player then {targetRotation=a.random_rotation} else nil}
end
local init=require(script.Parent.NativeTherizinosaurus).bossInit
data.controller={family='Silesaurus',shooting=data.shootingRules,phases=C.actors.Silesaurus,init=init,
 projectileDamage=data.shooting[1].damage,projectileRange=J.shootingRules.projectileRangeStuds,
 projectileRadius=data.bullet.radiusPoints*POINT,
 attacks={{kind='Spawn',summon={enemy='Enigmacursor',count=data.spawn.count,area=data.spawn.areaPoints*POINT},minimumCount=data.spawn.minimumCount}},
 movements={},speedReset={profile=data.speedReset.sourceChildIndex+2,percent=data.speedReset.percent}}
for index,a in data.shooting do
 table.insert(data.controller.attacks,{kind='Bullet',speed=a.projectile_speed*POINT,volley=data.volleys[index]})
end
for index,m in data.movements do
 data.controller.movements[index]={around='Target',range=m.range_around_player*POINT,rangeJitter=0,
 arriveStuds=J.spawningRules.goalPrecisionPoints*POINT,
 maxSeconds=if m.update_every_x_frames==-1 then math.huge else m.update_every_x_frames/clock.frameRate}
end
local s=data.stats
data.kind={id='Silesaurus',typeId=73,displayName='Silesaurus',look='Brute',nativeArtPending=true,
 nativeZoneId=J.zoneId,nativeScene=data.source,specialSpawn=true,nativeBoss=data.controller,wander=data.controller.movements[1],
 hp=s.health,hpPerWave=s.health_increase_each_wave,contactDamage=s.damage,damagePerWave=s.damage_increase_each_wave,
 speed=s.speed*POINT,nativeSpeedPoints={base=s.speed,randomization=s.speed_randomization},xp=s.value,
 shotDamagePerWave=data.shooting[1].damage_increase_each_wave,
 radius=data.body.radiusPoints*POINT,hurtRadius=data.hurt.radiusPoints*POINT,hitRadius=data.hit.radiusPoints*POINT,
 nativeBodyOffsetX=data.body.offsetPoints[1]*POINT,nativeBodyOffsetZ=data.body.offsetPoints[2]*POINT,
 nativeHurtOffsetX=data.hurt.offsetPoints[1]*POINT,nativeHurtOffsetZ=data.hurt.offsetPoints[2]*POINT,
 nativeHitOffsetX=data.hit.offsetPoints[1]*POINT,nativeHitOffsetZ=data.hit.offsetPoints[2]*POINT,
 nativeBodyLayer=data.bodyLayer,nativeBodyMask=data.bodyMask,nativeObstacleCollision=bit32.band(data.bodyMask,128)~=0,
 nativeMovement={borderClamp=data.bodyBorders,goalInsetX=data.sprite.widthPoints*POINT/2,goalInsetZ=data.sprite.heightPoints*POINT/2,
 precision=J.spawningRules.goalPrecisionPoints*POINT,collidePlayers=bit32.band(data.bodyMask,2)~=0},
 mass=data.mass,knockbackResistance=s.knockback_resistance,nativeArmor={base=s.armor,perWave=s.armor_increase_each_wave},
 nativeHealthRounding=true,nativeDamageRounding=true,nativeCanBeBoosted=false,nativeCanBeCharmed=false,
 loot={consumableChance=s.base_drop_chance,crateShare=s.item_drop_chance,crate=true,alwaysOrbs=true}}
return data
'''
    with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
        p=Path(folder)/'NativeSilesaurus.luau';p.write_text(text,encoding='utf-8')
        # StyLua 2.6 may collapse generated table.insert calls only on its second pass.
        for _ in range(2):subprocess.run(['stylua',str(p)],check=True)
        text=p.read_text(encoding='utf-8')
    for p,v in {ROOT/'docs/characters/silesaurus-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeSilesaurus.luau':text}.items():
        if args.check:assert p.read_text(encoding='utf-8')==v,'Stale Silesaurus source: '+str(p)
        else:p.write_text(v,encoding='utf-8',newline='\n')
    print('Normal Silesaurus actor compiled; evolution and complete area acceptance remain open')
if __name__=='__main__':main()
