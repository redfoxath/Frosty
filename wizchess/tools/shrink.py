import bpy, sys
src,dst=sys.argv[-2],sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for img in bpy.data.images:
    if img.size[0] > 2048: img.scale(2048, 2048)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_skins=True, export_animations=True, export_image_format='JPEG', export_jpeg_quality=88)
print("WROTE")
