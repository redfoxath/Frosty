import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/home/claude/wizchess/models/pawn_b.glb')
sc=bpy.context.scene
for a in bpy.data.armatures: a.pose_position="REST"
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
print("ACT", [a.name for a in bpy.data.actions], arm.animation_data.action.name if arm.animation_data and arm.animation_data.action else None)
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
for loc in ((3,-4,4),(-3,4,4),(0,-5,1)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=1500; l.location=loc; sc.collection.objects.link(l)
sc.render.engine="CYCLES"; sc.cycles.samples=10; sc.render.resolution_x=600; sc.render.resolution_y=800
for i,f in enumerate((1,)):
    sc.frame_set(f)
    cam.location=(-3.2,0.0,1.0); d=Vector((0,0,0.9))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f'/tmp/claude-0/bside_{i}.png'; bpy.ops.render.render(write_still=True)
