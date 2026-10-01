import bpy, bmesh
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/tmp/knight.glb')
me=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('tripo')][0]
bm=bmesh.new(); bm.from_mesh(me.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0008); bm.verts.ensure_lookup_table()
seen=set(); isl=[]
for v in bm.verts:
    if v.index in seen: continue
    stack=[v]; comp=[]; seen.add(v.index)
    while stack:
        x=stack.pop(); comp.append(x.index)
        for e in x.link_edges:
            o=e.other_vert(x)
            if o.index not in seen: seen.add(o.index); stack.append(o)
    isl.append(comp)
isl.sort(key=len, reverse=True)
print("ISLANDS", len(isl))
for c in isl[:12]:
    cs=[me.matrix_world@bm.verts[i].co for i in c]
    mn=[round(min(p[k] for p in cs),2) for k in range(3)]; mx=[round(max(p[k] for p in cs),2) for k in range(3)]
    print(len(c), mn, mx)
