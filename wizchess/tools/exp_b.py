import bpy
from mathutils import Matrix, Vector
from math import radians
bpy.ops.wm.open_mainfile(filepath='/tmp/bknight_dec.blend')
me=[o for o in bpy.data.objects if o.type=='MESH'][0]
me.data.transform(Matrix.Rotation(radians(-58),4,'Z'))
zs=[v.co.z for v in me.data.vertices]; zmin=min(zs); k=1.8/(max(zs)-zmin)
me.data.transform(Matrix.Translation((0,0,-zmin))); me.data.transform(Matrix.Scale(k,4))
xs=[v.co.x for v in me.data.vertices]; ys=[v.co.y for v in me.data.vertices]
me.data.transform(Matrix.Translation((-(min(xs)+max(xs))/2,-(min(ys)+max(ys))/2,0)))
for o in bpy.data.objects: o.select_set(o==me)
bpy.ops.export_scene.fbx(filepath='/mnt/user-data/outputs/chernaya_peshka_dlya_mixamo.fbx', use_selection=True, path_mode='COPY', embed_textures=True)
sc=bpy.context.scene
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
for loc in ((3,-4,4),(-3,4,4),(0,-5,1)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=1500; l.location=loc; sc.collection.objects.link(l)
sc.render.engine="CYCLES"; sc.cycles.samples=12; sc.render.resolution_x=400; sc.render.resolution_y=600
cam.location=(0,-4.5,0.95); d=Vector((0,0,0.9))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
sc.render.filepath='/tmp/claude-0/bk_front.png'; bpy.ops.render.render(write_still=True)
print("OK")
