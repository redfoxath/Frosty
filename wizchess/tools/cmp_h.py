import bpy
from mathutils.bvhtree import BVHTree
def load(p):
    bpy.ops.import_scene.fbx(filepath=p)
    return [o for o in bpy.context.selected_objects if o.type=='MESH'][0]
bpy.ops.wm.read_factory_settings(use_empty=True)
a=load('/mnt/user-data/outputs/kon_dlya_mixamo.fbx'); b=load('/mnt/user-data/outputs/belyi_kon_dlya_mixamo.fbx')
dg=bpy.context.evaluated_depsgraph_get()
ta=BVHTree.FromObject(a,dg)
ds=[]
for v in b.data.vertices:
    p=b.matrix_world@v.co
    loc,n,i,d=ta.find_nearest(a.matrix_world.inverted()@p)
    ds.append(d*a.matrix_world.to_scale()[0])
ds.sort(); n=len(ds)
print("DIST median %.3f p90 %.3f p99 %.3f max %.3f m"%(ds[n//2],ds[int(n*.9)],ds[int(n*.99)],ds[-1]))
