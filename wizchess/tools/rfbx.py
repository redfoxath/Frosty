import bpy
from mathutils import Vector
from math import radians
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath='/mnt/user-data/outputs/peshka_bez_shchita_mixamo.fbx')
sc=bpy.context.scene
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
for loc in ((3,-4,4),(-3,4,4),(0,-5,1),(0,5,1)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=1500; l.location=loc; sc.collection.objects.link(l)
sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.render.resolution_x=500; sc.render.resolution_y=700
for nm,y in (("a",-4.5),("b",4.5)):
    cam.location=(0,y,0.95); d=Vector((0,0,0.9))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f'/tmp/claude-0/ns_{nm}.png'; bpy.ops.render.render(write_still=True)
