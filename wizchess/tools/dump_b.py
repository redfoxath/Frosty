import bpy, json
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath='/mnt/user-data/outputs/chernaya_peshka_dlya_mixamo.fbx')
me=[o for o in bpy.data.objects if o.type=='MESH'][0]
V=[list(me.matrix_world@v.co) for v in me.data.vertices]
json.dump(V,open('/tmp/bk_verts.json','w'))
print("N",len(V))
