import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/tmp/knight.glb')
for o in bpy.data.objects:
    if o.type in ('MESH','ARMATURE'):
        print(o.name, "loc", tuple(o.location), "rot", tuple(o.rotation_euler), "scale", tuple(o.scale))
    if o.type=='MESH':
        ws=[o.matrix_world@Vector(v) for v in o.bound_box]
        print("  min", [round(min(w[k] for w in ws),3) for k in range(3)], "max", [round(max(w[k] for w in ws),3) for k in range(3)])
        print("  mats", [ (m.name) for m in o.data.materials])
