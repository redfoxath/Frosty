class_name Archer
extends Node
## Лучник на основе солдата-пешки: меч/топор и щит убраны, в левой руке — лук.
## Позу рук считаем сами каждый кадр (анимации у модели для лука нет):
## левая рука вытянута к цели, правая двухзвенной IK тянет тетиву к щеке.
## Тетива рисуется отдельно (из модели лука вырезана), поэтому натягивается вместе с рукой.

const UP := Vector3.UP
## Концы тетивы в координатах модели лука (замерено по сетке)
const STRING := {1: [Vector3(0.089, 0.947, 0.0), Vector3(0.089, 0.034, 0.0)],
	-1: [Vector3(0.081, 0.943, -0.002), Vector3(0.081, 0.039, -0.002)]}
## Хват лука в координатах модели (середина рукояти)
const GRIP := Vector3(-0.045, 0.49, 0.0)

var fig: Node3D          # солдат (корень формы)
var c := 1
var target := Vector3.ZERO
var draw := 0.0          # 0 — тетива отпущена, 1 — натянута до щеки
var nocked := false      # стрела на тетиве
var height := 1.45       # рост фигуры, м
var bow: Node3D
var arrow: Node3D
var _sk: Skeleton3D
var _b := {}
var _str_top: MeshInstance3D
var _str_bot: MeshInstance3D

static var _meshes := {}

## Создать лучника: возвращает узел-контроллер; сама фигура — в .fig
static func make(color: int, h: float) -> Archer:
	var a := Archer.new()
	a.c = color
	a.height = h
	a.fig = Fig.rigged("res://models/pawn_w.glb" if color == 1 else "res://models/pawn_b.glb", 0.0,
		1.75 if color == 1 else 1.8, h)
	a.fig.add_child(a)
	a._setup()
	return a

func _setup() -> void:
	var p := Fig.P_(fig)
	(p.rig as Node).set_process(false)        # процедурный риг не трогает кости
	if p.has("anim"):
		(p.anim as AnimationPlayer).stop()
	_sk = fig.find_children("*", "Skeleton3D", true, false)[0]
	for n in ["Spine1", "Spine2", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand",
			"RightHandIndex1", "LeftHandIndex1"]:
		_b[n] = _sk.find_bone("mixamorig_" + n)
	var mi: MeshInstance3D = _sk.find_children("*", "MeshInstance3D", true, false)[0]
	mi.mesh = _weaponless(mi)
	bow = (load("res://models/bow_w.glb" if c == 1 else "res://models/bow_b.glb") as PackedScene).instantiate()
	bow.top_level = true
	fig.add_child(bow)
	Fig._shadows(bow)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("e8e0d0") if c == 1 else Color("c8b8a0")
	sm.roughness = 0.6
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	for i in 2:
		var s := MeshInstance3D.new()
		s.mesh = cyl
		s.material_override = sm
		s.top_level = true
		fig.add_child(s)
		if i == 0: _str_top = s
		else: _str_bot = s
	arrow = Fig.arrow(c, c == -1)
	arrow.top_level = true
	arrow.visible = false
	fig.add_child(arrow)

## Сетка солдата без оружия и щита (кэш по цвету)
func _weaponless(mi: MeshInstance3D) -> ArrayMesh:
	if _meshes.has(c):
		return _meshes[c]
	var src := mi.mesh
	var am := ArrayMesh.new()
	if c == -1:
		# чёрный: 0 — тело, 1 — топор, 2 — щит
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(0))
		am.surface_set_material(0, src.surface_get_material(0))
	else:
		# белый: 1 — щит; меч вшит в тело и привязан к правой кисти — убираем вершины кисти,
		# которые дальше 22 см от неё (пальцы ближе, клинок начинается от ~29 см)
		var arr := src.surface_get_arrays(0)
		var skin := mi.skin
		var bind := -1
		for i in skin.get_bind_count():
			if skin.get_bind_name(i) == "mixamorig_RightHand" or skin.get_bind_bone(i) == _sk.find_bone("mixamorig_RightHand"):
				bind = i
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var bp := skin.get_bind_pose(bind)
		var cut := PackedByteArray()
		cut.resize(v.size())
		for i in v.size():
			var wt := 0.0
			for k in 4:
				if bones[i * 4 + k] == bind:
					wt += w[i * 4 + k]
			cut[i] = 1 if wt > 0.9 and (bp * v[i]).length() > 22.0 else 0
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if cut[idx[t]] == 1 and cut[idx[t + 1]] == 1 and cut[idx[t + 2]] == 1:
				continue
			keep.append(idx[t]); keep.append(idx[t + 1]); keep.append(idx[t + 2])
		arr[Mesh.ARRAY_INDEX] = keep
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(0, src.surface_get_material(0))
	_meshes[c] = am
	return am

