import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/tmp/knight.glb')
for o in bpy.data.objects:
    print(o.type, o.name, tuple(round(x,3) for x in o.dimensions), "parent", o.parent.name if o.parent else None)
    if o.type=='ARMATURE':
        for b in o.data.bones:
            print("  BONE", b.name, "parent", b.parent.name if b.parent else None, "head", tuple(round(x,3) for x in (o.matrix_world@b.head_local)), "tail", tuple(round(x,3) for x in (o.matrix_world@b.tail_local)))
