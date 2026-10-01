"""Анимации ударов для пешек (скелет Mixamo).
Позы задаются направлениями костей в системе персонажа: F вперёд, U вверх, R его правая рука.
python make_attacks.py in.glb out.glb w|b"""
import bpy, sys
from mathutils import Vector, Matrix, Quaternion

_a = [x for x in sys.argv if not x.startswith("--")]
SRC, DST, SIDE = _a[-3], _a[-2], _a[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
bpy.context.scene.render.fps = 30
bpy.context.scene.render.fps_base = 1.0
me = max([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: len(o.vertex_groups))
for o in list(bpy.data.objects):
    if o.type == "MESH" and o != me:
        bpy.data.objects.remove(o)
F, U, R = Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((-1, 0, 0))
L = -R
LEAN = Vector((1, 0, 0))  # поворот вокруг этой оси на +a = наклон вперёд
def n(v): return v.normalized()

def bone(name):
    for b in arm.pose.bones:
        if b.name.split(":")[-1].split("_")[-1] == name or b.name.endswith(name) and len(b.name) - len(name) <= 10:
            if b.name.endswith(name):
                return b
    raise KeyError(name)
PB = {k: bone(k) for k in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
                           "RightShoulder", "RightArm", "RightForeArm", "RightHand",
                           "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
                           "RightUpLeg", "RightLeg", "RightFoot", "LeftUpLeg", "LeftLeg", "LeftFoot"]}
for pb in PB.values():
    pb.rotation_mode = "QUATERNION"

# вектор оружия в локальной системе кисти (покой)
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
hb = arm.data.bones[PB["RightHand"].name]
vg = me.vertex_groups.get(hb.name)
inv_arm = arm.matrix_world.inverted()
hand_head = hb.head_local
pts = []
for v in me.data.vertices:
    for g in v.groups:
        if g.group == vg.index and g.weight > 0.95:
            pts.append(inv_arm @ (me.matrix_world @ v.co))
tip = max(pts, key=lambda p: (p - hand_head).length)
W_LOCAL = hb.matrix_local.inverted().to_3x3() @ (tip - hand_head)
print("weapon len (arm units)", (tip - hand_head).length, "armworld", arm.matrix_world.to_3x3().normalized().to_euler(), arm.parent)
arm.data.pose_position = "POSE"

def reset():
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    bpy.context.view_layer.update()

def rotate(pb, q):
    h = pb.head.copy()
    pb.matrix = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()

W2A = None
def wa(d):
    global W2A
    if W2A is None:
        W2A = arm.matrix_world.to_3x3().normalized().inverted()
    return (W2A @ n(d)).normalized()

def aim(name, d):
    pb = PB[name]
    cur = (pb.tail - pb.head).normalized()
    rotate(pb, cur.rotation_difference(wa(d)))

def aim_weapon(d):
    pb = PB["RightHand"]
    cur = (pb.matrix.to_3x3() @ W_LOCAL).normalized()
    rotate(pb, cur.rotation_difference(wa(d)))

def turn(name, axis, ang):
    rotate(PB[name], Quaternion(wa(axis), ang))

def pose(p):
    reset()
    if "hips_down" in p:
        PB["Hips"].location = Vector((0, 0, 0))
        hb_ = PB["Hips"]
        hb_.matrix = Matrix.Translation(wa(U) * (-p["hips_down"] * 100)) @ hb_.matrix
        bpy.context.view_layer.update()
    for k, a in p.get("body", []):
        turn(k, *a)
    for k in ["RightUpLeg", "RightLeg", "LeftUpLeg", "LeftLeg",
              "RightArm", "RightForeArm", "LeftArm", "LeftForeArm"]:
        if k in p:
            aim(k, p[k])
    for k in ["RightFoot", "LeftFoot"]:
        if k in p:
            aim(k, p[k])
    if "weapon" in p:
        aim_weapon(p["weapon"])
    if "LeftHand" in p:
        aim("LeftHand", p["LeftHand"])

def key(frame):
    for pb in PB.values():
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    PB["Hips"].keyframe_insert("location", frame=frame)

def make(name, seq):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for frame, p in seq:
        pose(p)
        key(frame)
    print("action", name, seq[-1][0])
    return act

# ---------- позы ----------
legs_stand = {"RightUpLeg": -U + R * 0.12, "RightLeg": -U + R * 0.05, "LeftUpLeg": -U + L * 0.12, "LeftLeg": -U + L * 0.05,
              "RightFoot": F - U * 0.4, "LeftFoot": F - U * 0.4}
legs_lunge = {"RightUpLeg": -U + F * 0.75 + R * 0.15, "RightLeg": -U + F * 0.05, "LeftUpLeg": -U - F * 0.6 + L * 0.1, "LeftLeg": -U - F * 0.9,
              "RightFoot": F - U * 0.3, "LeftFoot": F - U * 0.9, "hips_down": 0.12}
legs_crouch = {"RightUpLeg": -U + F * 0.9 + R * 0.25, "RightLeg": -U - F * 0.25, "LeftUpLeg": -U + F * 0.5 + L * 0.25, "LeftLeg": -U - F * 0.5,
               "RightFoot": F - U * 0.3, "LeftFoot": F - U * 0.3, "hips_down": 0.25}
legs_tuck = {"RightUpLeg": F * 0.9 - U * 0.5 + R * 0.2, "RightLeg": -U - F * 0.7, "LeftUpLeg": F * 0.5 - U * 0.8 + L * 0.2, "LeftLeg": -U - F * 0.9,
             "RightFoot": F - U * 0.3, "LeftFoot": F - U * 0.3}

def P(**kw):
    d = dict(legs_stand)
    d.update(kw.pop("legs", {}))
    d.update(kw)
    return d

shield_front = {"LeftArm": -U * 0.7 + F * 0.6 + L * 0.35, "LeftForeArm": F + R * 0.45 + U * 0.15}
shield_side = {"LeftArm": -U + L * 0.35 + F * 0.15, "LeftForeArm": -U * 0.4 + F + L * 0.1}

idle = P(RightArm=-U + R * 0.35 + F * 0.15, RightForeArm=F * 0.8 - U * 0.5 + R * 0.1, weapon=F * 0.5 + U * 0.75 + R * 0.15,
         **shield_front)
windup = P(RightArm=U * 0.9 + R * 0.4 - F * 0.25, RightForeArm=U * 0.2 - F * 0.9 + L * 0.2, weapon=-F * 0.5 - U * 0.85,
           body=[("Spine", (U, 0.35)), ("Spine1", (LEAN, -0.15))], **shield_front)
strike = P(RightArm=F * 0.95 - U * 0.25 + R * 0.05, RightForeArm=F * 0.85 - U * 0.5, weapon=F * 0.55 - U * 0.85,
           body=[("Spine", (U, -0.45)), ("Spine1", (LEAN, 0.4))], legs=legs_lunge, **shield_side)
bash = P(RightArm=-U + R * 0.45 - F * 0.3, RightForeArm=-U * 0.3 + F * 0.6 + R * 0.4, weapon=-F * 0.3 - U * 0.9 + R * 0.3,
         LeftArm=F - U * 0.15 + L * 0.15, LeftForeArm=F + U * 0.05,
         body=[("Spine", (U, -0.5)), ("Spine1", (LEAN, 0.25))], legs=legs_lunge)

if SIDE == "w":
    make("slash", [(0, idle), (9, windup), (14, windup), (18, strike), (32, strike), (44, idle)])
    make("bash", [(0, idle), (5, bash), (14, bash), (24, idle)])
else:
    big_wind = P(RightArm=U + R * 0.15 - F * 0.35, RightForeArm=U * 0.1 - F * 0.95, weapon=-F * 0.3 - U * 0.95,
                 body=[("Spine1", (LEAN, -0.25))], legs=legs_tuck, **shield_side)
    prep = P(RightArm=-U + R * 0.4 - F * 0.4, RightForeArm=-U * 0.4 - F * 0.6, weapon=-F * 0.7 - U * 0.5 + R * 0.2,
             body=[("Spine1", (LEAN, 0.3))], legs=legs_crouch, **shield_side)
    slam = P(RightArm=F * 0.9 - U * 0.45, RightForeArm=F * 0.5 - U * 0.85, weapon=F * 0.25 - U * 0.97,
             body=[("Spine1", (LEAN, 0.55)), ("Spine", (U, -0.2))], legs=legs_crouch, **shield_side)
    make("slash", [(0, idle), (8, prep), (14, big_wind), (26, big_wind), (31, slam), (46, slam), (58, idle)])
    make("bash", [(0, idle), (5, bash), (14, bash), (24, idle)])
make("idle", [(0, idle), (30, idle)])

for a in bpy.data.actions:
    a.use_fake_user = True
arm.animation_data.action = bpy.data.actions["walk"]

# --- превью: рендер ключевых поз ---
if "--preview" in sys.argv:
    sc = bpy.context.scene
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera = cam
    for loc in ((3, -4, 4), (-3, 4, 4), (0, -5, 1), (4, 0, 2)):
        l = bpy.data.objects.new("l", bpy.data.lights.new("l", "POINT")); l.data.energy = 1500; l.location = loc; sc.collection.objects.link(l)
    sc.render.engine = "CYCLES"; sc.cycles.samples = 8; sc.render.resolution_x = 320; sc.render.resolution_y = 420
    shots = [("idle", 0), ("slash", 14 if SIDE == "w" else 20), ("slash", 18 if SIDE == "w" else 31), ("bash", 5)]
    for i, (an, fr) in enumerate(shots):
        arm.animation_data.action = bpy.data.actions[an]
        sc.frame_set(fr)
        for j, cl in enumerate(((3.2, -1.2, 1.1), (0.4, -3.4, 1.1))):
            cam.location = cl
            d = Vector((0.1, -0.2, 0.9)) - cam.location
            cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = f"/tmp/claude-0/atk_{SIDE}_{i}_{j}.png"
            bpy.ops.render.render(write_still=True)
    arm.animation_data.action = bpy.data.actions["walk"]

for o in bpy.context.scene.objects:
    o.select_set(o in (arm, me))
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_skins=True,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_image_format="JPEG", export_jpeg_quality=88)
print("WROTE", DST)
