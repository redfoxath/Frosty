import bpy, bmesh, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/tmp/knight.glb')
arm=[o for o in bpy.data.objects if o.type=="ARMATURE"][0]
me=[o for o in bpy.data.objects if o.type=="MESH" and o.parent==arm][0]
mw=me.matrix_world.copy(); me.parent=None; me.matrix_world=mw
for m in list(me.modifiers): me.modifiers.remove(m)
for vg in list(me.vertex_groups): me.vertex_groups.remove(vg)
for o in list(bpy.data.objects):
    if o!=me: bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active=me; me.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# склеить швы и разделить на куски
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.0008)
bpy.ops.mesh.separate(type='LOOSE'); bpy.ops.object.mode_set(mode='OBJECT')
parts=sorted([o for o in bpy.data.objects if o.type=='MESH'], key=lambda o: len(o.data.vertices), reverse=True)
body, shield = parts[0], parts[1]
print("BODY", len(body.data.vertices))
zs=[(body.matrix_world@v.co).z for v in body.data.vertices]; zmin=min(zs); h=max(zs)-zmin; k=1.8/h
from math import radians
for o in parts:
    o.scale=(k,k,k); o.location=(0,0,-zmin*k); pass
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
from mathutils import Matrix
for o in parts: o.data.transform(Matrix.Rotation(radians(-40), 4, 'Z'))
print('DIMS', tuple(round(x,2) for x in body.dimensions), tuple(body.rotation_euler))
# рыцарь без щита -> FBX для Mixamo
bpy.ops.object.select_all(action='DESELECT'); body.select_set(True)
bpy.ops.export_scene.fbx(filepath='/mnt/user-data/outputs/peshka_bez_shchita_mixamo.fbx', use_selection=True, path_mode='COPY', embed_textures=True)
# щит отдельно для игры
bpy.ops.object.select_all(action='DESELECT'); shield.select_set(True)
bpy.ops.export_scene.gltf(filepath='/home/claude/wizchess/models/pawn_w_shield.glb', export_format='GLB', use_selection=True)
print("OK")
