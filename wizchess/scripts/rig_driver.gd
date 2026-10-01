class_name RigDriver
extends Node3D
## Управляет костями скелета (Mixamo) через «прокси»-узлы.
## У прокси меняется rotation (как у старых шарниров), а здесь это
## переводится в повороты костей относительно позы покоя.

var skel: Skeleton3D
var parts := {}      # имя части -> индекс кости
var proxies := {}    # имя части -> Node3D
var rest_q := {}     # индекс -> Quaternion покоя (локальный)
var g_basis := {}    # индекс -> Basis глобального покоя в пространстве формы

func setup(s: Skeleton3D, form_root: Node3D, mapping: Dictionary) -> Dictionary:
	skel = s
	# преобразование «скелет → корень формы» (до добавления в дерево)
	var st := Transform3D.IDENTITY
	var n: Node = s
	while n != null and n != form_root:
		if n is Node3D:
			st = (n as Node3D).transform * st
		n = n.get_parent()
	var sb := st.basis.orthonormalized()
	for part in mapping:
		var idx := skel.find_bone(mapping[part])
		if idx < 0:
			continue
		var px := Node3D.new()
		px.name = "px_" + part
		add_child(px)
		proxies[part] = px
		parts[part] = idx
		rest_q[idx] = skel.get_bone_rest(idx).basis.get_rotation_quaternion()
		g_basis[idx] = sb * skel.get_bone_global_rest(idx).basis.orthonormalized()
	return proxies

func _process(_d: float) -> void:
	if skel == null:
		return
	for part in parts:
		var idx: int = parts[part]
		var r: Vector3 = proxies[part].rotation
		if r == Vector3.ZERO:
			skel.set_bone_pose_rotation(idx, rest_q[idx])
			continue
		var g: Basis = g_basis[idx]
		var local := Quaternion((g.inverse() * Basis.from_euler(r) * g).orthonormalized())
		skel.set_bone_pose_rotation(idx, rest_q[idx] * local)
