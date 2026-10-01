import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath='/mnt/user-data/outputs/peshka_dlya_mixamo.fbx')
print("OBJ",[(o.type,o.name,tuple(round(x,2) for x in o.dimensions)) for o in bpy.data.objects])
print("IMG",[(i.name,i.size[:]) for i in bpy.data.images])
