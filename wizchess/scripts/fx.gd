class_name FX
extends Node3D
## Спецэффекты: частицы, кольца, вспышки, разрезы, молнии, столпы света, осколки.

var _spark_mat: StandardMaterial3D
var _glow_tex: GradientTexture2D
var _crack_tex: ImageTexture

func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.75))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 64
	_glow_tex.height = 64
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.albedo_color = Color(1, 1, 1, 0.42)
	_spark_mat.albedo_texture = _glow_tex
	_spark_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_crack_tex = _make_crack_tex()

## Отложенные функции хранят номер узла, а не сам узел: если узел к тому времени
## уже удалён, Godot иначе ругается «Lambda capture … was freed».
static func _alive(id: int) -> Node:
	return instance_from_id(id) as Node

func _later(n: Node, t: float) -> void:
	var id := n.get_instance_id()
	get_tree().create_timer(t).timeout.connect(func():
		var o := _alive(id)
		if o != null:
			o.queue_free())

func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	var n := colors.size()
	for i in n:
		offs.append(float(i) / n)
		cols.append(colors[i])
		offs.append(float(i + 1) / n - 0.001)
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	return g

func _particles(amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = max(1, amount)
	p.lifetime = life
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _spark_mat
	p.mesh = q
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	var cv := Curve.new()
	cv.add_point(Vector2(0, 1))
	cv.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = cv
	return p

## Разовый взрыв частиц
func burst(pos: Vector3, colors: Array, amount := 80, speed := 5.0, life := 1.0, grav := 6.0, size := 0.12, spread := 180.0, dir := Vector3.UP, radius := 0.05) -> CPUParticles3D:
	var p := _particles(amount, life)
	p.one_shot = true
	p.explosiveness = 0.92
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = max(radius, 0.01)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.damping_min = 0.5
	p.damping_max = 2.5
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size * 1.2
	p.color_initial_ramp = _ramp(colors)
	add_child(p)
	p.global_position = pos
	p.emitting = true
	_later(p, life + 0.6)
	return p

## Постоянный источник (огонь, аура). Возвращает узел — удалите его сами или задайте ttl.
func emitter(parent: Node3D, offset: Vector3, colors: Array, amount := 40, speed := 1.5, life := 0.8, grav := -3.0, size := 0.15, radius := 0.2, ttl := 0.0) -> CPUParticles3D:
	var p := _particles(amount, life)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	p.color_initial_ramp = _ramp(colors)
	p.local_coords = false
	parent.add_child(p)
	p.position = offset
	p.emitting = true
	if ttl > 0:
		_later(p, ttl)
	return p

func stop_emitter(p: CPUParticles3D) -> void:
	if is_instance_valid(p):
		p.emitting = false
		_later(p, p.lifetime + 0.2)

func ring(pos: Vector3, col: Color, size := 4.0, dur := 0.6, y := 0.04) -> void:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 48
	t.ring_segments = 6
	m.mesh = t
	var mt := Fig.fx_mat(col)
	m.material_override = mt
	add_child(m)
	m.global_position = Vector3(pos.x, y, pos.z)
	m.scale = Vector3(0.2, 0.05, 0.2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(size, 0.05, size), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mt, "albedo_color:a", 0.0, dur)
	_later(m, dur + 0.05)

func glow_ball(pos: Vector3, col: Color, size := 2.0, dur := 0.4) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	m.mesh = q
	var gc := col
	gc.a = 0.75
	var mt := Fig.fx_mat(gc)
	mt.albedo_texture = _glow_tex
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.material_override = mt
	add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * size * 0.3
	var tw := create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * size, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mt, "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_later(m, dur + 0.05)

## Сияющий разрез: длинная тонкая полоса, вспыхивает и гаснет
func slash(pos: Vector3, rot: Vector3, col: Color, length := 3.5, dur := 0.35, width := 0.08) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	root.rotation = rot
	for layer in [[width, col], [width * 0.35, Color(1, 1, 1)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(length, layer[0], 0.01)
		m.mesh = b
		var mt := Fig.fx_mat(layer[1])
		m.material_override = mt
		root.add_child(m)
		m.scale = Vector3(0.05, 1, 1)
		var tw := create_tween()
		tw.tween_property(m, "scale", Vector3(1, 1, 1), dur * 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mt, "albedo_color:a", 0.0, dur).set_delay(dur * 0.1)
		tw.parallel().tween_property(m, "scale:y", 3.0, dur).set_delay(dur * 0.1)
	_later(root, dur + 0.1)

## Молния от from к to
func bolt(from: Vector3, to: Vector3, col: Color, dur := 0.5) -> void:
	var root := Node3D.new()
	add_child(root)
	var mats := [Fig.fx_mat(col), Fig.fx_mat(Color.WHITE)]
	var rebuild := func():
		for ch in root.get_children():
			ch.queue_free()
		var prev := from
		var n := 10
		for i in range(1, n + 1):
			var f := float(i) / n
			var p := from.lerp(to, f)
			if i < n:
				p += Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
			var len := prev.distance_to(p)
			for k in 2:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				var w := 0.07 if k == 0 else 0.025
				b.size = Vector3(w, w, len)
				m.mesh = b
				m.material_override = mats[k]
				root.add_child(m)
				m.global_transform = Transform3D(Basis.looking_at((p - prev).normalized(), Vector3.RIGHT if abs((p - prev).normalized().y) > 0.95 else Vector3.UP), (prev + p) / 2.0)
			prev = p
	rebuild.call()
	var steps := int(dur / 0.06)
	for i in steps:
		var rid := root.get_instance_id()
		get_tree().create_timer(0.06 * (i + 1)).timeout.connect(func(): if _alive(rid) != null: rebuild.call())
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mats[0], "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mats[1], "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_later(root, dur + 0.1)

## Столп света с небес
func pillar(pos: Vector3, col: Color, rad := 0.6, dur := 1.2, height := 40.0) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3(pos.x, 0, pos.z)
	var layers := [[rad, col, 0.32], [rad * 0.3, Color.WHITE, 0.5], [rad * 1.8, col, 0.08]]
	for l in layers:
		var m := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = l[0]
		c.bottom_radius = l[0]
		c.height = height
		c.cap_top = false
		c.cap_bottom = false
		c.radial_segments = 32
		m.mesh = c
		var cc: Color = l[1]
		cc.a = l[2]
		var mt := Fig.fx_mat(cc)
		m.material_override = mt
		m.position.y = height / 2.0
		root.add_child(m)
	root.scale = Vector3(0.01, 1, 0.01)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3(1, 1, 1), dur * 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur * 0.55)
	tw.tween_property(root, "scale", Vector3(0.01, 1, 0.01), dur * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_later(root, dur + 0.1)
	return root

func light(pos: Vector3, col: Color, energy := 8.0, rng := 8.0, dur := 0.5) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)
	l.global_position = pos
	if dur > 0:
		create_tween().tween_property(l, "light_energy", 0.0, dur)
		_later(l, dur + 0.05)
	return l

func _make_crack_tex() -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 11:
		var a := i / 11.0 * TAU + randf() * 0.3
		var x := s / 2.0
		var y := s / 2.0
		var w := 4.0
		for st in 7:
			var len := randf_range(10, 20)
			var nx := x + cos(a) * len
			var ny := y + sin(a) * len
			var steps := int(len)
			for k in steps:
				var px := lerpf(x, nx, float(k) / steps)
				var py := lerpf(y, ny, float(k) / steps)
				for ox in range(-int(w), int(w) + 1):
					for oy in range(-int(w), int(w) + 1):
						var qx := int(px) + ox
						var qy := int(py) + oy
						if qx >= 0 and qy >= 0 and qx < s and qy < s and ox * ox + oy * oy <= w * w:
							img.set_pixel(qx, qy, Color(1, 0.7, 0.3, 1))
			x = nx
			y = ny
			a += randf_range(-0.5, 0.5)
			w = max(1.0, w - 0.6)
	return ImageTexture.create_from_image(img)

func cracks(pos: Vector3, col: Color, size := 4.0, dur := 2.5) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	m.mesh = q
	var mt := Fig.fx_mat(col)
	mt.albedo_texture = _crack_tex
	m.material_override = mt
	add_child(m)
	m.global_position = Vector3(pos.x, 0.012, pos.z)
	m.rotation = Vector3(-PI / 2, randf() * TAU, 0)
	m.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * size, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur * 0.5)
	tw.tween_property(mt, "albedo_color:a", 0.0, dur * 0.5)
	_later(m, dur + 0.2)

# ---------- разрушение фигур ----------
func _chunk(mesh: Mesh, shape: Shape3D, m: Material, pos: Vector3, vel: Vector3, life := 4.0) -> RigidBody3D:
	var rb := RigidBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rb.add_child(mi)
	rb.mass = 0.3
	rb.collision_layer = 2
	rb.collision_mask = 1
	add_child(rb)
	rb.global_position = pos
	rb.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	rb.linear_velocity = vel
	rb.angular_velocity = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
	var rbid := rb.get_instance_id()
	var fade := func():
		var r := _alive(rbid) as Node3D
		if r != null:
			var tw := r.create_tween()
			tw.tween_property(r, "scale", Vector3.ONE * 0.01, 0.8)
			tw.tween_callback(r.queue_free)
	get_tree().create_timer(life).timeout.connect(fade)
	return rb

## Фигура разлетается каменными обломками
func shatter(piece: Node3D, from: Vector3, power := 1.0, count := 30) -> void:
	var m: Material = piece.get_meta("m")
	var tr: Material = piece.get_meta("tr")
	var h: float = piece.get_meta("h")
	var base := piece.global_position
	for i in count:
		var s := randf_range(0.07, 0.17)
		var mesh: Mesh
		var shape: Shape3D
		if i % 3 == 0:
			mesh = Fig.cyl(0.0, s * 0.7, s * 1.2, 3)
			var cs := CylinderShape3D.new()
			cs.radius = s * 0.5
			cs.height = s * 1.2
			shape = cs
		else:
			mesh = Fig.box(s, s * randf_range(0.6, 1.3), s)
			var bs := BoxShape3D.new()
			bs.size = Vector3(s, s, s)
			shape = bs
		var pos := base + Vector3(randf_range(-0.25, 0.25), randf() * h * 0.9 + 0.05, randf_range(-0.25, 0.25))
		var out := pos - from
		out.y = 0
		out = out.normalized()
		var vel := out * randf_range(2.0, 6.0) * power + Vector3(0, randf_range(2.0, 6.5) * power, 0)
		_chunk(mesh, shape, tr if i % 6 == 0 else m, pos, vel)
	burst(base + Vector3(0, 0.3, 0), [Color("6a5d50"), Color("8a7f70"), Color("3a3042")], 35, 2.5, 1.4, 3.0, 0.15, 180, Vector3.UP, 0.3)
	piece.queue_free()

## Шинковка: фигура рассыпается на ровные кубики
func dice(piece: Node3D, cut_col: Color) -> void:
	var m: Material = piece.get_meta("m")
	var h: float = piece.get_meta("h")
	var base := piece.global_position
	var s := 0.14
	var layers := int(h / s)
	var mesh := Fig.box(s * 0.96, s * 0.96, s * 0.96)
	var shape := BoxShape3D.new()
	shape.size = Vector3(s * 0.96, s * 0.96, s * 0.96)
	for ly in layers:
		var y := (ly + 0.5) * s
		var rad := 0.33 if y < 0.25 else (0.22 if y < h * 0.75 else 0.17)
		for ix in range(-2, 3):
			for iz in range(-2, 3):
				var x := ix * s
				var z := iz * s
				if x * x + z * z > rad * rad:
					continue
				var rb := _chunk(mesh, shape, m, base + Vector3(x, y, z), Vector3.ZERO, 3.5)
				rb.rotation = Vector3.ZERO
				rb.angular_velocity = Vector3.ZERO
				rb.linear_velocity = Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.0), randf_range(-0.6, 0.6)) + Vector3(x, 0, z) * 4.0
	# светящиеся линии разрезов
	for i in 5:
		slash(base + Vector3(0, randf_range(0.2, h), 0), Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6)), cut_col, 1.6, 0.4, 0.05)
	piece.queue_free()