# ---------- работа с костями в мировых координатах ----------
func _gp(b: int) -> Vector3:
	return _sk.global_transform * _sk.get_bone_global_pose(b).origin

func _rot_world(b: int, q: Quaternion) -> void:
	var sb := _sk.global_transform.basis.orthonormalized()
	var qs := Quaternion(sb.inverse() * Basis(q) * sb)
	var g := _sk.get_bone_global_pose(b).basis.orthonormalized()
	var ng := Basis(qs) * g
	var par := _sk.get_bone_parent(b)
	var pb := _sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()
	_sk.set_bone_pose_rotation(b, (pb.inverse() * ng).get_rotation_quaternion())

func _aim(b: int, child: int, dir: Vector3) -> void:
	var d0 := (_gp(child) - _gp(b)).normalized()
	var d1 := dir.normalized()
	if d0.cross(d1).length() > 1e-5 or d0.dot(d1) < 0.0:
		_rot_world(b, Quaternion(d0, d1))

## Двухзвенная IK: плечо → локоть → кисть в точку t, локоть уводим в сторону pole
func _ik(arm: int, fore: int, hand: int, t: Vector3, pole: Vector3) -> void:
	var s := _gp(arm)
	var l1 := _gp(fore).distance_to(s)
	var l2 := _gp(hand).distance_to(_gp(fore))
	var st := t - s
	var d := clampf(st.length(), 0.01, (l1 + l2) * 0.999)
	var dir := st.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - a * a))
	var pn := (pole - dir * pole.dot(dir)).normalized()
	var e := s + dir * a + pn * h
	_aim(arm, fore, e - s)
	_aim(fore, hand, s + dir * d - e)

func _process(_dt: float) -> void:
	if fig == null or not fig.is_inside_tree():
		return
	_sk.reset_bone_poses()
	var chest := _gp(_b.Spine2)
	var D := target - chest
	if D.length() < 0.01:
		return
	D = D.normalized()
	var flat := Vector3(D.x, 0, D.z).normalized()
	# корпус боком к цели: левое плечо вперёд
	fig.global_rotation.y = atan2(-(flat.cross(UP)).x, -(flat.cross(UP)).z)
	# голова повёрнута к цели (корпус стоит боком — цель слева)
	_rot_world(_b.Head, Quaternion(UP, PI * 0.42))
	# левая рука — к цели (чуть выше линии прицела)
	var aim := (D + UP * 0.08).normalized()
	_aim(_b.LeftArm, _b.LeftForeArm, aim)
	_aim(_b.LeftForeArm, _b.LeftHand, aim)
	_aim(_b.LeftHand, _b.LeftHandIndex1, aim)
	# лук в левой руке: вертикально с небольшим наклоном, брюхом к цели, тетивой к лучнику
	var k := height * 0.62 / 0.98
	var right := flat.cross(UP).normalized()
	var by := (UP + right * 0.18).normalized()
	var bx := -aim
	bx = (bx - by * bx.dot(by)).normalized()
	var bz := bx.cross(by).normalized()
	var bb := Basis(bx, by, bz).scaled(Vector3.ONE * k)
	var hand := _gp(_b.LeftHand).lerp(_gp(_b.LeftHandIndex1), 0.5)
	bow.global_transform = Transform3D(bb, hand - bb * GRIP)
	var sp: Array = STRING[c]
	var top: Vector3 = bow.global_transform * (sp[0] as Vector3)
	var bot: Vector3 = bow.global_transform * (sp[1] as Vector3)
	var rest := top.lerp(bot, 0.5)
	# правая рука: от тетивы (draw=0) до щеки (draw=1)
	var anchor := rest - aim * height * 0.36
	var nock := rest.lerp(anchor, draw)
	var rh := nock - aim * 0.03 * height / 1.45
	_ik(_b.RightArm, _b.RightForeArm, _b.RightHand, rh, (-aim + UP * 0.6 + right * 0.3))
	_aim(_b.RightHand, _b.RightHandIndex1, aim)
	_string(_str_top, top, nock)
	_string(_str_bot, nock, bot)
	arrow.visible = nocked
	if nocked:
		var s := height / 1.7
		arrow.global_transform = Transform3D(Basis.looking_at(aim, UP).scaled(Vector3.ONE * s), nock + aim * 0.33 * s)

func _string(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var r := 0.004 * height / 1.45
	m.global_transform = Transform3D(Basis(x * r, y * l, z * r), (a + b) * 0.5)

## Где сейчас наконечник стрелы на тетиве (откуда вылетает выстрел)
func arrow_start() -> Vector3:
	return arrow.global_position
