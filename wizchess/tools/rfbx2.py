import bpy
from mathutils import Vector
from math import radians
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath='/mnt/user-data/outputs/peshka_bez_shchita_mixamo.fbx')
ob=[o for o in bpy.data.objects if o.type=='MESH'][0]
print("IMPORTED", ob.name, tuple(round(x,3) for x in ob.rotation_euler), tuple(round(x,3) for x in ob.dimensions))
sc=bpy.context.scene
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
for loc in ((3,-4,4),(-3,4,4),(0,-5,1),(0,5,1)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=1500; l.location=loc; sc.collection.objects.link(l)
sc.render.engine="CYCLES"; sc.cycles.samples=12; sc.render.resolution_x=400; sc.render.resolution_y=600
base=ob.rotation_euler.z
for i,a in enumerate((0,-40,40,80)):
    ob.rotation_euler.z=base+radians(a)
    cam.location=(0,-4.5,0.95); d=Vector((0,0,0.9))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f'/tmp/claude-0/rot_{i}.png'; bpy.ops.render.render(write_still=True)
