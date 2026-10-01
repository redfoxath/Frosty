import bpy, sys
from mathutils import Vector
from math import radians
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/tmp/whorse.glb')
me=[o for o in bpy.data.objects if o.type=='MESH'][0]
mw=me.matrix_world.copy(); me.parent=None; me.matrix_world=mw
for o in list(bpy.data.objects):
    if o!=me: bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active=me; me.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.0004); bpy.ops.object.mode_set(mode='OBJECT')
m=me.modifiers.new("d","DECIMATE"); m.ratio=0.012
bpy.ops.object.modifier_apply(modifier="d")
print("TRIS", sum(len(p.vertices)-2 for p in me.data.polygons))
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.separate(type='LOOSE'); bpy.ops.object.mode_set(mode='OBJECT')
parts=sorted([o for o in bpy.data.objects if o.type=='MESH'], key=lambda o: len(o.data.vertices), reverse=True)
for o in parts[:8]:
    ws=[o.matrix_world@Vector(c) for c in o.bound_box]
    print("PART", len(o.data.vertices), [round(min(w[k] for w in ws),2) for k in range(3)], [round(max(w[k] for w in ws),2) for k in range(3)])
bpy.ops.wm.save_as_mainfile(filepath='/tmp/whorse_dec.blend')
sc=bpy.context.scene
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
for loc in ((3,-4,4),(-3,4,4),(0,-5,1),(0,5,1)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=60; l.location=loc; sc.collection.objects.link(l)
w=bpy.data.worlds.new("w"); w.use_nodes=True; w.node_tree.nodes["Background"].inputs[0].default_value=(0.35,0.35,0.38,1); sc.world=w
sc.render.engine="CYCLES"; sc.cycles.samples=10; sc.render.resolution_x=300; sc.render.resolution_y=450
for i,a in enumerate((0,90,180,270)):
    cam.location=(4.5*__import__('math').sin(radians(a)),-4.5*__import__('math').cos(radians(a)),0.0); d=Vector((0,0,0))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
    cam.data.lens=60
    sc.render.filepath=f'/tmp/claude-0/wh_{i}.png'; bpy.ops.render.render(write_still=True)
