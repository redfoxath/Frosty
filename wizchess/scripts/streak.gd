class_name Streak
extends MeshInstance3D
## Светящийся след-лента за летящим предметом (острие копья и т. п.).
## Вешается в мир (top_level), каждый кадр запоминает положение цели и рисует ленту, развёрнутую к камере.

var target: Node3D
var col := Color.WHITE
var life := 0.18
var width := 0.12
var _pts := []   # [позиция, время]
var _clock := 0.0
var _mesh := ImmediateMesh.new()
var _on := true

func _init(t: Node3D, c: Color, w := 0.12, l := 0.18) -> void:
	target = t
	col = c
	width = w
	life = l
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material_override = m

## Перестать добавлять точки; хвост догорает и узел удаляется
func stop() -> void:
	_on = false

func _process(dt: float) -> void:
	_clock += dt
	global_transform = Transform3D.IDENTITY
	if _on and target != null and is_instance_valid(target) and target.is_inside_tree():
		_pts.append([target.global_position, _clock])
	while _pts.size() > 0 and _clock - _pts[0][1] > life:
		_pts.pop_front()
	_mesh.clear_surfaces()
	if not _on and _pts.is_empty():
		queue_free()
		return
	var n := _pts.size()
	if n < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3(0, 5, 10)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var p: Vector3 = _pts[i][0]
		var q: Vector3 = _pts[mini(i + 1, n - 1)][0] - _pts[maxi(i - 1, 0)][0]
		var side := q.cross(eye - p).normalized()
		var k := float(i) / (n - 1)   # 0 — хвост, 1 — у предмета
		var w := width * (0.1 + 0.9 * k)
		var c := col
		c.a = k * k * 0.8
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(p - side * w * 0.5)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(p + side * w * 0.5)
	_mesh.surface_end()
