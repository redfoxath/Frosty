"""Чёрная пешка: риг Mixamo + топор в правую руку + щит на левое предплечье.
Выход: models/pawn_b.glb (с анимацией walk), текстуры JPEG до 2048."""
import bpy
from mathutils import Vector, Matrix

FBX = "/tmp/bwalk.fbx"
AXE = "/home/claude/wizchess/tools/props/axe_b.glb"
SHIELD = "/home/claude/wizchess/tools/props/shield_b.glb"
OUT = "/home/claude/wizchess/models/pawn_b.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
me = [o for o in bpy.data.objects if o.type == "MESH"][0]
arm.animation_data.action.name = "walk"
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
B = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
zs = [(me.matrix_world @ v.co).z for v in me.data.vertices]
H = max(zs) - min(zs)
print("height", H)

def import_prop(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    o = [x for x in bpy.data.objects if x not in before and x.type == "MESH"][0]
    # запечь трансформацию импорта в вершины
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    return o

def place(o, origin_local, X, Y, Z, scale, pos):
    """Переносит объект: точка origin_local -> pos, оси объекта X,Y,Z -> заданные мировые векторы."""
    R = Matrix((X, Y, Z)).transposed().to_4x4()
    M = Matrix.Translation(pos) @ R @ Matrix.Scale(scale, 4) @ Matrix.Translation(-origin_local)
    o.data.transform(M)

# ---- топор ----
axe = import_prop(AXE)
pts = [v.co.copy() for v in axe.data.vertices]
zmin = min(p.z for p in pts); zmax = max(p.z for p in pts)
low = [p for p in pts if p.z < zmin + 0.42 * (zmax - zmin)]
c0 = sum(low, Vector()) / len(low)
# ось топорища — главная ось нижней (узкой) части
import numpy as np
M_ = np.array([[p.x - c0.x, p.y - c0.y, p.z - c0.z] for p in low])
w_, v_ = np.linalg.eigh(M_.T @ M_)
A = Vector(v_[:, -1]).normalized()
if A.z < 0: A = -A
proj = [(p - c0).dot(A) for p in pts]
bot = c0 + A * min(proj); L = max(proj) - min(proj)
grip_local = bot + A * (0.2 * L)
# направление лезвия: самая широкая часть головы, перпендикулярно оси
head = [p for p in pts if (p - c0).dot(A) > max(proj) - 0.35 * L]
far = max(head, key=lambda p: ((p - c0) - A * (p - c0).dot(A)).length)
Bl = ((far - c0) - A * (far - c0).dot(A)).normalized()
N = A.cross(Bl).normalized()
print("axe axis", A, "len", L)
hand_h, hand_t = B["mixamorig:RightHand"]
fore_h, fore_t = B["mixamorig:RightForeArm"]
hd = (hand_t - hand_h).normalized()
grip = hand_h + hd * 0.075 + Vector((0, -0.01, 0))
h = Vector((0, -1, 0.35)).normalized()            # топорище вперёд и чуть вверх
h = (h - hd * h.dot(hd)).normalized()             # строго поперёк кисти — через кулак
dn = (Vector((0, 0, -1)) - h * Vector((0, 0, -1)).dot(h)).normalized()
src_basis = Matrix((Bl, A, N)).transposed()
dst_basis = Matrix((dn, h, dn.cross(h).normalized())).transposed()
k = 0.95 * H / 1.75
R = (dst_basis @ src_basis.inverted()).to_4x4()
axe.data.transform(Matrix.Translation(grip) @ R @ Matrix.Scale(k, 4) @ Matrix.Translation(-grip_local))
g = axe.vertex_groups.new(name="mixamorig:RightHand")
g.add([v.index for v in axe.data.vertices], 1.0, "REPLACE")

# ---- щит ----
sh = import_prop(SHIELD)
lf_h, lf_t = B["mixamorig:LeftForeArm"]
d2 = (lf_t - lf_h).normalized()
out = Vector((1, 0, 0))
n = (out - d2 * out.dot(d2)).normalized()          # наружу (влево от персонажа)
Zs = -d2                                           # верх щита — к локтю
Xs = n
Ys = Zs.cross(Xs).normalized()
center = (lf_h + lf_t) / 2 + n * 0.09
place(sh, Vector((0, 0, 0.5)), Xs, Ys, Zs, 0.68 * H / 1.75, center)
g2 = sh.vertex_groups.new(name="mixamorig:LeftForeArm")
g2.add([v.index for v in sh.data.vertices], 1.0, "REPLACE")

# ---- в один меш под скелет ----
inv = me.matrix_world.inverted()
for o in (axe, sh):
    o.data.transform(inv)
    o.matrix_world = me.matrix_world.copy()
bpy.ops.object.select_all(action="DESELECT")
for o in (axe, sh, me):
    o.select_set(True)
bpy.context.view_layer.objects.active = me
bpy.ops.object.join()

# текстуры поменьше
for img in bpy.data.images:
    if img.size[0] > 2048:
        img.scale(2048, 2048)

arm.data.pose_position = "POSE"
for o in bpy.context.scene.objects:
    o.select_set(o in (arm, me))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True,
                          export_animations=True, export_image_format="JPEG", export_jpeg_quality=88)
print("WROTE", OUT)
