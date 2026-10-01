import bpy, sys
from mathutils import Vector
src,dst,ratio,png=sys.argv[-4],sys.argv[-3],float(sys.argv[-2]),sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
me=[o for o in bpy.data.objects if o.type=='MESH'][0]
bpy.context.view_layer.objects.active=me; me.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=0.0003); bpy.ops.object.mode_set(mode='OBJECT')
m=me.modifiers.new("d","DECIMATE"); m.ratio=ratio; bpy.ops.object.modifier_apply(modifier="d")
print("TRIS", sum(len(p.vertices)-2 for p in me.data.polygons))
for o in bpy.data.objects: o.select_set(o==me)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True)
sc=bpy.context.scene
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
for loc in ((3,-4,4),(-3,4,4),(4,1,1),(-4,-1,1)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=900; l.location=loc; sc.collection.objects.link(l)
sc.render.engine="CYCLES"; sc.cycles.samples=12; sc.render.resolution_x=400; sc.render.resolution_y=400
import math
for i,(a,b) in enumerate(((3,0),(0,-3),(2.1,-2.1))):
    cam.location=(a,b,0.5); d=Vector((0,0,0.5))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler(); cam.data.lens=45
    sc.render.filepath=png+f'_{i}.png'; bpy.ops.render.render(write_still=True)
