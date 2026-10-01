"""Конь: скелет Mixamo (чёрный) + перенос весов на белого + копьё в правой руке (дочерний объект кости).
Анимации: throw (Mixamo), walk (от пешки), idle (кадр 1 броска).
python build_horse.py w|b"""
import bpy, sys
import numpy as np
from mathutils import Vector, Matrix

SIDE = [a for a in sys.argv if a in ("w", "b")][-1]
THROW = "/tmp/hthrow.fbx"
WALK = "/tmp/bwalk.fbx"
WHITE = "/mnt/user-data/outputs/belyi_kon_dlya_mixamo.fbx"
SPEAR = "/home/claude/wizchess/tools/props/spear1.glb" if SIDE == "w" else "/home/claude/wizchess/tools/props/spear2.glb"
OUT = f"/home/claude/wizchess/models/knight_{SIDE}.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = 30
bpy.ops.import_scene.fbx(filepath=THROW)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
me = [o for o in bpy.data.objects if o.type == "MESH"][0]
throw = arm.animation_data.action
throw.name = "throw"
throw.use_fake_user = True

# --- ходьба от пешки (те же имена костей Mixamo) ---
before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=WALK)
for o in list(bpy.data.objects):
    if o not in before:
        if o.type == "ARMATURE" and o.animation_data and o.animation_data.action:
            wa = o.animation_data.action
            wa.name = "walk"
            wa.use_fake_user = True
        bpy.data.objects.remove(o)

# --- idle: боевая стойка с поднятым копьём (кадр 52 броска) ---
arm.animation_data.action = throw
sc.frame_set(52)
idle = bpy.data.actions.new("idle")
idle.use_fake_user = True
mats = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones}
arm.animation_data.action = idle
for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
    pb.location, pb.rotation_quaternion = mats[pb.name]
    for f in (0, 30):
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("location", frame=f)

# --- белый: меш с теми же весами ---
if SIDE == "w":
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=WHITE)
    wm = [o for o in bpy.data.objects if o not in before and o.type == "MESH"][0]
    for o in list(bpy.data.objects):
        if o not in before and o != wm:
            bpy.data.objects.remove(o)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    for g in me.vertex_groups:
        wm.vertex_groups.new(name=g.name)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = wm
    wm.select_set(True)
    dt = wm.modifiers.new("dt", "DATA_TRANSFER")
    dt.object = me
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.modifier_apply(modifier="dt")
    mw = wm.matrix_world.copy()
    wm.parent = arm
    wm.matrix_world = mw
    am = wm.modifiers.new("arm", "ARMATURE")
    am.object = arm
    bpy.data.objects.remove(me)
    me = wm
    arm.data.pose_position = "POSE"

# --- копьё ---
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=SPEAR)
sp = [o for o in bpy.data.objects if o not in before and o.type == "MESH"][0]
sp.data.transform(sp.matrix_world)
sp.matrix_world = Matrix.Identity(4)
pts = np.array([list(v.co) for v in sp.data.vertices])
c0 = pts.mean(0)
w_, v_ = np.linalg.eigh((pts - c0).T @ (pts - c0))
A = Vector(v_[:, -1]).normalized()
proj = (pts - c0) @ np.array(A)
L = proj.max() - proj.min()
# остриё — конец с самым узким сечением
def width(t0, t1):
    m = (proj > t0) & (proj < t1)
    q = pts[m] - c0
    r = q - np.outer(q @ np.array(A), np.array(A))
    return np.linalg.norm(r, axis=1).max() if m.any() else 0
lo, hi = proj.min(), proj.max()
w_lo = width(lo, lo + 0.08 * L); w_hi = width(hi - 0.08 * L, hi)
# у древка внизу утолщение-набалдашник; остриё у противоположного конца с плоским лезвием.
# надёжнее: со стороны острия на 15-30% длины есть широкая часть лезвия, у пятки — нет.
blade_hi = width(hi - 0.3 * L, hi - 0.1 * L); blade_lo = width(lo + 0.1 * L, lo + 0.3 * L)
if blade_lo < blade_hi:  # широкая гарда-раструб у пятки, остриё на другом конце
    A = -A; proj = -proj; lo, hi = -hi, -lo
