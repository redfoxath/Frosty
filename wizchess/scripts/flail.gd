class_name Flail
extends Node
## Цепь кистеня как маятник на шарнире: шар отстаёт по инерции при замахе, раскачивается и затухает.
## head — узел mace_flail (цепь+шар), его начало координат стоит в точке крепления цепи к рукояти.
## Каждый кадр сначала берём позу из анимации, потом доворачиваем цепь к смоделированному положению шара.

const GRAVITY := Vector3(0, -9.8, 0)
## Затухание качания, 1/с
const DAMPING := 3.0
## Насколько шар тянется к позе из анимации (чтобы удар приходился туда же, куда задумано)
const FOLLOW := 22.0

var head: Node3D
var ball_local := Vector3.ZERO   # центр шара в координатах head (в покое)
var ball: Node3D                 # маркер на центре шара — к нему цепляются эффекты
var _rest: Basis
var _pos := Vector3.ZERO
var _prev := Vector3.ZERO
var _piv := Vector3.ZERO
var _started := false
# след удара: лента за шаром
var _trail_on := false
var _trail_col := Color.WHITE
var _trail_pts := []   # [позиция, время]
var _trail_mi: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _clock := 0.0
const TRAIL_LIFE := 0.22
const TRAIL_W := 0.16

func setup(h: Node3D) -> void:
	head = h
	_rest = h.basis
	ball_local = _ball_center(h)
	ball = Node3D.new()
	ball.name = "flail_ball"
	h.add_child(ball)
	ball.position = ball_local

## Центр шара: среднее дальних от шарнира вершин цепи
static func _ball_center(h: Node3D) -> Vector3:
	var mi := h as MeshInstance3D
	if mi == null or mi.mesh == null:
		return Vector3.DOWN * 0.5
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var far := 0.0
	for v in verts:
		far = maxf(far, v.length())
	var sum := Vector3.ZERO
	var n := 0
	for v in verts:
		if v.length() > far * 0.6:
			sum += v
			n += 1
	return sum / maxf(n, 1)

## Включить/выключить светящийся след за шаром
func trail(on: bool, col := Color.WHITE) -> void:
	_trail_on = on
	_trail_col = col
	if on and _trail_mi == null:
		_trail_mesh = ImmediateMesh.new()
		_trail_mi = MeshInstance3D.new()
		_trail_mi.mesh = _trail_mesh
		_trail_mi.top_level = true
		_trail_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_trail_mi.material_override = m
		add_child(_trail_mi)
		_trail_mi.global_transform = Transform3D.IDENTITY

func _draw_trail() -> void:
	if _trail_mi == null:
		return
	while _trail_pts.size() > 0 and _clock - _trail_pts[0][1] > TRAIL_LIFE:
		_trail_pts.pop_front()
	_trail_mesh.clear_surfaces()
	var n := _trail_pts.size()
	if n < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3(0, 5, 10)
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var p: Vector3 = _trail_pts[i][0]
		var q: Vector3 = _trail_pts[mini(i + 1, n - 1)][0] - _trail_pts[maxi(i - 1, 0)][0]
		var side := q.cross(eye - p).normalized()
		var k := float(i) / (n - 1)           # 0 — хвост, 1 — у шара
		var w := TRAIL_W * (0.15 + 0.85 * k)
		var c := _trail_col
		c.a = k * k * 0.85
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p - side * w * 0.5)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p + side * w * 0.5)
	_trail_mesh.surface_end()

func _process(dt: float) -> void:
	_clock += dt
	if _trail_mi != null:
		if _trail_on and ball != null and is_instance_valid(ball) and ball.is_visible_in_tree():
			_trail_pts.append([ball.global_position, _clock])
		_draw_trail()
	if head == null or not is_instance_valid(head) or not head.is_visible_in_tree():
		_started = false
		return
	dt = minf(dt, 1.0 / 30.0)
	head.basis = _rest
	var piv := head.global_position
	var target := head.global_transform * ball_local
	var L := (target - piv).length()
	if L < 0.001:
		return
	# первый кадр или фигуру переставили рывком — без качания
	if not _started or piv.distance_to(_piv) > 1.0:
		_pos = target
		_prev = target
		_started = true
	_piv = piv
	if dt <= 0.0:
		return
	var vel := _pos - _prev
	_prev = _pos
	var acc := GRAVITY + (target - _pos) * FOLLOW * FOLLOW * 0.25
	var nxt := _pos + vel * maxf(0.0, 1.0 - DAMPING * dt) + acc * dt * dt
	nxt = piv + (nxt - piv).normalized() * L   # цепь не растягивается
	_pos = nxt
	var d0 := (target - piv).normalized()
	var d1 := (_pos - piv).normalized()
	if d0.cross(d1).length() > 1e-5:
		var gb := head.global_transform.basis
		head.global_transform.basis = Basis(Quaternion(d0, d1)) * gb
