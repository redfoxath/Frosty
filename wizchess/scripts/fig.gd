class_name Fig
extends RefCounted
## Процедурные модели: шахматные фигуры, гуманоиды, оружие, трон, череп.
## Все фигуры и персонажи смотрят в сторону -Z.

static var _mats := {}

# ---------- материалы ----------
static func mat(key: String, col: Color, metal := 0.0, rough := 0.5, emit := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := new_mat(col, metal, rough, emit, energy)
	_mats[key] = m
	return m

static func new_mat(col: Color, metal := 0.0, rough := 0.5, emit := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m

## Полированный мрамор (белый — слоновая кость, иначе чёрный) с трипланарной разверткой
static func marble(white: bool, rough := 0.2, scale := 1.0, world := false) -> StandardMaterial3D:
	var key := "marble_%s_%.2f_%.2f_%s" % [white, rough, scale, world]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/marble_white.jpg" if white else "res://textures/marble_black.jpg")
	m.roughness = rough
	m.metallic_specular = 0.75
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m

static func glow(col: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "glow" + col.to_html() + str(energy)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col * energy
	m.albedo_color.a = 1.0
	_mats[key] = m
	return m

static func fx_mat(col: Color, add := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = col
	return m

# ---------- меши ----------
static func box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

static func cyl(top: float, bot: float, h: float, seg := 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bot
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m

static func sph(r: float, seg := 18) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = int(seg / 2.0)
	return m

static func cap(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = max(h, r * 2.0 + 0.001)
	m.radial_segments = 12
	m.rings = 4
	return m

static func cone(r: float, h: float, seg := 12) -> CylinderMesh:
	return cyl(0.0, r, h, seg)

static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 8
	return m

static func mi(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation = rot
	n.scale = scl
	parent.add_child(n)
	return n

static func node(parent: Node3D, pos := Vector3.ZERO, nm := "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if nm != "":
		n.name = nm
	parent.add_child(n)
	return n

static func lathe(parent: Node3D, pts: Array, m: Material) -> void:
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var h: float = b[1] - a[1]
		if h < 0.001:
			continue
		mi(parent, cyl(b[0], a[0], h, 28), m, Vector3(0, a[1] + h / 2.0, 0))

# ---------- палитры ----------
static func side_cols(c: int) -> Dictionary:
	if c == 1:
		return {"a": Color("ffcf5a"), "b": Color("8fe3ff"), "deep": Color("5a3a08"), "eye": Color("8fe3ff")}
	return {"a": Color("ff3d5a"), "b": Color("c27bff"), "deep": Color("3d0712"), "eye": Color("ff2a48")}

# ---------- шахматная фигура ----------
const BASE := [[0.0, 0.0], [0.4, 0.0], [0.41, 0.04], [0.4, 0.1], [0.33, 0.14], [0.3, 0.18]]

## Пешка на доске — живой рыцарь (своя копия материалов, чтобы свечение не перекидывалось на соседей)
static func board_pawn(c: int) -> Node3D:
	return board_rigged(Rules.P, c, "res://models/pawn_w.glb" if c == 1 else "res://models/pawn_b.glb", 1.75 if c == 1 else 1.8, 1.2)

static func board_rigged(t: int, c: int, path: String, raw_h: float, height: float) -> Node3D:
	var g := Node3D.new()
	var body := node(g, Vector3.ZERO, "body")
	var form := rigged(path, 0.0, raw_h, height)
	body.add_child(form)
	var first: BaseMaterial3D = null
	for mi_ in form.find_children("*", "MeshInstance3D", true, false):
		var mesh_i := mi_ as MeshInstance3D
		for si in mesh_i.mesh.get_surface_count():
			var m0 := mesh_i.get_active_material(si)
			if m0 is BaseMaterial3D:
				var m := (m0 as BaseMaterial3D).duplicate() as BaseMaterial3D
				mesh_i.set_surface_override_material(si, m)
				if first == null:
					first = m
	# анимация играет только внутри дерева сцены: включаем стойку, когда фигура окажется на доске,
	# иначе модель остаётся в позе скелета по умолчанию (у слона это Т-поза)
	form.ready.connect(func(): play_anim(form, "idle"), CONNECT_ONE_SHOT)
	g.set_meta("t", t)
	g.set_meta("c", c)
	g.set_meta("m", first)
	g.set_meta("tr", first)
	g.set_meta("form", form)
	g.set_meta("face", 0.0 if c == 1 else PI)
	g.set_meta("bob", randf() * 6.0)
	g.set_meta("h", height)
	g.rotation.y = g.get_meta("face")
	return g

static func piece(t: int, c: int) -> Node3D:
	if t == Rules.P:
		return board_pawn(c)
	if t == Rules.B:
		return board_rigged(Rules.B, c, "res://models/bishop_w.glb" if c == 1 else "res://models/bishop_b.glb", 1.8, 1.55)
	if t == Rules.N:
		return board_rigged(Rules.N, c, "res://models/knight_w.glb" if c == 1 else "res://models/knight_b.glb", 1.81, 1.35)
	var g := Node3D.new()
	var body := node(g, Vector3.ZERO, "body")
	var m: StandardMaterial3D
	var tr: StandardMaterial3D
	if c == 1:
		m = marble(true, 0.24, 1.6)
		tr = new_mat(Color("d8a63c"), 0.85, 0.28)
	else:
		m = marble(false, 0.16, 1.6).duplicate()
		m.emission_enabled = true
		m.emission = Color("1a0309")
		tr = new_mat(Color("9c1830"), 0.6, 0.25, Color("3a0010"), 1.0)
	var eye := glow(side_cols(c).eye, 4.0)
	var ey := 0.7
	var ez := -0.15
	var ex := 0.065
	match t:
		Rules.P:
			lathe(body, BASE + [[0.22, 0.28], [0.13, 0.42], [0.11, 0.5], [0.2, 0.54], [0.2, 0.58], [0.1, 0.62]], m)
			mi(body, sph(0.17), m, Vector3(0, 0.76, 0))
			mi(body, torus(0.18, 0.22), tr, Vector3(0, 0.56, 0))
			ey = 0.78
		Rules.R:
			lathe(body, BASE + [[0.27, 0.3], [0.25, 0.75], [0.32, 0.8], [0.32, 0.98]], m)
			mi(body, torus(0.3, 0.34), tr, Vector3(0, 0.8, 0))
			for i in 5:
				var a := i / 5.0 * TAU
				mi(body, box(0.14, 0.16, 0.12), m, Vector3(sin(a) * 0.25, 1.06, cos(a) * 0.25), Vector3(0, a, 0))
			ey = 0.88
			ez = -0.31
			ex = 0.09
		Rules.N:
			lathe(body, BASE + [[0.27, 0.3], [0.28, 0.36]], m)
			mi(body, box(0.3, 0.62, 0.36), m, Vector3(0, 0.62, 0.04), Vector3(0.25, 0, 0))
			mi(body, box(0.26, 0.24, 0.56), m, Vector3(0, 0.92, -0.14), Vector3(-0.25, 0, 0))
			mi(body, box(0.2, 0.16, 0.2), m, Vector3(0, 0.82, -0.4), Vector3(-0.1, 0, 0))
			for s in [-1, 1]:
				mi(body, cone(0.06, 0.18, 6), m, Vector3(s * 0.08, 1.1, 0.04), Vector3(-0.2, 0, 0))
			mi(body, box(0.06, 0.6, 0.16), tr, Vector3(0, 0.84, 0.22), Vector3(0.4, 0, 0))
			ey = 0.98
			ez = -0.22
			ex = 0.135
		Rules.B:
			lathe(body, BASE + [[0.24, 0.28], [0.13, 0.62], [0.23, 0.66], [0.23, 0.7], [0.12, 0.74]], m)
			mi(body, sph(0.2), m, Vector3(0, 0.95, 0), Vector3.ZERO, Vector3(0.9, 1.35, 0.9))
			mi(body, sph(0.06), tr, Vector3(0, 1.25, 0))
			mi(body, box(0.03, 0.2, 0.3), tr, Vector3(0.06, 1.0, -0.04), Vector3(0, 0, 0.6))
			mi(body, torus(0.2, 0.24), tr, Vector3(0, 0.68, 0))
			ey = 0.92
			ez = -0.17
		Rules.Q:
			lathe(body, BASE + [[0.26, 0.3], [0.14, 0.84], [0.26, 0.9], [0.26, 0.95], [0.15, 1.0], [0.22, 1.14]], m)
			mi(body, torus(0.24, 0.28), tr, Vector3(0, 0.92, 0))
			for i in 8:
				var a := i / 8.0 * TAU
				mi(body, sph(0.045, 10), tr, Vector3(sin(a) * 0.21, 1.16, cos(a) * 0.21))
			mi(body, sph(0.08), tr, Vector3(0, 1.22, 0))
			ey = 1.04
			ez = -0.17
			ex = 0.06
		Rules.K:
			lathe(body, BASE + [[0.27, 0.3], [0.15, 0.9], [0.27, 0.96], [0.27, 1.0], [0.16, 1.04], [0.22, 1.16]], m)
			mi(body, torus(0.25, 0.29), tr, Vector3(0, 0.98, 0))
			mi(body, box(0.08, 0.34, 0.08), tr, Vector3(0, 1.32, 0))
			mi(body, box(0.26, 0.08, 0.08), tr, Vector3(0, 1.36, 0))
			ey = 1.1
			ez = -0.19
			ex = 0.07
	for s in [-1, 1]:
		mi(body, sph(0.028, 8), eye, Vector3(s * ex, ey, ez))
	for ch in body.get_children():
		if ch is MeshInstance3D:
			ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	g.set_meta("t", t)
	g.set_meta("c", c)
	g.set_meta("m", m)
	g.set_meta("tr", tr)
	g.set_meta("face", 0.0 if c == 1 else PI)
	g.set_meta("bob", randf() * 6.0)
	g.set_meta("h", {1: 0.95, 2: 1.15, 3: 1.3, 4: 1.15, 5: 1.3, 6: 1.45}[t])
	g.rotation.y = g.get_meta("face")
	return g

# ---------- гуманоид ----------
## o: skin, cloth, armor (материалы), w (ширина), head ("human"/"horse"/"none")
static func humanoid(o: Dictionary) -> Node3D:
	var root := Node3D.new()
	var skin: Material = o.get("skin", mat("skin", Color("d9a982"), 0, 0.7))
	var cloth: Material = o.get("cloth", mat("cloth", Color("3a3f6b"), 0, 0.8))
	var armor: Material = o.get("armor", mat("steel", Color("b9bec8"), 0.9, 0.3))
	var w: float = o.get("w", 1.0)
	var p := {}
	var hips := node(root, Vector3(0, 0.95, 0), "hips")
	p.hips = hips
	var torso := node(hips, Vector3.ZERO, "torso")
	p.torso = torso
	mi(torso, box(0.44 * w, 0.5, 0.26), armor, Vector3(0, 0.36, 0))
	mi(torso, box(0.38 * w, 0.2, 0.23), cloth, Vector3(0, 0.05, 0))
	mi(torso, box(0.4 * w, 0.06, 0.25), o.get("belt", mat("belt", Color("4a3020"), 0, 0.6)), Vector3(0, 0.15, 0))
	mi(torso, cyl(0.06, 0.07, 0.1), skin, Vector3(0, 0.64, 0))
	var head := node(torso, Vector3(0, 0.68, 0), "head")
	p.head = head
	var hk: String = o.get("head", "human")
	if hk == "human":
		mi(head, sph(0.13), skin, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(0.95, 1.08, 1.0))
	elif hk == "horse":
		var hm: Material = o.get("horse", skin)
		mi(head, box(0.22, 0.26, 0.3), hm, Vector3(0, 0.15, 0.02))
		mi(head, box(0.17, 0.19, 0.34), hm, Vector3(0, 0.08, -0.26), Vector3(0.25, 0, 0))
		mi(head, box(0.14, 0.05, 0.12), mat("dark", Color("100c12"), 0, 0.9), Vector3(0, 0.0, -0.42), Vector3(0.25, 0, 0))
		for s in [-1, 1]:
			mi(head, cone(0.045, 0.16, 6), hm, Vector3(s * 0.07, 0.35, 0.08), Vector3(-0.15, 0, s * 0.15))
			mi(head, sph(0.03, 8), glow(o.get("eye", Color("8fe3ff")), 5.0), Vector3(s * 0.115, 0.2, -0.06))
		mi(head, box(0.06, 0.42, 0.12), o.get("mane", cloth), Vector3(0, 0.12, 0.2), Vector3(0.2, 0, 0))
		p.mane_anchor = head
	for side in [-1, 1]:
		var sn := "r" if side == 1 else "l"
		var sh := node(torso, Vector3(0.27 * w * side, 0.54, 0), "arm_" + sn)
		mi(sh, sph(0.1), armor, Vector3(side * 0.02, 0, 0), Vector3.ZERO, Vector3(1.1, 0.9, 1.0))
		mi(sh, cap(0.065, 0.34), cloth, Vector3(0, -0.15, 0))
		var el := node(sh, Vector3(0, -0.3, 0), "fore_" + sn)
		mi(el, cap(0.06, 0.32), armor, Vector3(0, -0.14, 0))
		var hand := node(el, Vector3(0, -0.31, 0), "hand_" + sn)
		mi(hand, sph(0.06, 10), o.get("glove", skin))
		p["arm_" + sn] = sh
		p["fore_" + sn] = el
		p["hand_" + sn] = hand
		var hp := node(hips, Vector3(0.11 * side, 0, 0), "leg_" + sn)
		mi(hp, cap(0.085, 0.48), cloth, Vector3(0, -0.22, 0))
		var kn := node(hp, Vector3(0, -0.45, 0), "shin_" + sn)
		mi(kn, cap(0.075, 0.46), armor, Vector3(0, -0.22, 0))
		mi(kn, box(0.12, 0.08, 0.26), o.get("boot", mat("boot", Color("2a2026"), 0.2, 0.6)), Vector3(0, -0.46, -0.05))
		p["leg_" + sn] = hp
		p["shin_" + sn] = kn
	root.set_meta("p", p)
	_shadows(root)
	return root

static func _shadows(n: Node) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_shadows(ch)

static func P_(fig: Node3D) -> Dictionary:
	return fig.get_meta("p")

## Плавная поза: pose = {"arm_r": Vector3(...), ...}
static func pose(fig: Node3D, ps: Dictionary, dur: float, trans := Tween.TRANS_CUBIC, ease := Tween.EASE_OUT) -> Tween:
	var p := P_(fig)
	var tw := fig.create_tween().set_parallel(true).set_trans(trans).set_ease(ease)
	for k in ps:
		if p.has(k):
			tw.tween_property(p[k], "rotation", ps[k], dur)
	return tw

static func set_pose(fig: Node3D, ps: Dictionary) -> void:
	var p := P_(fig)
	for k in ps:
		if p.has(k):
			p[k].rotation = ps[k]

# ---------- оружие (рукоять в начале координат, клинок вдоль -Y) ----------
static func sword(c: int, length := 1.0) -> Node3D:
	var n := Node3D.new()
	var steel := mat("blade", Color("dfe6f0"), 1.0, 0.15)
	var gold := mat("gold", Color("d8a63c"), 0.9, 0.3)
	mi(n, cyl(0.025, 0.025, 0.22), mat("grip", Color("3a2418"), 0, 0.8), Vector3(0, 0.0, 0))
	mi(n, box(0.3, 0.04, 0.06), gold, Vector3(0, -0.12, 0))
	mi(n, box(0.07, length, 0.018), steel, Vector3(0, -0.14 - length / 2.0, 0))
	mi(n, box(0.02, length * 0.95, 0.02), glow(side_cols(c).b, 3.0), Vector3(0, -0.14 - length / 2.0, 0))
	mi(n, sph(0.04, 8), gold, Vector3(0, 0.13, 0))
	return n

static func shield(c: int) -> Node3D:
	var n := Node3D.new()
	var face := mat("shield" + str(c), Color("2b4fa8") if c == 1 else Color("5a0f1c"), 0.3, 0.5)
	var rim := mat("gold", Color("d8a63c"), 0.9, 0.3)
	mi(n, box(0.36, 0.46, 0.05), face, Vector3.ZERO)
	mi(n, box(0.4, 0.04, 0.07), rim, Vector3(0, 0.23, 0))
	mi(n, box(0.4, 0.04, 0.07), rim, Vector3(0, -0.23, 0))
	mi(n, box(0.05, 0.44, 0.07), rim, Vector3(0, 0, -0.01))
	mi(n, box(0.36, 0.05, 0.07), rim, Vector3(0, 0.04, -0.01))
	return n

static func axe(c: int) -> Node3D:
	var n := Node3D.new()
	var wood := mat("wood", Color("4a2c1a"), 0, 0.8)
	var iron := mat("iron", Color("3a3a44"), 0.9, 0.35)
	mi(n, cyl(0.03, 0.035, 1.3), wood, Vector3(0, -0.45, 0))
	var head := node(n, Vector3(0, -1.0, 0))
	mi(head, box(0.08, 0.2, 0.1), iron, Vector3.ZERO)
	mi(head, box(0.04, 0.5, 0.45), iron, Vector3(0, 0, -0.26))
	mi(head, box(0.02, 0.52, 0.05), glow(side_cols(c).a, 3.0), Vector3(0, 0, -0.49))
	mi(head, cone(0.06, 0.25, 6), iron, Vector3(0, 0, 0.15), Vector3(-PI / 2, 0, 0))
	return n

static func lance(c: int, flame := false) -> Node3D:
	# вдоль -Z, рукоять в начале координат
	var n := Node3D.new()
	var wood := mat("lancewood" + str(c), Color("e8e0cc") if c == 1 else Color("2a1a22"), 0.1, 0.5)
	var met := mat("gold", Color("d8a63c"), 0.9, 0.3)
	mi(n, cyl(0.04, 0.05, 0.9), wood, Vector3(0, 0, 0.2), Vector3(PI / 2, 0, 0))
	mi(n, cyl(0.03, 0.2, 0.35), met, Vector3(0, 0, -0.35), Vector3(PI / 2, 0, 0))
	mi(n, cyl(0.0, 0.11, 2.0, 16), wood, Vector3(0, 0, -1.5), Vector3(-PI / 2, 0, 0))
	mi(n, cyl(0.0, 0.03, 0.4, 8), glow(side_cols(c).b if c == 1 else Color("ff8a30"), 4.0), Vector3(0, 0, -2.55), Vector3(-PI / 2, 0, 0))
	return n

static func javelin(c: int) -> Node3D:
	var n := Node3D.new()
	mi(n, cyl(0.025, 0.025, 1.6), mat("jav", Color("2a1a22"), 0.2, 0.6), Vector3(0, 0, -0.3), Vector3(PI / 2, 0, 0))
	mi(n, cyl(0.0, 0.06, 0.35, 8), glow(Color("ff7a20"), 4.0), Vector3(0, 0, -1.25), Vector3(-PI / 2, 0, 0))
	return n

static func morningstar(c: int, flail := false) -> Node3D:
	var n := Node3D.new()
	var iron := mat("darkiron", Color("2c2c34"), 0.9, 0.35)
	var spikem := mat("spike", Color("c8ccd4"), 1.0, 0.2)
	mi(n, cyl(0.045, 0.05, 1.0), mat("wood", Color("4a2c1a"), 0, 0.8), Vector3(0, -0.35, 0))
	mi(n, cyl(0.07, 0.07, 0.12), iron, Vector3(0, -0.88, 0))
	var ball_parent := n
	var off := -1.1
	if flail:
		var chain := node(n, Vector3(0, -0.9, 0), "chain")
		for i in 6:
			mi(chain, torus(0.025, 0.05), iron, Vector3(0, -0.1 * i - 0.05, 0), Vector3(0, 0, PI / 2 if i % 2 == 0 else 0.0))
		ball_parent = chain
		off = -0.75
		n.set_meta("chain", chain)
	var ball := node(ball_parent, Vector3(0, off, 0), "ball")
	mi(ball, sph(0.26), iron)
	var eyec: Color = side_cols(c).b if c == 1 else side_cols(c).a
	for i in 14:
		var dir := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
		var sp := mi(ball, cone(0.06, 0.24, 6), spikem)
		sp.transform = Transform3D(Basis.looking_at(dir, Vector3.UP if abs(dir.y) < 0.9 else Vector3.RIGHT), dir * 0.3)
		sp.rotate_object_local(Vector3.RIGHT, -PI / 2)
	n.set_meta("ball", ball)
	return n

static func katana(c: int) -> Node3D:
	var n := Node3D.new()
	var bl := mat("katanablade", Color("eef2f8"), 1.0, 0.1)
	mi(n, cyl(0.022, 0.022, 0.28), mat("katgrip" + str(c), Color("20202a") if c == 1 else Color("5a0010"), 0, 0.8), Vector3(0, 0.02, 0))
	mi(n, cyl(0.08, 0.08, 0.02), mat("gold", Color("d8a63c"), 0.9, 0.3), Vector3(0, -0.13, 0))
	for i in 4:
		var y := -0.18 - i * 0.24
		mi(n, box(0.045, 0.25, 0.012), bl, Vector3(0, y - 0.12, -i * i * 0.006), Vector3(-i * 0.03, 0, 0))
	var edge := mi(n, box(0.012, 0.95, 0.014), glow(Color("bfe9ff") if c == 1 else Color("ff2a48"), 4.0), Vector3(0, -0.66, -0.035))
	edge.name = "edge"
	return n

static func bow(c: int) -> Node3D:
	var n := Node3D.new()
	var wood := mat("bow" + str(c), Color("6b4424") if c == 1 else Color("2a1418"), 0.1, 0.6)
	mi(n, box(0.03, 0.4, 0.03), wood, Vector3(0, 0.2, -0.06), Vector3(-0.35, 0, 0))
	mi(n, box(0.03, 0.4, 0.03), wood, Vector3(0, -0.2, -0.06), Vector3(0.35, 0, 0))
	var st := mi(n, box(0.008, 0.76, 0.008), mat("string", Color("e8e0d0"), 0, 0.5), Vector3(0, 0, 0.01))
	st.name = "string"
	return n

static func arrow(c: int, fire := false) -> Node3D:
	var n := Node3D.new()
	mi(n, cyl(0.012, 0.012, 0.7, 6), mat("arrowshaft", Color("c9b48a"), 0, 0.6), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	mi(n, cyl(0.0, 0.03, 0.08, 6), glow(Color("ff8a30"), 5.0) if fire else mat("iron", Color("3a3a44"), 0.9, 0.35), Vector3(0, 0, -0.38), Vector3(-PI / 2, 0, 0))
	mi(n, box(0.002, 0.06, 0.12), mat("fletch" + str(c), Color("f2f2f2") if c == 1 else Color("aa1020"), 0, 0.8), Vector3(0, 0, 0.3))
	mi(n, box(0.06, 0.002, 0.12), mat("fletch" + str(c), Color("f2f2f2") if c == 1 else Color("aa1020"), 0, 0.8), Vector3(0, 0, 0.3))
	return n

# ---------- формы ----------
const PARTS := ["hips", "torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "hand_l", "hand_r", "leg_l", "leg_r", "shin_l", "shin_r"]

## Загружает модель из Blender (.glb): шарниры с теми же именами, что у процедурного гуманоида.
static func load_form(path: String) -> Node3D:
	var ps: PackedScene = load(path)
	var inst: Node3D = ps.instantiate()
	var p := {}
	for nm in PARTS:
		p[nm] = inst.find_child(nm, true, false)
	p.w_main = inst.find_child("w_main", true, false)
	p.w_off = inst.find_child("w_off", true, false)
	inst.set_meta("p", p)
	_shadows(inst)
	return inst

static func _attach(n: Node3D, parent: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> void:
	if n == null:
		return
	n.get_parent().remove_child(n)
	parent.add_child(n)
	n.position = pos
	n.rotation = rot

const MIXAMO := {"hips": "mixamorig_Hips", "torso": "mixamorig_Spine1", "head": "mixamorig_Head",
	"arm_r": "mixamorig_RightArm", "fore_r": "mixamorig_RightForeArm", "hand_r": "mixamorig_RightHand",
	"arm_l": "mixamorig_LeftArm", "fore_l": "mixamorig_LeftForeArm", "hand_l": "mixamorig_LeftHand",
	"leg_r": "mixamorig_RightUpLeg", "shin_r": "mixamorig_RightLeg", "leg_l": "mixamorig_LeftUpLeg", "shin_l": "mixamorig_LeftLeg"}

## Модель со скелетом (Tripo/Mixamo). feet — насколько ступни ниже начала координат, height — нужный рост.
static func rigged(path: String, feet: float, raw_h: float, height: float, dark := false) -> Node3D:
	var root := Node3D.new()
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var holder := Node3D.new()
	holder.name = "model"
	root.add_child(holder)
	holder.add_child(inst)
	var k := height / raw_h
	holder.scale = Vector3.ONE * k
	holder.rotation.y = PI
	inst.position.y = feet
	var skel: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var names := _mixamo_names(skel)
	var drv := RigDriver.new()
	drv.name = "rig"
	root.add_child(drv)
	var p := drv.setup(skel, root, names)
	for side in ["r", "l"]:
		var att := BoneAttachment3D.new()
		att.bone_name = names["hand_" + side]
		skel.add_child(att)
		p["hand_" + side + "_att"] = att
	var hatt := BoneAttachment3D.new()
	hatt.bone_name = names["head"]
	skel.add_child(hatt)
	p["head_att"] = hatt
	if dark:
		for mi_ in inst.find_children("*", "MeshInstance3D", true, false):
			var mesh_i := mi_ as MeshInstance3D
			for si in mesh_i.mesh.get_surface_count():
				var m0 := mesh_i.get_active_material(si)
				if m0 is StandardMaterial3D:
					var m := (m0 as StandardMaterial3D).duplicate() as StandardMaterial3D
					m.albedo_color = Color(0.13, 0.11, 0.16)
					m.metallic = 0.5
					m.emission_enabled = true
					m.emission = Color("ff2040")
					m.emission_energy_multiplier = 0.06
					m.rim_enabled = true
					m.rim = 0.6
					mesh_i.set_surface_override_material(si, m)
	p.rig = drv
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		var ap: AnimationPlayer = aps[0]
		_strip_root_motion(ap, names["hips"])
		p.anim = ap
		ap.stop()
		skel.reset_bone_poses()
	root.set_meta("p", p)
	_shadows(root)
	return root

## Убираем перемещение таза вперёд из анимации (ходьба на месте — двигаем фигуру сами)
static func _strip_root_motion(ap: AnimationPlayer, hips: String) -> void:
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		for an in lib.get_animation_list():
			var a: Animation = lib.get_animation(an)
			a.loop_mode = Animation.LOOP_LINEAR if (an == "walk" or an == "idle" or an.ends_with("walk")) else Animation.LOOP_NONE
			if not (an == "walk" or an.ends_with("walk") or an == "attack"):
				continue
			for ti in a.get_track_count():
				if a.track_get_type(ti) == Animation.TYPE_POSITION_3D and String(a.track_get_path(ti)).ends_with(hips):
					var first: Vector3 = a.track_get_key_value(ti, 0)
					for k in a.track_get_key_count(ti):
						var v: Vector3 = a.track_get_key_value(ti, k)
						a.track_set_key_value(ti, k, Vector3(first.x, v.y, first.z))

## Проиграть анимацию модели (вместо процедурных поз). Возвращает false, если анимации нет.
static func play_anim(fig: Node3D, name: String, speed := 1.0, from_frame := -1.0) -> bool:
	if not fig.has_meta("p"):   # процедурная фигура без скелета и анимаций
		return false
	var p := P_(fig)
	if not p.has("anim"):
		return false
	var ap: AnimationPlayer = p.anim
	var full := ""
	for an in ap.get_animation_list():
		if an == name or an.ends_with("/" + name):
			full = an
			break
	if full == "":
		return false
	p.rig.set_process(false)
	ap.play(full, 0.15 if (name == "walk" or name == "idle") else 0.0, speed)
	if from_frame >= 0.0:
		ap.seek(from_frame / 30.0, true)
	return true

## Текущая позиция анимации в секундах (-1, если не играет)
static func anim_pos(fig: Node3D) -> float:
	if not fig.has_meta("p"):
		return -1.0
	var p := P_(fig)
	if not p.has("anim") or not p.anim.is_playing():
		return -1.0
	return p.anim.current_animation_position

static func stop_anim(fig: Node3D) -> void:
	if not fig.has_meta("p"):
		return
	var p := P_(fig)
	if p.has("anim"):
		p.anim.stop()
		p.rig.skel.reset_bone_poses()
		p.rig.set_process(true)

static func _mixamo_names(skel: Skeleton3D) -> Dictionary:
	# имена костей могут прийти как "mixamorig_X" или "mixamorig:X"
	var out := {}
	for part in MIXAMO:
		var nm: String = MIXAMO[part]
		if skel.find_bone(nm) < 0:
			var alt := nm.replace("mixamorig_", "mixamorig:")
			if skel.find_bone(alt) >= 0:
				nm = alt
		out[part] = nm
	return out

static func soldier(c: int) -> Node3D:
	if c == 1:
		return rigged("res://models/pawn_w.glb", 0.0, 1.75, 1.45)
	return rigged("res://models/pawn_b.glb", 0.0, 1.8, 1.5)

static func horseman(c: int, height := 1.55) -> Node3D:
	var f := rigged("res://models/knight_w.glb" if c == 1 else "res://models/knight_b.glb", 0.0, 1.81, height)
	var p := P_(f)
	p.weapon = f.find_child("spear*", true, false)
	return f

static func giant(c: int) -> Node3D:
	var f := rigged("res://models/bishop_w.glb" if c == 1 else "res://models/bishop_b.glb", 0.0, 1.8, 2.15)
	var p := P_(f)
	p.weapon = f.find_child("mace*", true, false)
	return f

static func ninja(c: int) -> Node3D:
	var suit := mat("ninja_w", Color("e8ecf2"), 0.1, 0.5) if c == 1 else mat("ninja_b", Color("121016"), 0.2, 0.45)
	var trim := mat("gold", Color("d8a63c"), 0.9, 0.3) if c == 1 else mat("crimson", Color("b0102a"), 0.4, 0.4)
	var f := humanoid({"armor": suit, "cloth": suit, "head": "human", "w": 0.82, "skin": mat("skin2", Color("e6c0a0"), 0, 0.6), "belt": trim, "boot": suit, "glove": suit})
	var p := P_(f)
	var head: Node3D = p.head
	var hair := mat("hair_w", Color("f2f0ff"), 0, 0.5) if c == 1 else mat("hair_b", Color("0a0a10"), 0, 0.5)
	mi(head, sph(0.14), hair, Vector3(0, 0.16, 0.02), Vector3.ZERO, Vector3(1, 1, 1))
	mi(head, box(0.24, 0.1, 0.2), suit, Vector3(0, 0.06, -0.05))
	var pony := node(head, Vector3(0, 0.22, 0.12), "pony")
	mi(pony, cap(0.05, 0.6), hair, Vector3(0, -0.25, 0.08), Vector3(0.3, 0, 0))
	p.pony = pony
	for s in [-1, 1]:
		mi(head, sph(0.016, 8), glow(side_cols(c).eye, 3.0), Vector3(s * 0.045, 0.14, -0.125))
	# тиара
	mi(head, torus(0.13, 0.15), trim, Vector3(0, 0.22, 0), Vector3(0.25, 0, 0))
	for i in 5:
		mi(head, cone(0.025, 0.12, 6), trim, Vector3((i - 2) * 0.05, 0.3, -0.1 + abs(i - 2) * 0.02))
	# шарф
	var scarf := node(p.torso, Vector3(0, 0.62, 0.1), "scarf")
	mi(scarf, box(0.1, 0.03, 0.9), mat("scarf_w", Color("d02040"), 0, 0.7) if c == 1 else mat("scarf_b", Color("ff2040"), 0, 0.7, Color("ff2040"), 0.6), Vector3(0, 0, 0.45))
	p.scarf = scarf
	var k := katana(c)
	p.hand_r.add_child(k)
	k.rotation = Vector3(PI / 2, 0, 0)
	p.weapon = k
	f.scale = Vector3.ONE * 0.85
	return f

static func old_king(c: int) -> Node3D:
	var robe := mat("robe_w", Color("f2ece0"), 0, 0.7) if c == 1 else mat("robe_b", Color("1a0c14"), 0.1, 0.6)
	var gold := mat("gold", Color("d8a63c"), 0.9, 0.3)
	var f := humanoid({"armor": robe, "cloth": robe, "head": "human", "w": 1.1, "skin": mat("oldskin", Color("d6b49a"), 0, 0.8), "boot": gold})
	var p := P_(f)
	var head: Node3D = p.head
	# борода, брови, корона, глаза
	mi(head, cone(0.12, 0.42, 10), mat("beard", Color("f4f4f4"), 0, 0.9), Vector3(0, -0.12, -0.08), Vector3(PI, 0, 0))
	mi(head, sph(0.135), mat("beard", Color("f4f4f4"), 0, 0.9), Vector3(0, 0.17, 0.02), Vector3.ZERO, Vector3(1.02, 0.9, 1.0))
	var eyec: Color = Color("ffd25a") if c == 1 else Color("ff2030")
	var eyes := node(head, Vector3.ZERO, "eyes")
	for s in [-1, 1]:
		mi(eyes, sph(0.018, 8), glow(eyec, 3.5), Vector3(s * 0.045, 0.14, -0.12))
		mi(head, box(0.07, 0.018, 0.03), mat("brow", Color("ffffff"), 0, 0.9), Vector3(s * 0.05, 0.18, -0.125), Vector3(0, 0, s * 0.45))
	p.eyes = eyes
	var crown := node(head, Vector3(0, 0.25, 0), "crown")
	mi(crown, cyl(0.15, 0.14, 0.1), gold, Vector3.ZERO)
	for i in 6:
		var a := i / 6.0 * TAU
		mi(crown, cone(0.035, 0.14, 6), gold, Vector3(sin(a) * 0.13, 0.11, cos(a) * 0.13))
	mi(crown, sph(0.03, 8), glow(eyec, 4.0), Vector3(0, 0.05, -0.15))
	# мантия
	mi(p.torso, cyl(0.28, 0.5, 1.0), robe, Vector3(0, 0.0, 0.05))
	mi(p.torso, box(0.12, 0.9, 0.02), gold, Vector3(0, 0.15, -0.2))
	# сидячая поза
	set_pose(f, {"leg_l": Vector3(PI / 2, 0, 0), "leg_r": Vector3(PI / 2, 0, 0), "shin_l": Vector3(-PI / 2, 0, 0), "shin_r": Vector3(-PI / 2, 0, 0),
		"arm_l": Vector3(0.6, 0, -0.15), "arm_r": Vector3(0.6, 0, 0.15), "fore_l": Vector3(0.9, 0, 0), "fore_r": Vector3(0.9, 0, 0)})
	p.hips.position.y = 0.55
	var throne := Node3D.new()
	throne.name = "throne"
	var tm := mat("throne_w", Color("e8dcc0"), 0.3, 0.4) if c == 1 else mat("throne_b", Color("16101c"), 0.6, 0.3)
	mi(throne, box(0.8, 0.5, 0.7), tm, Vector3(0, 0.25, 0.05))
	mi(throne, box(0.85, 1.8, 0.15), tm, Vector3(0, 0.9, 0.42))
	mi(throne, box(0.85, 0.08, 0.2), gold, Vector3(0, 1.82, 0.42))
	for s in [-1, 1]:
		mi(throne, box(0.12, 0.25, 0.7), tm, Vector3(s * 0.45, 0.62, 0.05))
		mi(throne, cone(0.07, 0.4 if c == 1 else 0.6, 6), gold if c == 1 else mat("crimson", Color("b0102a"), 0.4, 0.4), Vector3(s * 0.38, 2.0, 0.42))
	mi(throne, sph(0.1), glow(eyec, 4.0), Vector3(0, 1.6, 0.34))
	f.add_child(throne)
	_shadows(throne)
	f.scale = Vector3.ONE * 1.15
	return f

static func skull(c: int) -> Node3D:
	var n := Node3D.new()
	var bone := mat("bone", Color("efe6d0"), 0, 0.6)
	var fire: Color = Color("ff9a20") if c == 1 else Color("ff2a10")
	mi(n, sph(0.5, 24), bone, Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(1, 1.05, 1.1))
	mi(n, box(0.62, 0.3, 0.55), bone, Vector3(0, -0.22, -0.12))
	var jaw := node(n, Vector3(0, -0.3, 0.1), "jaw")
	mi(jaw, box(0.55, 0.12, 0.55), bone, Vector3(0, -0.06, -0.25))
	for i in 6:
		mi(jaw, box(0.06, 0.08, 0.06), bone, Vector3(-0.17 + i * 0.07, 0.03, -0.5))
		mi(n, box(0.06, 0.08, 0.06), bone, Vector3(-0.17 + i * 0.07, -0.36, -0.38))
	for s in [-1, 1]:
		mi(n, sph(0.14), mat("dark", Color("100c12"), 0, 0.9), Vector3(s * 0.2, 0.08, -0.38))
		mi(n, sph(0.07), glow(fire, 8.0), Vector3(s * 0.2, 0.08, -0.47))
	mi(n, cone(0.07, 0.12, 3), mat("dark", Color("100c12"), 0, 0.9), Vector3(0, -0.12, -0.5), Vector3(PI, 0, 0))
	n.set_meta("jaw", jaw)
	return n
