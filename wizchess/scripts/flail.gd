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
var _vel := Vector3.ZERO
var _piv := Vector3.ZERO
var _tgt := Vector3.ZERO
var damping := DAMPING
var _started := false
var anim_ball := Vector3.ZERO    # где шар по анимации (без раскачки), в мировых координатах
## Жёсткость тяги к позе из анимации (свободная раскачка в стойке и при ходьбе)
var follow := FOLLOW
## 0..1 — насколько каждый кадр подтягивать шар к позе из анимации (0 — чистая физика)
var track := 0.0
## Скорость шара, м/с (для силы удара и эффектов)
var speed := 0.0

## Удар о цель: почти вся энергия шара уходит в противника, остаток — отскок назад
func hit(absorb := 0.85) -> void:
	_vel *= -(1.0 - absorb) * 0.5

## Свободный кистень: шар почти не тянется к позе из анимации, его ведут только цепь,
## тяжесть и инерция от движения руки — при замахе отстаёт, при ударе захлёстывает вперёд
func set_free(on: bool) -> void:
	follow = 2.0 if on else FOLLOW
	damping = 0.35 if on else DAMPING
	track = 0.0
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
	# Godot при импорте даёт рукояти (mace) скрытое преобразование относительно кисти (масштаб ×100,
	# поворот, сдвиг), а отделённой цепи — нет. Обе сетки заданы в одних координатах, поэтому цепь
	# получает то же преобразование плюс сдвиг до шарнира, иначе шар в 100 раз меньше и не на месте.
	var shaft := h.get_parent().get_node_or_null("mace") as Node3D
	if shaft != null:
		h.transform = shaft.transform * Transform3D(Basis.IDENTITY, h.position)
	_rest = h.basis
	ball_local = _ball_center(h)
	ball = Node3D.new()
	ball.name = "flail_ball"
	h.add_child(ball)
	ball.position = ball_local
	var p := h.get_parent()
	while p != null and not (p is Skeleton3D):
		p = p.get_parent()
	_skel = p as Skeleton3D
	if _skel != null:
		_skel.skeleton_updated.connect(_on_skeleton_updated)

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
	_dt += dt
	if _trail_mi != null:
		if _trail_on and ball != null and is_instance_valid(ball) and ball.is_visible_in_tree():
			_trail_pts.append([ball.global_position, _clock])
		_draw_trail()

var _dt := 0.0
var _skel: Skeleton3D

## Маятник считаем сразу после того, как скелет рассчитал позу кадра: тогда кисть уже на своём
## месте и цепь не отстаёт от руки на кадр (заметно при быстром ударе и низком FPS)
func _on_skeleton_updated() -> void:
	if head == null or not is_instance_valid(head) or not head.is_visible_in_tree():
		_started = false
		return
	var att := head.get_parent() as BoneAttachment3D
	if att != null:
		att.on_skeleton_update()
	var dt := minf(_dt, 1.0 / 30.0)
	_dt = 0.0
	head.basis = _rest
	var piv := head.global_position
	var target := head.global_transform * ball_local
	anim_ball = target
	var L := (target - piv).length()
	if L < 0.001:
		return
	# первый кадр или фигуру переставили рывком — без качания
	if not _started or piv.distance_to(_piv) > 1.0:
		_pos = target
		_vel = Vector3.ZERO
		_piv = piv
		_tgt = target
		_started = true
	if dt <= 0.0:
		return
	# шаги по 4 мс: рука за кадр проходит до полуметра, крупный шаг «срезал» бы инерцию.
	# Цепь — жёсткая связь: после шага шар возвращаем на сферу вокруг шарнира,
	# а скорость берём из фактического перемещения — так рывок руки передаётся шару.
	var n := clampi(ceili(dt / 0.004), 1, 12)
	var h := dt / n
	var k := follow * follow * 0.25
	for i in n:
		var t := float(i + 1) / n
		var pv := _piv.lerp(piv, t)
		var tg := _tgt.lerp(target, t)
		var old := _pos
		_vel += (GRAVITY + (tg - _pos) * k) * h
		_vel *= maxf(0.0, 1.0 - damping * h)
		var nxt := _pos + _vel * h
		nxt = pv + (nxt - pv).normalized() * L
		if track > 0.0:
			nxt = pv + (nxt.lerp(tg, track) - pv).normalized() * L
		_vel = (nxt - old) / h
		_pos = nxt
	speed = _vel.length()
	_piv = piv
	_tgt = target
	# поворот считаем в координатах родителя (кости кисти): кость обновляется позже в этом же кадре,
	# и поворот, заданный в мировых координатах, она бы сбила
	var inv := (head.get_parent() as Node3D).global_transform.affine_inverse()
	var lp := inv * piv
	var d0 := (inv * target - lp).normalized()
	var d1 := (inv * _pos - lp).normalized()
	if d0.cross(d1).length() > 1e-5:
		head.basis = Basis(Quaternion(d0, d1)) * _rest
