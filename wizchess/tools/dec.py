import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/tmp/harpy.glb')
for o in bpy.data.objects:
    if o.type=='MESH':
        bpy.context.view_layer.objects.active=o
        m=o.modifiers.new("d","DECIMATE"); m.ratio=0.03
        bpy.ops.object.modifier_apply(modifier="d")
        print("TRIS", sum(len(p.vertices)-2 for p in o.data.polygons))
bpy.ops.export_scene.gltf(filepath='/tmp/harpy_low.glb', export_format='GLB')
