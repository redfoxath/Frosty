import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/home/claude/wizchess/tools/props/axe_b.glb')
o=[x for x in bpy.data.objects if x.type=='MESH'][0]
ps=[o.matrix_world@v.co for v in o.data.vertices]
import collections
for k in range(3):
    print("axis",k,round(min(p[k] for p in ps),3),round(max(p[k] for p in ps),3))
# width profile along Z
bins=collections.defaultdict(list)
for p in ps: bins[int(p.z*20)].append(p)
for z in sorted(bins):
    b=bins[z]; print(z/20, "x",round(min(p.x for p in b),2),round(max(p.x for p in b),2),"y",round(min(p.y for p in b),2),round(max(p.y for p in b),2))
