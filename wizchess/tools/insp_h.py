import bpy, json
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath='/tmp/hthrow.fbx')
for o in bpy.data.objects:
    print("OBJ", o.type, o.name, tuple(round(x,3) for x in o.dimensions), tuple(round(x,3) for x in o.scale))
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
me=[o for o in bpy.data.objects if o.type=='MESH'][0]
print("BONES", len(arm.data.bones), [b.name for b in arm.data.bones][:8])
print("ACTIONS", [(a.name, tuple(a.frame_range)) for a in bpy.data.actions])
print("IMG", [(i.name, i.size[:]) for i in bpy.data.images])
# точки для графика в позе покоя
V=[]
for v in list(me.data.vertices)[::2]:
    p=me.matrix_world@v.co
    g=max(v.groups, key=lambda x:x.weight).group if v.groups else -1
    V.append([p.x,p.y,p.z, me.vertex_groups[g].name if g>=0 else ""])
B=[(b.name, list(arm.matrix_world@b.head_local), list(arm.matrix_world@b.tail_local)) for b in arm.data.bones]
json.dump({"V":V,"B":B}, open('/tmp/vizh.json','w'))
