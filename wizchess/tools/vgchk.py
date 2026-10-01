import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/home/claude/wizchess/models/pawn_w.glb')
ms=[o for o in bpy.data.objects if o.type=='MESH']; print('MESHES',[(o.name,len(o.data.vertices),len(o.vertex_groups),o.parent.name if o.parent else None) for o in ms]); me=max(ms,key=lambda o:len(o.vertex_groups))
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
print("BONES", [b.name for b in arm.data.bones if 'Hand' in b.name][:4])
print("VG", [g.name for g in me.vertex_groups][:40])
cnt={}
for v in me.data.vertices:
    for g in v.groups:
        if g.weight>0.9: cnt[me.vertex_groups[g.group].name]=cnt.get(me.vertex_groups[g.group].name,0)+1
print("CNT", cnt)
