import bpy, sys
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[-1])
sc=bpy.context.scene
for a in bpy.data.armatures: a.pose_position="REST"
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
for loc in ((3,-4,4),(-3,4,4),(0,-5,1),(4,0,2)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=1500; l.location=loc; sc.collection.objects.link(l)
sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.render.resolution_x=700; sc.render.resolution_y=500
cam.location=(-1.2,-1.3,1.3); d=Vector((-0.25,-0.5,0.95))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler(); cam.data.lens=40
sc.render.filepath='/tmp/claude-0/axeclose.png'; bpy.ops.render.render(write_still=True)