## Растворение в свете
func dissolve(piece: Node3D, col: Color, dur := 0.8) -> void:
	var base := piece.global_position
	var tw := create_tween().set_parallel(true)
	tw.tween_property(piece, "scale", Vector3(0.05, 1.6, 0.05), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(piece, "position:y", piece.position.y + 1.2, dur)
	burst(base + Vector3(0, 0.6, 0), [col, Color.WHITE], 160, 3.0, 1.6, -4.0, 0.15, 180, Vector3.UP, 0.4)
	var pid := piece.get_instance_id()
	get_tree().create_timer(dur).timeout.connect(func():
		var o := _alive(pid)
		if o != null:
			o.queue_free())

## Полёт стрелы/копья по дуге. Возвращает узел снаряда (остаётся воткнутым).
func projectile(n: Node3D, from: Vector3, to: Vector3, arc: float, dur: float, stick_ttl := 3.0) -> Tween:
	if n.get_parent() != self:   # копьё коня уже лежит в fx (его разворачивают перед броском)
		add_child(n)
	n.global_position = from
	var prev := [from]
	var nid := n.get_instance_id()
	var step := func(t: float):
		var node := _alive(nid) as Node3D
		if node == null:
			return
		var p := from.lerp(to, t)
		p.y += sin(t * PI) * arc
		var d: Vector3 = p - prev[0]
		if d.length() > 0.0005:
			node.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if abs(d.normalized().y) < 0.98 else Vector3.RIGHT), p)
		prev[0] = p
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, dur)
	_later(n, dur + stick_ttl)
	return tw
