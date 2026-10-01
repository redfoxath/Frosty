import bpy, sys
from mathutils import Vector
from math import radians
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/tmp/harpy.glb')
sc=bpy.context.scene
mn=[1e9]*3; mx=[-1e9]*3
for o in bpy.data.objects:
    if o.type=='MESH':
        for v in o.bound_box:
            w=o.matrix_world@Vector(v)
            for k in range(3): mn[k]=min(mn[k],w[k]); mx[k]=max(mx[k],w[k])
print("BBOX",mn,mx)
c=[(a+b)/2 for a,b in zip(mn,mx)]; h=mx[2]-mn[2]
cam=bpy.data.objects.new("cam",bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera=cam
cam.data.lens=50
for loc,en in (((2,-3,4),900),((-3,2,3),500),((0,-4,1),300)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=en*h*h; l.location=(c[0]+loc[0]*h,c[1]+loc[1]*h,c[2]+loc[2]*h*.5); sc.collection.objects.link(l)
w=bpy.data.worlds.new("w"); w.use_nodes=True; w.node_tree.nodes["Background"].inputs[0].default_value=(0.05,0.045,0.06,1); sc.world=w
sc.render.engine="CYCLES"; sc.cycles.samples=32; sc.render.resolution_x=700; sc.render.resolution_y=900
for name,d in (("front",(0,-1)),("side",(1,-0.35))):
    dist=h*2.6
    cam.location=(c[0]+d[0]*dist, c[1]+d[1]*dist, c[2]+h*0.1)
    dirv=Vector(c)-cam.location
    cam.rotation_euler=dirv.to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f'/tmp/claude-0/harpy_{name}.png'
    bpy.ops.render.render(write_still=True)
