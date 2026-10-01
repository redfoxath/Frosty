import bpy, sys
src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm=[o for o in bpy.data.objects if o.type=="ARMATURE"][0]
me=[o for o in bpy.data.objects if o.type=="MESH" and o.parent==arm][0]
mw=me.matrix_world.copy()
me.parent=None; me.matrix_world=mw
for m in list(me.modifiers): me.modifiers.remove(m)
for vg in list(me.vertex_groups): me.vertex_groups.remove(vg)
for o in list(bpy.data.objects):
    if o!=me: bpy.data.objects.remove(o)
# поставить на пол и сделать рост ~1.8 м
bpy.context.view_layer.objects.active=me; me.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
zs=[v.co.z for v in me.data.vertices]; h=max(zs)-min(zs)
me.scale=(1.8/h,)*3; me.location.z=-min(zs)*1.8/h
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.export_scene.fbx(filepath=dst, use_selection=True, path_mode='COPY', embed_textures=True, add_leaf_bones=False)
print("WROTE", dst)
