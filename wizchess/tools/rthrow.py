import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath='/tmp/hthrow.fbx')
sc=bpy.context.scene
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
pb=arm.pose.bones['mixamorig:RightHand']; hips=arm.pose.bones['mixamorig:Hips']
prev=None
for f in range(1,148,3):
    sc.frame_set(f)
    p=arm.matrix_world@pb.head; h=arm.matrix_world@hips.head
    v=(p-prev).length/3*30 if prev else 0
    print("F",f,"hand",tuple(round(x,2) for x in p),"hips",tuple(round(x,2) for x in h),"v %.2f"%v); prev=p
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
for loc in ((3,-4,4),(-3,4,4),(4,0,2)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=1500; l.location=loc; sc.collection.objects.link(l)
sc.render.engine="CYCLES"; sc.cycles.samples=6; sc.render.resolution_x=240; sc.render.resolution_y=320
cam.location=(4.2,-1.0,1.1); d=Vector((0,-0.3,0.9))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler(); cam.data.lens=35
for i,f in enumerate(range(1,148,9)):
    sc.frame_set(f); sc.render.filepath=f'/tmp/claude-0/th_{i:02d}.png'; bpy.ops.render.render(write_still=True)
