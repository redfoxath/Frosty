"""Чинит пешку после Mixamo: меч целиком к правой кисти, щит обратно на левое предплечье.
Выход: models/pawn_w.glb (скелет + анимация ходьбы)."""
import bpy, sys
from mathutils import Vector

FBX = "/tmp/strut.fbx"
UPLOADED = "/mnt/user-data/outputs/peshka_bez_shchita_mixamo.fbx"
SHIELD = "/home/claude/wizchess/models/pawn_w_shield.glb"
OUT = "/home/claude/wizchess/models/pawn_w.glb"

def bbox(o):
    ws = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return [min(w[k] for w in ws) for k in range(3)], [max(w[k] for w in ws) for k in range(3)]

bpy.ops.wm.read_factory_settings(use_empty=True)
# 1) габариты загруженного в Mixamo тела — чтобы перенести щит в те же координаты
bpy.ops.import_scene.fbx(filepath=UPLOADED)
up = [o for o in bpy.data.objects if o.type == "MESH"][0]
umn, umx = bbox(up)
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

bpy.ops.import_scene.fbx(filepath=FBX)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
me = [o for o in bpy.data.objects if o.type == "MESH"][0]
arm.animation_data.action.name = "walk"
bpy.context.scene.frame_set(0)
# поза покоя для вычислений
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
mmn, mmx = bbox(me)
sc = [(mmx[k] - mmn[k]) / (umx[k] - umn[k]) for k in range(3)]
s = (sc[0] + sc[1] + sc[2]) / 3
off = [mmn[k] - umn[k] * s for k in range(3)]
print("scale", sc, "off", off)

mw = me.matrix_world
inv = mw.inverted()
verts = [mw @ v.co for v in me.data.vertices]
bones = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
hand = bones["mixamorig:RightHand"][0]

# 2) меч: вершины перед телом (сильно вперёд по -Y) — это лезвие; по ним строим ось
far = [p for p in verts if p.y < -0.30 and p.z > 0.2]
print("blade sample", len(far))
c = sum(far, Vector()) / len(far)
# направление: от кисти к центру дальних точек
axis = (c - hand).normalized()
tip = max(far, key=lambda p: (p - hand).dot(axis))
L = (tip - hand).dot(axis)
print("hand", hand, "tip", tip, "len", L)
def dist_to_axis(p):
    t = (p - hand).dot(axis)
    return t, (p - (hand + axis * t)).length
grp = me.vertex_groups.get("mixamorig:RightHand") or me.vertex_groups.new(name="mixamorig:RightHand")
sword = []
for i, p in enumerate(verts):
    t, r = dist_to_axis(p)
    # клинок — узкий цилиндр; у гарды и рукояти — чуть шире
    lim = 0.05 if t > 0.18 else 0.11
    if -0.12 < t < L + 0.03 and r < lim:
        sword.append(i)
print("sword verts", len(sword))
for i in sword:
    v = me.data.vertices[i]
    for g in list(v.groups):
        me.vertex_groups[g.group].remove([i])
    grp.add([i], 1.0, "REPLACE")

# 3) щит: импорт, перенос в координаты Mixamo, вершины к левому предплечью
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=SHIELD)
sh = [o for o in bpy.data.objects if o not in before and o.type == "MESH"][0]
for v in sh.data.vertices:
    w = sh.matrix_world @ v.co
    v.co = Vector((w.x * s + off[0], w.y * s + off[1], w.z * s + off[2]))
sh.matrix_world = me.matrix_world.copy()
for v in sh.data.vertices:
    v.co = inv @ v.co
fg = sh.vertex_groups.new(name="mixamorig:LeftForeArm")
fg.add([v.index for v in sh.data.vertices], 1.0, "REPLACE")
bpy.ops.object.select_all(action="DESELECT")
sh.select_set(True)
me.select_set(True)
bpy.context.view_layer.objects.active = me
bpy.ops.object.join()
for o in list(bpy.data.objects):
    if o.type == "MESH" and o != me:
        bpy.data.objects.remove(o)

arm.data.pose_position = "POSE"
for o in bpy.context.scene.objects:
    o.select_set(o in (arm, me))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True, export_animations=True)
print("WROTE", OUT)
