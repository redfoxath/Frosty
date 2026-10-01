import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/tmp/knight.glb')
arm=[o for o in bpy.data.objects if o.type=="ARMATURE"][0]
me=[o for o in bpy.data.objects if o.type=="MESH" and o.parent==arm][0]
import json
V=[list(me.matrix_world@v.co) for v in list(me.data.vertices)[::3]]
B=[(b.name,list(arm.matrix_world@b.head_local),list(arm.matrix_world@b.tail_local)) for b in arm.data.bones if 'Hand' not in b.name or b.name.endswith('Hand')]
json.dump({"V":V,"B":B},open('/tmp/viz.json','w'))
