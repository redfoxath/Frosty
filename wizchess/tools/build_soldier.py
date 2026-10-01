"""Модели солдата-пешки (белый и чёрный) для «Живых шахмат».
Запуск: python build_soldier.py <out_dir>
Каждая часть тела — отдельный объект внутри пустышки-шарнира с тем же именем,
что ждёт игра (hips, torso, head, arm_r, fore_r, hand_r, leg_r, shin_r, ...).
Blender: Z вверх, персонаж смотрит в +Y (в Godot это -Z)."""
import bpy, bmesh, sys, os
from math import cos, sin, pi, radians
from mathutils import Vector, Matrix

OUT = sys.argv[-1] if len(sys.argv) > 1 else "."

# ---------------- сцена ----------------
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, col, metal=0.0, rough=0.5, emit=None, strength=0.0):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m

def empty(name, parent=None, loc=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    return o

def finish(name, bm, m, parent, loc=(0, 0, 0), subd=2, smooth=True, solid=0.0, bevel=0.0, rot=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    o.parent = parent
    o.location = loc
    o.rotation_euler = rot
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    if solid:
        md = o.modifiers.new("solid", "SOLIDIFY")
        md.thickness = solid
        md.offset = 0
    if bevel:
        md = o.modifiers.new("bevel", "BEVEL")
        md.width = bevel
        md.segments = 2
    if subd:
        md = o.modifiers.new("subd", "SUBSURF")
        md.levels = subd
        md.render_levels = subd
    return o

def loft(name, rings, m, parent, segs=16, cap0=True, cap1=True, **kw):
    """rings: (z, rx, ry[, cx, cy]) — эллипсы вдоль оси Z."""
    bm = bmesh.new()
    loops = []
    for r in rings:
        z, rx, ry = r[0], r[1], r[2]
        cx = r[3] if len(r) > 3 else 0.0
        cy = r[4] if len(r) > 4 else 0.0
        loops.append([bm.verts.new((cx + rx * cos(2 * pi * i / segs), cy + ry * sin(2 * pi * i / segs), z)) for i in range(segs)])
    for a, b in zip(loops, loops[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for cap, ring in ((cap0, loops[0]), (cap1, loops[-1])):
        if cap:
            c = sum((v.co for v in ring), Vector()) / segs
            cv = bm.verts.new(c)
            for i in range(segs):
                bm.faces.new((ring[i], ring[(i + 1) % segs], cv))
    return finish(name, bm, m, parent, **kw)

def tube(name, pts, radii, m, parent, segs=10, **kw):
    """Труба вдоль ломаной pts с радиусами radii (рога, гарда, кромка щита)."""
    bm = bmesh.new()
    loops = []
    n = len(pts)
    pts = [Vector(p) for p in pts]
    for k, p in enumerate(pts):
        t = (pts[min(k + 1, n - 1)] - pts[max(k - 1, 0)]).normalized()
        up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        a = t.cross(up).normalized()
        b = t.cross(a).normalized()
        r = radii[k]
        loops.append([bm.verts.new(p + (a * cos(2 * pi * i / segs) + b * sin(2 * pi * i / segs)) * r) for i in range(segs)])
    for A, B in zip(loops, loops[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((A[i], A[j], B[j], B[i]))
    for ring, p in ((loops[0], pts[0]), (loops[-1], pts[-1])):
        cv = bm.verts.new(p)
        for i in range(segs):
            bm.faces.new((ring[i], ring[(i + 1) % segs], cv))
    return finish(name, bm, m, parent, **kw)

def sphere(name, r, m, parent, loc=(0, 0, 0), scale=(1, 1, 1), subd=1):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return finish(name, bm, m, parent, loc=loc, subd=subd)

def box(name, size, m, parent, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.004, subd=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    return finish(name, bm, m, parent, loc=loc, rot=rot, subd=subd, smooth=False, bevel=bevel)

def plate(name, outline, m, parent, thick=0.02, curve=0.0, **kw):
    """Плоская фигура по контуру в плоскости XZ (выдавлена по Y), с изгибом y = -curve*x²."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, -curve * x * x, z)) for x, z in outline]
    bm.faces.new(vs)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    o = finish(name, bm, m, parent, subd=0, smooth=False, solid=thick, **kw)
    return o

# ---------------- солдат ----------------
def build(side):
    reset()
    W = side == "w"
    steel = mat("steel_w", (0.86, 0.88, 0.92), 0.6, 0.28) if W else mat("iron_b", (0.16, 0.15, 0.18), 0.6, 0.35)
    steel2 = mat("steel_dark_w", (0.6, 0.62, 0.68), 0.6, 0.32) if W else mat("iron_b2", (0.09, 0.085, 0.1), 0.6, 0.42)
    trim = mat("gold", (0.86, 0.62, 0.20), 1.0, 0.28) if W else mat("crimson_metal", (0.55, 0.04, 0.08), 0.7, 0.35)
    cloth = mat("tabard_blue", (0.08, 0.17, 0.52), 0.0, 0.85) if W else mat("tabard_red", (0.38, 0.02, 0.06), 0.0, 0.85)
    under = mat("gambeson", (0.62, 0.58, 0.50), 0.0, 0.95) if W else mat("under_b", (0.09, 0.07, 0.08), 0.0, 0.95)
    leather = mat("leather", (0.22, 0.12, 0.06), 0.0, 0.65)
    dark = mat("void", (0.01, 0.01, 0.015), 0.0, 1.0)
    eye = mat("eye_w", (0.5, 0.9, 1.0), 0, 0.5, (0.5, 0.9, 1.0), 8.0) if W else mat("eye_b", (1.0, 0.1, 0.15), 0, 0.5, (1.0, 0.1, 0.15), 8.0)
    plume = mat("plume", (0.95, 0.94, 0.9), 0.0, 0.9)
    fur = mat("fur", (0.12, 0.08, 0.06), 0.0, 1.0)
    bone = mat("horn", (0.85, 0.80, 0.68), 0.0, 0.45)

    root = empty("soldier_" + side)
    body = empty("body", root)
    hips = empty("hips", body, (0, 0, 0.95))
    torso = empty("torso", hips)
    head = empty("head", torso, (0, 0, 0.68))

    # --- корпус ---
    loft("t_under", [(-0.04, .165, .115), (0.1, .16, .11), (0.26, .17, .115), (0.42, .2, .125), (0.54, .2, .115), (0.62, .12, .09), (0.66, .055, .055)], under, torso)
    loft("t_breast", [(0.16, .178, .128, 0, .006), (0.3, .195, .14, 0, .012), (0.43, .218, .15, 0, .014), (0.53, .218, .138), (0.6, .15, .105)], steel, torso, cap0=False, cap1=False, solid=0.014)
    loft("t_gorget", [(0.55, .13, .1), (0.6, .12, .095), (0.65, .085, .08), (0.69, .075, .072)], steel2, torso, cap0=False, cap1=False, solid=0.01)
    for i, z in enumerate((0.12, 0.06, 0.0)):
        loft(f"t_fauld{i}", [(z + 0.035, .182 + i * .012, .132 + i * .01), (z - 0.03, .195 + i * .013, .145 + i * .011)], steel, torso, cap0=False, cap1=False, solid=0.01, subd=1)
    loft("t_belt", [(0.17, .186, .136), (0.13, .186, .136)], leather, torso, cap0=False, cap1=False, solid=0.012, subd=1)
    box("t_buckle", (0.06, 0.02, 0.05), trim, torso, (0, .14, .15))
    # сюрко (накидка) поверх лат
    sur = [(-.13, .5), (.13, .5), (.15, .2), (.14, -.12), (.1, -.2), (0, -.24), (-.1, -.2), (-.14, -.12), (-.15, .2)]
    plate("t_tabard", sur, cloth, torso, thick=0.012, curve=1.4, loc=(0, .2, 0))
    plate("t_tabard_b", sur, cloth, torso, thick=0.012, curve=-1.4, loc=(0, -.2, 0))
    if W:
        box("t_emb_v", (0.035, 0.012, 0.26), trim, torso, (0, .21, .2))
        box("t_emb_h", (0.17, 0.012, 0.035), trim, torso, (0, .21, .27))
    else:
        tube("t_emb", [(-.06, .212, .34), (0, .212, .16), (.06, .212, .34)], [.014, .014, .014], trim, torso, segs=6, subd=1)
        loft("t_fur", [(0.6, .2, .14), (0.66, .19, .15), (0.7, .14, .12)], fur, torso, cap0=False, cap1=False, solid=0.04, subd=2)

    # --- голова и шлем ---
    loft("h_face", [(-0.02, .09, .1), (0.1, .11, .12), (0.2, .09, .1), (0.25, .02, .02)], under, head)
    if W:
        loft("h_helm", [(-0.07, .125, .14), (0.0, .135, .15), (0.1, .142, .155), (0.19, .133, .145), (0.25, .1, .11), (0.29, .05, .055), (0.3, .005, .005)], steel, head, cap0=False, solid=0.01)
        loft("h_plume", [(0.26, .02, .1, 0, -0.01), (0.34, .03, .16, 0, -0.05), (0.42, .028, .2, 0, -0.1), (0.48, .018, .17, 0, -0.18), (0.5, .006, .08, 0, -0.26)], plume, head)
        tube("h_crest", [(0, .13, .22), (0, .05, .3), (0, -.05, .3), (0, -.13, .22)], [.012] * 4, trim, head, segs=6, subd=1)
    else:
        loft("h_helm", [(-0.06, .13, .14), (0.02, .14, .15), (0.12, .145, .152), (0.22, .125, .13), (0.28, .07, .075), (0.31, .01, .01)], steel, head, cap0=False, solid=0.01)
        for s in (-1, 1):
            pts = [(s * .12, 0, .16), (s * .2, 0, .19), (s * .27, 0, .26), (s * .3, 0, .35), (s * .28, 0, .43)]
            tube(f"h_horn{'r' if s > 0 else 'l'}", pts, [.04, .034, .026, .016, .003], bone, head, segs=10, subd=1)
    box("h_slit", (0.2, 0.03, 0.024), dark, head, (0, .14, .11))
    box("h_nose", (0.022, 0.03, 0.12), steel2, head, (0, .155, .06))
    for s in (-1, 1):
        sphere(f"h_eye{'r' if s > 0 else 'l'}", .016, eye, head, (s * .045, .125, .11))
    loft("h_cheek", [(-0.07, .136, .15, 0, .0), (0.05, .14, .155, 0, .005)], steel2, head, cap0=False, cap1=False, solid=0.012, subd=1)

    # --- руки ---
    for s, sn in ((1, "r"), (-1, "l")):
        arm = empty("arm_" + sn, torso, (s * .27, 0, .54))
        loft(f"a{sn}_sleeve", [(0.04, .06, .06), (-0.12, .058, .058), (-0.3, .052, .052)], under, arm)
        loft(f"a{sn}_pauldron", [(0.1, .02, .02, s * .02), (0.08, .085, .085, s * .025), (0.03, .125, .118, s * .03), (-0.04, .135, .125, s * .03), (-0.1, .128, .12, s * .028)], steel, arm, cap1=False, solid=0.012)
        loft(f"a{sn}_lame", [(-0.1, .11, .1, s * .02), (-0.15, .1, .095, s * .018)], trim if W else steel2, arm, cap0=False, cap1=False, solid=0.01, subd=1)
        if not W:
            for k, ang in enumerate((-30, 15, 60)):
                a = radians(ang)
                tube(f"a{sn}_spike{k}", [(s * .1, .0, .06 - k * .02), (s * (.1 + .08 * cos(a)), .07 * sin(a), .14 - k * .02)], [.025, .002], steel2, arm, segs=8, subd=0)
        loft(f"a{sn}_rere", [(-0.13, .065, .065), (-0.28, .06, .06)], steel, arm, cap0=False, cap1=False, solid=0.01)
        fore = empty("fore_" + sn, arm, (0, 0, -0.30))
        sphere(f"f{sn}_cop", .062, steel2, fore, (0, -.015, 0), (1.0, 1.0, 0.9))
        loft(f"f{sn}_vamb", [(-0.02, .057, .057), (-0.14, .055, .052), (-0.23, .063, .06)], steel, fore, cap0=False, cap1=False, solid=0.01)
        loft(f"f{sn}_arm", [(0.0, .045, .045), (-0.28, .04, .04)], under, fore)
        hand = empty("hand_" + sn, fore, (0, 0, -0.31))
        loft(f"g{sn}_cuff", [(0.08, .062, .06), (0.02, .075, .07)], steel2, hand, cap0=False, cap1=False, solid=0.008, subd=1)
        loft(f"g{sn}_fist", [(0.03, .045, .05), (-0.02, .05, .058, 0, .005), (-0.07, .048, .055, 0, .008), (-0.1, .03, .035, 0, .006)], steel2, hand)
        sphere(f"g{sn}_thumb", .022, steel2, hand, (-s * .04, .03, -0.01), (0.8, 1.3, 1.0))

    # --- ноги ---
    loft("p_pelvis", [(0.08, .17, .12), (-0.04, .17, .125), (-0.12, .13, .1)], under, hips)
    for s, sn in ((1, "r"), (-1, "l")):
        leg = empty("leg_" + sn, hips, (s * .11, 0, 0))
        loft(f"l{sn}_thigh", [(0.02, .09, .09), (-0.22, .08, .08), (-0.45, .065, .065)], under, leg)
        loft(f"l{sn}_cuisse", [(-0.06, .094, .095, 0, .006), (-0.22, .087, .09, 0, .008), (-0.37, .074, .078, 0, .006)], steel, leg, cap0=False, cap1=False, solid=0.01)
        shin = empty("shin_" + sn, leg, (0, 0, -0.45))
        sphere(f"s{sn}_knee", .062, steel2, shin, (0, .03, 0.0), (1.0, 0.8, 1.0))
        loft(f"s{sn}_greave", [(-0.03, .066, .068), (-0.18, .063, .066, 0, .004), (-0.38, .05, .055)], steel, shin, cap0=False, cap1=False, solid=0.01)
        loft(f"s{sn}_leg", [(0.0, .055, .055), (-0.42, .045, .045)], under, shin)
        loft(f"s{sn}_boot", [(-0.38, .056, .06, 0, .0), (-0.42, .06, .075, 0, .02), (-0.46, .062, .12, 0, .06), (-0.5, .058, .125, 0, .07), (-0.505, .03, .06, 0, .07)], steel2 if W else leather, shin)

    # --- оружие (рукоять в начале координат, клинок вдоль -Z) ---
    wm = empty("w_main", root, (0, 0, 0))
    if W:
        loft("sw_grip", [(0.11, .017, .017), (-0.1, .019, .019)], leather, wm, subd=1)
        for k in range(5):
            loft(f"sw_wrap{k}", [(0.08 - k * .04 + .006, .021, .021), (0.08 - k * .04 - .006, .021, .021)], trim, wm, cap0=False, cap1=False, solid=0.004, subd=0)
        sphere("sw_pommel", .033, trim, wm, (0, 0, .135), (1, .7, 1))
        tube("sw_guard", [(-.16, 0, -.08), (-.08, 0, -.115), (0, 0, -.12), (.08, 0, -.115), (.16, 0, -.08)], [.012, .016, .02, .016, .012], trim, wm, segs=8, subd=1)
        loft("sw_blade", [(-0.12, .036, .009), (-0.5, .033, .008), (-0.9, .028, .007), (-1.0, .015, .005), (-1.06, .001, .001)], mat("blade", (0.92, 0.94, 0.97), 1.0, 0.12), wm, segs=8, subd=0, smooth=True)
        box("sw_fuller", (0.012, 0.0182, 0.7), mat("blade_glow", (0.6, 0.9, 1), 0, .4, (0.55, 0.88, 1.0), 4.0), wm, (0, 0, -0.5), bevel=0)
        # щит-«геральдический»
        off = empty("w_off", root, (0, 0, 0))
        outline = [(-.19, .24)]
        for k in range(1, 13):
            t = k / 12
            outline.append((-0.19 * (1 - t ** 2.2), 0.24 - 0.56 * t))
        for k in range(11, -1, -1):
            t = k / 12
            outline.append((0.19 * (1 - t ** 2.2), 0.24 - 0.56 * t))
        plate("sh_face", outline, cloth, off, thick=0.03, curve=0.9)
        rim = [(x * 1.0, -0.9 * x * x + 0.0, z) for x, z in outline] + [(outline[0][0], -0.9 * outline[0][0] ** 2, outline[0][1])]
        tube("sh_rim", [(x, y + .0, z) for x, y, z in rim], [.014] * len(rim), trim, off, segs=6, subd=0)
        box("sh_band_v", (0.04, 0.02, 0.5), trim, off, (0, .025, -0.03))
        box("sh_band_h", (0.34, 0.02, 0.04), trim, off, (0, .022, 0.1))
        sphere("sh_boss", .045, steel, off, (0, .035, 0.1), (1, .6, 1))
    else:
        loft("ax_haft", [(0.12, .022, .022), (-0.6, .026, .026), (-1.18, .028, .028)], mat("wood_dark", (0.12, 0.07, 0.04), 0, 0.7), wm, subd=1)
        for k in range(3):
            loft(f"ax_wrap{k}", [(0.08 - k * .06 + .02, .03, .03), (0.08 - k * .06 - .02, .03, .03)], leather, wm, cap0=False, cap1=False, solid=0.004, subd=0)
        loft("ax_socket", [(-0.92, .04, .045), (-1.12, .04, .045)], steel2, wm, subd=1)
        # полумесяц лезвия в плоскости YZ, остриём к +Y
        blade = []
        for k in range(15):
            a = -pi / 2 + pi * k / 14
            blade.append((0.12 + 0.3 * cos(a) ** 0.8, -1.02 + 0.27 * sin(a)))
        inner = [(0.12, -0.86), (0.05, -0.94), (0.05, -1.1), (0.12, -1.18)]
        ol = [(y, z) for y, z in blade] + inner[::-1]
        bm = bmesh.new()
        vs = [bm.verts.new((0, y, z)) for y, z in ol]
        bm.faces.new(vs)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        finish("ax_blade", bm, steel, wm, subd=0, smooth=False, solid=0.022, bevel=0.006)
        tube("ax_edge", [(0, 0.12 + 0.3 * cos(-pi / 2 + pi * k / 14) ** 0.8 + 0.004, -1.02 + 0.27 * sin(-pi / 2 + pi * k / 14)) for k in range(15)], [.006] * 15, mat("edge_glow_b", (1, .2, .1), 0, .4, (1.0, 0.25, 0.1), 5.0), wm, segs=6, subd=0)
        tube("ax_spike", [(0, -.04, -1.02), (0, -.24, -1.02)], [.035, .002], steel2, wm, segs=8, subd=0)

    # --- экспорт ---
    for o in bpy.context.scene.objects:
        o.select_set(True)
    path = os.path.join(OUT, f"soldier_{side}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True)
    print("WROTE", path, len(bpy.data.objects))

for side in ("w", "b"):
    build(side)