print("spear L", L, "blade side widths", blade_hi, blade_lo)
butt = Vector(c0) + A * lo
# рукоять: между навершием и раструбом-гардой (самое широкое место в нижней половине)
ts = np.linspace(0.02, 0.5, 49)
widths = [width(lo + t * L - 0.012 * L, lo + t * L + 0.012 * L) for t in ts]
t_guard = float(ts[int(np.argmax(widths))])
grip_local = butt + A * (t_guard * 0.5 * L)
print("guard at", round(t_guard, 3), "grip at", round(t_guard * 0.5, 3))
# ось поперёк: любая перпендикулярная
X0 = A.orthogonal().normalized()
# ставим копьё по позе ЗАМАХА (кадр REL): остриё вперёд и чуть вверх, как у метательного копья
REL = 66
arm.data.pose_position = "POSE"
arm.animation_data.action = throw
sc.frame_set(REL)
bpy.context.view_layer.update()
pb = arm.pose.bones["mixamorig:RightHand"]
HM = arm.matrix_world @ pb.matrix
hh = arm.matrix_world @ pb.head
ht = arm.matrix_world @ pb.tail
hd = (ht - hh).normalized()
grip = hh + hd * 0.075
h = Vector((0, -1, 0.15)).normalized()           # вперёд (персонаж смотрит в -Y)
h = (h - hd * h.dot(hd)).normalized()
x1 = hd.cross(h).normalized()
X0 = A.orthogonal().normalized()
src = Matrix((X0, A, A.cross(X0).normalized())).transposed()
dst = Matrix((x1, h, x1.cross(h).normalized())).transposed()
length = 2.0 if SIDE == "w" else 1.8
k = length / L
R = (dst @ src.inverted()).to_4x4()
sp.data.transform(Matrix.Translation(grip) @ R @ Matrix.Scale(k, 4) @ Matrix.Translation(-grip_local))
sp.name = "spear"
sp.data.name = "spear"
sp.parent = arm
sp.parent_type = "BONE"
sp.parent_bone = "mixamorig:RightHand"
pm = arm.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.bone.length, 0))
sp.matrix_parent_inverse = pm.inverted()
bpy.context.view_layer.update()
print("spear dir at release", h)
arm.data.pose_position = "POSE"
bpy.context.view_layer.update()

for img in bpy.data.images:
    if img.size[0] > 2048:
        img.scale(2048, 2048)
arm.animation_data.action = idle
for o in bpy.context.scene.objects:
    o.select_set(o in (arm, me, sp))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_image_format="JPEG", export_jpeg_quality=88)
print("WROTE", OUT)

if "--preview" in sys.argv:
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera = cam
    for loc in ((3, -4, 4), (-3, 4, 4), (0, -5, 1), (4, 0, 2)):
        l = bpy.data.objects.new("l", bpy.data.lights.new("l", "POINT")); l.data.energy = 1500; l.location = loc; sc.collection.objects.link(l)
    sc.render.engine = "CYCLES"; sc.cycles.samples = 8; sc.render.resolution_x = 320; sc.render.resolution_y = 420
    shots = [("idle", 0), ("walk", 10), ("throw", 58), ("throw", 66), ("throw", 71)]
    for i, (an, fr) in enumerate(shots):
        arm.animation_data.action = bpy.data.actions[an]
        sc.frame_set(fr)
        cam.location = (3.4, -1.8, 1.2)
        d = Vector((0, -0.4, 0.95)) - cam.location
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = f"/tmp/claude-0/hz_{SIDE}_{i}.png"
        bpy.ops.render.render(write_still=True)
