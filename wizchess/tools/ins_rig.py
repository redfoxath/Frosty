import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/home/claude/wizchess/models/pawn_w.glb')
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
print("ARM", arm.name, tuple(arm.rotation_euler), tuple(arm.scale), [a.name for a in bpy.data.actions])
arm.data.pose_position='REST'; bpy.context.view_layer.update()
for n in ("mixamorig:Hips","mixamorig:RightArm","mixamorig:RightForeArm","mixamorig:RightHand","mixamorig:LeftArm","mixamorig:LeftForeArm","mixamorig:Head","mixamorig:RightUpLeg"):
    n2=[b for b in arm.data.bones if b.name.replace('_',':')==n or b.name==n]
    b=n2[0]
    print(b.name, "head", tuple(round(x,2) for x in arm.matrix_world@b.head_local), "dir", tuple(round(x,2) for x in (arm.matrix_world.to_3x3()@(b.tail_local-b.head_local)).normalized()))
me=[o for o in bpy.data.objects if o.type=='MESH'][0]
vg={g.index:g.name for g in me.vertex_groups}
from mathutils import Vector
hand=[v for v in me.data.vertices if any(vg[g.group].endswith('RightHand') and g.weight>0.9 for g in v.groups)]
ps=[me.matrix_world@v.co for v in hand]
hh=arm.matrix_world@[b for b in arm.data.bones if b.name.endswith('RightHand')][0].head_local
tip=max(ps,key=lambda p:(p-hh).length)
print("sword tip", tuple(round(x,2) for x in tip), "from hand", tuple(round(x,2) for x in (tip-hh)))
