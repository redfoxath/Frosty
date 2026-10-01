"""Быстрый превью-рендер glb-моделей: python render_preview.py out.png a.glb [b.glb ...]"""
import bpy, sys
from math import radians
args = sys.argv[1:]
out, files = args[0], args[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
for i, f in enumerate(files):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.parent is None:
            o.location.x += (i - (len(files) - 1) / 2) * 1.1
    for o in new:
        if o.name.startswith("w_main"):
            o.location = (o.location.x + 0.42, 0.25, 0.95)
            o.rotation_euler = (radians(-100), 0, 0)
        if o.name.startswith("w_off"):
            o.location = (o.location.x - 0.42, 0.25, 0.95)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
cam.location = (1.4, 3.2, 1.5)
cam.rotation_euler = (radians(82), 0, radians(156))
cam.data.lens = 40
sc.camera = cam
for loc, en, col in (((2, 3, 4), 900, (1, .95, .9)), ((-3, -2, 3), 600, (.5, .6, 1)), ((0, 4, 1), 200, (1, .8, .6))):
    l = bpy.data.objects.new("l", bpy.data.lights.new("l", "POINT"))
    l.data.energy = en
    l.data.color = col
    l.location = loc
    sc.collection.objects.link(l)
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.025, 0.04, 1)
sc.world = w
sc.render.engine = "CYCLES"
sc.cycles.samples = 24
sc.cycles.device = "CPU"
sc.render.resolution_x = 900
sc.render.resolution_y = 700
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
