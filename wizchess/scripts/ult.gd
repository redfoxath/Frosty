class_name Ult
extends Node
## Ульты: 6 фигур × 2 стороны. Белые и чёрные — разные варианты.

var g  # main.gd
var cur_atk: Node3D
var cur_vic: Node3D
const UP := Vector3.UP

const INFO := {
	"1w": ["КЛИНОК ПЕХОТЫ", "ПЕШКА · СОЛДАТ КОРОЛЕВСТВА", "РУБ!"],
	"1b": ["СЕКИРА ТЬМЫ", "ПЕШКА · ЧЁРНЫЙ ЛЕГИОН", "ХРЯСЬ!"],
	"2w": ["КОПЬЁ ГРОМА", "КОНЬ · НЕБЕСНЫЙ БРОСОК", "ГРОМ!"],
	"2b": ["АДСКОЕ КОПЬЁ", "КОНЬ · ОГНЕННЫЙ БРОСОК", "БАБАХ!"],
	"3w": ["ЦЕП ПРАВОСУДИЯ", "СЛОН · ЖЕЛЕЗНЫЙ ПАЛАДИН", "БУМ!"],
	"3b": ["ЦЕП БЕЗДНЫ", "СЛОН · ЧЁРНЫЙ ПАЛАДИН", "ХРУСТЬ!"],
	"4w": ["ЛИВЕНЬ СТРЕЛ", "ЛАДЬЯ · ГАРНИЗОН КРЕПОСТИ", "ТРА-ТА-ТА!"],
	"4b": ["ОГНЕННЫЙ ЗАЛП", "ЛАДЬЯ · ЧЁРНАЯ ЦИТАДЕЛЬ", "ПЫЛАЙ!"],
	"5w": ["ТЫСЯЧА РАЗРЕЗОВ", "ФЕРЗЬ · КОРОЛЕВА-НИНДЗЯ", "ШИНК!"],
	"5b": ["ТЕНЕВЫЕ КЛОНЫ", "ФЕРЗЬ · ТЕНЬ ВОСТОКА", "ВЖИК!"],
	"6w": ["ГНЕВ НЕБЕС", "КОРОЛЬ · ВЕРХОВНЫЙ ПРИГОВОР", "СУД!"],
	"6b": ["КРОВАВОЕ НЕБО", "КОРОЛЬ · ПРИГОВОР БЕЗДНЫ", "КАРА!"],
}

func _ang(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.x - from.x), -(to.z - from.z))

func play(atk: Node3D, vic: Node3D, m: Dictionary) -> void:
	cur_atk = atk
	cur_vic = vic
	var c: int = atk.get_meta("c")
	var t: int = atk.get_meta("t")
	var x := {}
	x.c = c
	x.t = t
	x.cols = Fig.side_cols(c)
	x.atk = atk
	x.vic = vic
	x.vt = vic.get_meta("t")
	x.P0 = Vector3(atk.position.x, 0, atk.position.z)
	x.PV = Vector3(vic.position.x, 0, vic.position.z)
	var d: Vector3 = x.PV - x.P0
	x.dist = d.length()
	x.d = d.normalized()
	var side := Vector3(-x.d.z, 0, x.d.x)
	if side.dot(g.main_view().pos) < 0:
		side = -side
	x.side = side
	x.mid = (x.P0 + x.PV) / 2.0
	x.ang = _ang(x.P0, x.PV)
	x.info = INFO[str(t) + ("w" if c == 1 else "b")]
	atk.set_meta("idle", false)
	vic.set_meta("idle", false)
	g.cine_begin(x.cols)
	g.turn_to(atk, x.ang, 0.4)
	g.turn_to(vic, _ang(x.PV, x.P0), 0.5)
	var end_pos: Vector3
	match t:
		Rules.P: end_pos = await ult_pawn(x)
		Rules.N: end_pos = await ult_knight(x)
		Rules.B: end_pos = await ult_bishop(x)
		Rules.R: end_pos = await ult_rook(x)
		Rules.Q: end_pos = await ult_queen(x)
		_: end_pos = await ult_king(x)
	await g.cine_end()
	if is_instance_valid(atk):
		atk.set_meta("idle", true)
	cur_atk = null
	cur_vic = null

# ---------- общие части ----------
func shot_start(x: Dictionary, back := 1.0, h := 1.0, dist := 2.6, fov := 40.0) -> void:
	await g.cam_to(x.P0 + x.side * dist - x.d * back + UP * h, x.P0 + UP * (h * 0.7), 0.6, fov).finished

func transform_in(x: Dictionary, form: Node3D, rise := false) -> void:
	var atk: Node3D = x.atk
	var cols: Dictionary = x.cols
	g.sfx("transform")
	var m: BaseMaterial3D = atk.get_meta("m")
	x.m_em = [m.emission_enabled, m.emission, m.emission_energy_multiplier]
	m.emission_enabled = true
	m.emission = cols.a
	m.emission_energy_multiplier = 0.0
	var b: Node3D = atk.get_node("body")
	var tw = g.create_tween().set_parallel(true)
	tw.tween_property(m, "emission_energy_multiplier", 4.0, 0.7)
	tw.tween_property(b, "rotation:y", b.rotation.y + TAU * 2.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "position:y", 0.45, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	g.fx.emitter(atk, Vector3(0, 0.3, 0), [cols.a, cols.b, Color.WHITE], 45, 2.5, 0.7, -2.0, 0.1, 0.45, 1.0)
	g.fx.pillar(x.P0, cols.a, 0.28, 1.0)
	await tw.finished
	g.flash(0.75, 0.3)
	g.shake(0.15)
	g.sfx("boom", -8, 1.3)
	g.fx.burst(x.P0 + UP * 0.8, [cols.a, Color.WHITE, cols.b], 110, 6.0, 0.9, 3.0, 0.13)
	g.fx.ring(x.P0, cols.a, 3.0, 0.5)
	atk.visible = false
	b.rotation.y = 0
	b.position.y = 0
	g.fx.add_child(form)
	Fig.play_anim(form, "idle")
	form.position = x.P0
	form.rotation.y = x.ang
	var s := form.scale
	if rise:
		form.scale = Vector3(s.x, s.y * 0.01, s.z)
		var tw2 = g.create_tween()
		tw2.tween_property(form, "scale", s, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		g.sfx("crack", 0, 0.7)
		g.shake(0.3)
		g.fx.burst(x.P0, [Color("9a8d7d"), Color("6a5f72")], 80, 3.0, 1.2, 2.0, 0.3, 80, UP, 0.6)
		await tw2.finished
	else:
		form.scale = s * 0.01
		var tw3 = g.create_tween()
		tw3.tween_property(form, "scale", s, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw3.finished

func transform_out(x: Dictionary, form: Node3D, pos: Vector3) -> void:
	var cols: Dictionary = x.cols
	g.sfx("transform", -10, 1.5)
	g.fx.burst(form.global_position + UP * 0.8, [cols.a, Color.WHITE], 100, 4.0, 0.7, 0.0, 0.14)
	var tw = g.create_tween()
	tw.tween_property(form, "scale", form.scale * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	form.queue_free()
	var atk: Node3D = x.atk
	if not is_instance_valid(atk):
		return
	var m: BaseMaterial3D = atk.get_meta("m")
	m.emission_enabled = x.m_em[0]
	m.emission = x.m_em[1]
	m.emission_energy_multiplier = x.m_em[2]
	atk.position = Vector3(pos.x, 0, pos.z)
	atk.rotation.y = x.ang
	atk.visible = true
	atk.scale = Vector3.ONE * 0.01
	var tw2 = g.create_tween()
	tw2.tween_property(atk, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw2.finished

func charge(x: Dictionary, form: Node3D, dur := 1.2, off := Vector3(0, 0.2, 0)) -> void:
	g.sfx("charge", -4)
	g.fx.emitter(form, off, [x.cols.a, x.cols.b], 40, 1.8, 0.8, -2.5, 0.08, 0.45, dur + 0.2)
	var l = g.fx.light(form.global_position + UP * 1.8, x.cols.a, 0.0, 5.0, 0.0)
	var tw = g.create_tween()
	tw.tween_property(l, "light_energy", 2.0, dur)
	tw.tween_property(l, "light_energy", 0.0, 0.3)
	tw.tween_callback(l.queue_free)

func run_to(fig: Node3D, from: Vector3, to: Vector3, dur: float, strides := 2.0, arms := false) -> void:
	if Fig.play_anim(fig, "walk", clampf(strides / max(dur, 0.1) * 0.9, 1.0, 3.5)):
		var twa = g.create_tween()
		twa.tween_method(func(t: float): fig.position = from.lerp(to, t), 0.0, 1.0, dur)
		await twa.finished
		Fig.stop_anim(fig)
		return
	var tw = g.create_tween()
	tw.tween_method(func(t: float):
		fig.position = from.lerp(to, t)
		var ph := t * strides * TAU
		var ps := {"leg_l": Vector3(sin(ph) * 0.9, 0, 0), "leg_r": Vector3(-sin(ph) * 0.9, 0, 0),
			"shin_l": Vector3(-max(0.0, -sin(ph + 0.6)) * 1.3, 0, 0), "shin_r": Vector3(-max(0.0, sin(ph + 0.6)) * 1.3, 0, 0)}
		if arms:
			ps["arm_l"] = Vector3(-sin(ph) * 0.7, 0, -0.1)
			ps["arm_r"] = Vector3(sin(ph) * 0.7, 0, 0.1)
		Fig.set_pose(fig, ps)
		fig.position.y = abs(sin(ph)) * 0.07 * fig.scale.y
		, 0.0, 1.0, dur)
	await tw.finished
	Fig.set_pose(fig, {"leg_l": Vector3.ZERO, "leg_r": Vector3.ZERO, "shin_l": Vector3.ZERO, "shin_r": Vector3.ZERO})
	fig.position.y = 0

func vic_name(x: Dictionary) -> String:
	var vt: int = x.vt
	return Rules.NAMES[vt].to_upper() + (" ПОВЕРЖЕНА" if vt == Rules.P or vt == Rules.R else " ПОВЕРЖЕН")

func impact(x: Dictionary, power := 1.0, big := false, kind := "shatter", at := Vector3.INF) -> void:
	var cols: Dictionary = x.cols
	var hp: Vector3 = (x.PV + UP * 0.55) if at == Vector3.INF else at
	g.hit_stop(0.16 if big else 0.11)
	g.flash(0.75, 0.3)
	g.shake(0.55 if big else 0.35)
	g.sfx("boom_big" if big else "boom")
	g.fx.ring(x.PV, cols.a, 6.5 if big else 4.5, 0.6)
	g.fx.ring(x.PV, Color.WHITE, 3.0, 0.35)
	g.fx.glow_ball(hp, cols.a, 3.0 if big else 2.2, 0.4)
	g.fx.burst(hp, [cols.a, cols.b, Color.WHITE], 200 if big else 140, 9.0 if big else 7.0, 1.1, 7.0, 0.12)
	g.fx.light(hp, Color.WHITE, 6.0, 8.0, 0.4)
	if is_instance_valid(x.vic):
		match kind:
			"shatter": g.fx.shatter(x.vic, x.P0, power)
			"dice": g.fx.dice(x.vic, cols.b)
			"dissolve": g.fx.dissolve(x.vic, cols.a)
			"side": g.fx.shatter(x.vic, x.PV - x.side * 2.0, power)
	g.ono(x.info[2], hp + UP * 0.5, cols)
	g.caption(vic_name(x))
	g.set_slow(0.35)
	await g.wait(0.5)
	g.set_slow(1.0)

## Узел для эффектов на оружии без унаследованного масштаба модели
func fx_anchor(n: Node3D) -> Node3D:
	var a := Node3D.new()
	n.add_child(a)
	var sc := n.global_transform.basis.get_scale()
	a.scale = Vector3(1.0 / max(sc.x, 0.0001), 1.0 / max(sc.y, 0.0001), 1.0 / max(sc.z, 0.0001))
	return a

func done(tw) -> void:
	if tw != null and tw.is_valid() and tw.is_running():
		await tw.finished

## Ждать, пока анимация дойдёт до кадра (30 кадров в секунду) — удар совпадает с позой
func at_frame(form: Node3D, frame: float) -> void:
	var t := frame / 30.0
	var guard := 0
	while Fig.anim_pos(form) >= 0.0 and Fig.anim_pos(form) < t and guard < 2000:
		await g.get_tree().process_frame
		guard += 1

func hand_pos(form: Node3D, which := "hand_r") -> Vector3:
	var p := Fig.P_(form)
	return (p[which + "_att"] if p.has(which + "_att") else p[which]).global_position

# =========================================================
# ПЕШКА: солдат с мечом и щитом / берсерк с секирой
# =========================================================
func ult_pawn(x: Dictionary) -> Vector3:
	var c: int = x.c
	var cols: Dictionary = x.cols
	var form := Fig.soldier(c)
	var d: Vector3 = x.d
	var side: Vector3 = x.side
	await shot_start(x, 1.2, 1.1, 2.8, 40)
	await transform_in(x, form)
	Fig.play_anim(form, "idle")
	if c == -1:
		g.sfx("roar", -4, 1.5)
	g.show_banner(x.info[0], x.info[1])
	g.cam_to(x.P0 + side * 2.0 + d * 0.9 + UP * 1.0, x.P0 + UP * 1.0, 1.3, 30)
	charge(x, form, 1.2)
	await g.wait(1.35)
	g.hide_banner()
	# разбег: камера сбоку следит за бойцом
	var reach := 1.25 if c == 1 else 1.2
	var strike: Vector3 = x.PV - d * reach
	if strike.distance_to(x.P0) > x.P0.distance_to(x.PV):
		strike = x.P0
	g.follow_cam(form, side * 3.2 - d * 0.6 + UP * 1.1, UP * 0.8 + d * 0.6, 5.0)
	g.lines.mode = 2
	g.sfx("whoosh")
	await run_to(form, x.P0, strike, 0.35 + strike.distance_to(x.P0) * 0.3, 2.0)
	g.lines.mode = 0
	var vb: Node3D = x.vic.get_node("body")
	if c == 1:
		# толчок щитом
		Fig.play_anim(form, "bash", 1.2)
		await at_frame(form, 5)
		g.sfx("clang", -2)
		g.shake(0.2)
		g.fx.burst(x.PV - d * 0.45 + UP * 0.7, [Color.WHITE, cols.b], 50, 4.0, 0.4, 4.0, 0.1)
		var tw = g.create_tween().set_parallel(true)
		tw.tween_property(vb, "rotation:x", -0.3, 0.12)
		await at_frame(form, 16)
		# замах и рубящий удар: крупный план снизу
		g.unfollow()
		g.cam_to(strike + side * 2.2 - d * 0.5 + UP * 0.5, (strike + x.PV) / 2.0 + UP * 1.0, 0.35, 44)
		Fig.play_anim(form, "slash", 1.0)
		await at_frame(form, 9)
		g.set_slow(0.3)
		g.fx.glow_ball(hand_pos(form) + UP * 0.3, cols.b, 1.6, 0.4)
		g.sfx("slash", 0, 0.7)
		await at_frame(form, 14)
		g.set_slow(1.0)
		await at_frame(form, 17)
		g.fx.slash(x.PV + UP * 0.7, Vector3(0, x.ang, 1.1), cols.b, 3.0, 0.45, 0.12)
		g.fx.slash(x.PV + UP * 0.7, Vector3(0, x.ang, 1.1), Color.WHITE, 2.4, 0.3, 0.04)
		await impact(x, 1.1, false)
	else:
		# прыжок с секирой над головой и удар сверху
		g.follow_cam(form, side * 4.4 - d * 0.5 + UP * 0.8, UP * 1.25 + d * 0.3, 9.0)
		Fig.play_anim(form, "slash", 1.0)
		await at_frame(form, 8)
		g.sfx("whoosh")
		g.fx.burst(strike, [Color("9a8d7d"), Color("6a5f72")], 40, 2.5, 0.6, 3.0, 0.2, 60, UP, 0.3)
		var p0 := strike
		var p1 := strike + d * 0.15
		var jump = g.create_tween()
		jump.tween_method(func(t: float):
			form.position = p0.lerp(p1, t)
			form.position.y = sin(t * PI) * 1.0, 0.0, 1.0, 23.0 / 30.0)
		await at_frame(form, 16)
		g.set_slow(0.3)
		g.lines.mode = 1
		g.lines.center = g.cam.unproject_position(form.global_position + UP * 1.4)
		g.sfx("whoosh", 0, 0.6)
		await at_frame(form, 25)
		g.lines.mode = 0
		g.set_slow(1.0)
		await at_frame(form, 30)
		await done(jump)
		form.position.y = 0
		g.fx.slash(x.PV + UP * 0.6, Vector3(0, x.ang, PI / 2), cols.a, 3.2, 0.45, 0.14)
		g.fx.cracks(x.PV, cols.a, 3.5)
		g.sfx("crack")
		await impact(x, 1.4, true)
	await g.wait(0.6)
	g.unfollow()
	Fig.play_anim(form, "idle")
	await transform_out(x, form, strike)
	return strike

# =========================================================
# КОНЬ: человек с головой коня. Белые — лэнс с молниями, чёрные — три огненных копья
# =========================================================
func ult_knight(x: Dictionary) -> Vector3:
	var c: int = x.c
	var cols: Dictionary = x.cols
	var d: Vector3 = x.d
	var side: Vector3 = x.side
	var form := Fig.horseman(c)
	var P := Fig.P_(form)
	await shot_start(x, 1.2, 1.2, 2.8, 40)
	await transform_in(x, form)
	Fig.play_anim(form, "idle")
	var wpn: Node3D = P.weapon
	var fire_cols := [Color("ff8a30"), Color("ffd060"), Color("ff3010")]
	g.sfx("roar", -8, 1.8)
	g.show_banner(x.info[0], x.info[1])
	g.cam_to(x.P0 + side * 2.0 + d * 0.8 + UP * 1.3, x.P0 + UP * 1.3, 1.3, 32)
	charge(x, form, 1.2)
	if c == 1:
		g.fx.bolt(wpn.global_position + UP * 6.0, wpn.global_position, cols.b, 0.4)
		g.sfx("zap", -6)
	else:
		g.fx.glow_ball(wpn.global_position, Color("ff6a20"), 1.2, 0.5)
		g.sfx("fire", -6)
	await g.wait(1.35)
	g.hide_banner()
	# бросок: камера из-за плеча на цель
	g.cam_to(x.P0 - d * 2.4 + side * 1.3 + UP * 1.7, x.PV + UP * 0.7, 0.4, 50)
	Fig.play_anim(form, "throw", 1.0, 46)
	var p0: Vector3 = x.P0
	await at_frame(form, 58)
	g.sfx("whoosh")
	g.fx.burst(x.P0, [Color("9a8d7d"), Color.WHITE], 40, 3.0, 0.7, 3.0, 0.2, 60, UP, 0.3)
	var jump = g.create_tween()
	jump.tween_method(func(t: float): form.position.y = sin(t * PI) * 0.8, 0.0, 1.0, 20.0 / 30.0)
	await at_frame(form, 64)
	g.set_slow(0.3)
	g.lines.mode = 1
	g.lines.center = g.cam.unproject_position(form.global_position + UP * 1.6)
	g.sfx("whoosh", 0, 0.6)
	await at_frame(form, 68)
	g.set_slow(1.0)
	g.lines.mode = 0
	# боковой план: видно и бросок, и полёт, и цель
	g.cam_to(x.mid + side * (x.dist * 0.75 + 2.6) + UP * 1.3 - d * 0.3, x.mid + UP * 0.9, 0.12, 50)
	await at_frame(form, 71)
	# отпускаем копьё
	var to: Vector3 = x.PV + UP * 0.55
	var from: Vector3 = wpn.global_position
	var mi_list := wpn.find_children("*", "MeshInstance3D", true, false)
	if wpn is MeshInstance3D:
		mi_list.append(wpn)
	var pivot := Node3D.new()
	g.fx.add_child(pivot)
	pivot.global_transform = Transform3D(Basis.looking_at((to - from).normalized(), UP), from)
	var gt := wpn.global_transform
	wpn.get_parent().remove_child(wpn)
	pivot.add_child(wpn)
	wpn.global_transform = gt
	# развернуть копьё остриём по полёту (длинная ось сетки → -Z пивота)
	if mi_list.size() > 0:
		var mi0: MeshInstance3D = mi_list[0]
		var ab := mi0.get_aabb()
		var ax := Vector3.RIGHT
		if ab.size.y >= ab.size.x and ab.size.y >= ab.size.z:
			ax = Vector3.UP
		elif ab.size.z >= ab.size.x:
			ax = Vector3.BACK
		var wdir := (mi0.global_transform.basis * ax).normalized()
		if wdir.dot(to - from) < 0:
			wdir = -wdir
		var q := Quaternion(wdir, (to - from).normalized())
		var center := mi0.global_transform * ab.get_center()
		var tr := Transform3D(Basis(q), Vector3.ZERO)
		var off := Transform3D(Basis.IDENTITY, center) * tr * Transform3D(Basis.IDENTITY, -center)
		wpn.global_transform = off * wpn.global_transform
	g.sfx("whoosh", 0, 0.5)
	if c == 1:
		g.fx.bolt(from, to, cols.b, 0.4)
	else:
		g.fx.bolt(from, to, Color("ff5a10"), 0.4)
		g.fx.burst(from, fire_cols, 40, 2.0, 0.4, -1.0, 0.1)
	g.unfollow()
	g.set_slow(0.45)
	var fly = g.fx.projectile(pivot, from, to + (to - from).normalized() * 0.35, 0.15, 0.3, 1.6)
	await done(fly)
	g.set_slow(1.0)
	if c == 1:
		for i in 3:
			g.fx.bolt(Vector3(x.PV.x + randf_range(-1.2, 1.2), 8.0, x.PV.z + randf_range(-1.2, 1.2)), x.PV + UP * 0.3, cols.b, 0.45)
		g.sfx("zap")
		g.fx.cracks(x.PV, cols.b, 3.0)
	else:
		g.sfx("fire")
		g.fx.burst(x.PV + UP * 0.3, fire_cols, 140, 5.0, 1.1, -3.0, 0.25, 50, UP, 0.5)
		g.fx.pillar(x.PV, Color("ff3010"), 0.4, 0.8)
	await impact(x, 1.3, false)
	await done(jump)
	form.position.y = 0
	await g.wait(0.7)
	Fig.play_anim(form, "idle")
	await transform_out(x, form, x.P0)
	return x.P0

## Кадр удара в анимации attack: шар идёт диагонально сверху-справа вниз-влево
## и в этот кадр он перед слоном на высоте корпуса противника (~0.7 м)
const BISHOP_HIT_FR := 44.0
## Где в этот кадр шар относительно слона: вперёд и вправо (минус — влево), м — замерено в игре
const BISHOP_HIT_OFS := Vector2(1.10, -0.71)

const JUMP_ROOT := [[1, 0.0], [4, 0.13], [7, 0.24], [10, 0.36], [13, 0.48], [16, 0.59], [19, 0.64], [22, 0.68], [25, 0.75], [28, 0.81], [31, 0.87], [34, 0.93], [36, 1.0], [40, 1.13], [46, 1.24], [52, 1.33], [58, 1.4], [66, 1.44]]

func _jump_frac(fr: float) -> float:
	for i in range(1, JUMP_ROOT.size()):
		if fr <= JUMP_ROOT[i][0]:
			var a: Array = JUMP_ROOT[i - 1]
			var b: Array = JUMP_ROOT[i]
			return lerpf(a[1], b[1], (fr - a[0]) / float(b[0] - a[0]))
	return JUMP_ROOT[-1][1]

## Сдвиг глаз от точки eyes_anchor (в метрах, в осях фигуры: x — вбок, y — вверх, -z — вперёд)
const EYE_OFS := Vector3(0, 0.10, -0.18)

## Глаза в щели забрала: маленькое горячее ядро + мягкий аддитивный ореол.
## Узел глаз получает единичный масштаб, поэтому размеры заданы в метрах и не зависят от масштаба скелета.
func _add_visor_eyes(form: Node3D, col: Color, s: float) -> Node3D:
	# точка eyes_anchor в моделях смещена вбок, поэтому считаем от кости головы
	var eyes := Node3D.new()
	(Fig.P_(form).head_att as Node3D).add_child(eyes)
	var fb := form.global_transform.basis.orthonormalized()
	var halos := []
	eyes.global_transform = Transform3D(fb, eyes.global_position + fb * (EYE_OFS * s))
	for k in [-1, 1]:
		var core := MeshInstance3D.new()
		core.mesh = Fig.sph(0.0075 * s, 12)
		core.material_override = Fig.glow(col.lerp(Color.WHITE, 0.2), 1.7)   # чуть выше порога свечения — лёгкий ореол
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eyes.add_child(core)
		core.position = Vector3(0.034 * s * k, 0, 0)
		var halo := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.075 * s
		halo.mesh = q
		halo.material_override = _eye_halo_mat(col)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eyes.add_child(halo)
		halo.position = core.position + Vector3(0, 0, -0.03 * s)   # перед забралом, чтобы не прятался в шлеме
		halos.append(halo)
	var lt := OmniLight3D.new()
	lt.light_color = col
	lt.light_energy = 0.0
	lt.omni_range = 0.4
	eyes.add_child(lt)
	lt.position = Vector3(0, 0, -0.25)
	eyes.set_meta("light", lt)
	eyes.set_meta("halos", halos)
	return eyes

var _halo_mats := {}

func _eye_halo_mat(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if _halo_mats.has(key):
		return _halo_mats[key]
	var gt := GradientTexture2D.new()
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.gradient = Gradient.new()
	gt.gradient.set_color(0, Color(1, 1, 1, 1))
	gt.gradient.add_point(0.25, Color(1, 1, 1, 0.45))
	gt.gradient.set_color(gt.gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = gt
	m.albedo_color = Color(col.r, col.g, col.b, 0.9)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_halo_mats[key] = m
	return m

# =========================================================
# СЛОН: громадный рыцарь. Белые — моргенштерн сверху, чёрные — цеп по кругу
# =========================================================
func ult_bishop(x: Dictionary) -> Vector3:
	var c: int = x.c
	var cols: Dictionary = x.cols
	var d: Vector3 = x.d
	var side: Vector3 = x.side
	var form := Fig.giant(c)
	var P := Fig.P_(form)
	var s: float = form.get_node("model").scale.x * 1.8 / 1.8
	var eyec: Color = Color("4aa8ff") if c == 1 else Color("ff2030")

	# слон не долетает до врага на длину удара и доворачивается так,
	# чтобы шар (он приходит левее оси слона) пришёлся точно в цель
	var reach := BISHOP_HIT_OFS.length()
	var travel: float = max(0.0, x.dist - reach)
	var aim_yaw := atan2(BISHOP_HIT_OFS.y, BISHOP_HIT_OFS.x)
	var start: Vector3 = x.P0
	await shot_start(x, 1.8, 1.6, 4.0, 46)
	await transform_in(x, form)
	Fig.play_anim(form, "idle")
	g.shake(0.25)
	g.sfx("boom", -6, 0.6)
	await g.wait(0.1)
	var eyes := _add_visor_eyes(form, eyec, 2.15 / 1.8)

	var headp: Vector3 = P.head_att.global_position + UP * 0.2
	var fwd := -form.global_transform.basis.z.normalized()
	# камера слева: справа у плеча поднята булава и закрывает забрало
	await g.cam_to(headp + fwd * 1.6 - side * 0.35, headp, 0.5, 30).finished
	g.show_banner(x.info[0], x.info[1])
	g.sfx("clang", 0, 0.5)
	g.sfx("charge", -4)
	var lt: OmniLight3D = eyes.get_meta("light")
	var tw = g.create_tween().set_parallel(true)
	tw.tween_property(lt, "light_energy", 0.1, 0.5)   # слабая подсветка забрала, а не заливка всего шлема
	# вспышка: раздуваем только ореолы, сами глаза остаются в щели забрала
	for h in eyes.get_meta("halos"):
		var th = g.create_tween()
		th.tween_property(h, "scale", Vector3.ONE * 2.2, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		th.tween_property(h, "scale", Vector3.ONE, 0.5)
	g.cam_to(headp + fwd * 1.1 - side * 0.25, headp, 1.2, 24)
	await g.wait(1.3)
	g.hide_banner()

	var wpn: Node3D = P.weapon
	# шлейф и «линии скорости» — от шара кистеня, а не от рукояти
	var tip: Node3D = (P.flail as Flail).ball if P.has("flail") else wpn
	var trail_col: Color = cols.b if c == 1 else Color("ff5a20")
	if P.has("flail"):
		(P.flail as Flail).trail(true, trail_col)
		(P.flail as Flail).track = 0.6   # в ударе цепь идёт по дуге из анимации с лёгким запаздыванием
	g.cam_to(x.mid + side * (x.dist * 0.6 + 6.0) + UP * 2.2 - d * 0.5, x.mid + UP * 1.6, 0.4, 50)
	form.rotation.y = x.ang + aim_yaw
	Fig.play_anim(form, "attack", 1.0)
	var moving := [true]
	var form_id := form.get_instance_id()
	var mover := func():
		while moving[0] and instance_from_id(form_id) != null:
			var fr: float = Fig.anim_pos(form) * 30.0
			if fr < 0.0:
				break
			# путь до врага проходим к кадру удара (BISHOP_HIT_FR) по кривой прыжка из анимации, дальше стоим
			var jf := clampf(_jump_frac(fr) / _jump_frac(BISHOP_HIT_FR), 0.0, 1.0)
			form.position = start + d * travel * jf
			await g.get_tree().process_frame
	mover.call()
	await at_frame(form, 18)
	g.sfx("whoosh", 0, 0.7)
	# замах: шар над головой — замедление и линии скорости
	await at_frame(form, 31)
	g.set_slow(0.3)
	g.lines.mode = 1
	g.lines.center = g.cam.unproject_position(tip.global_position)
	g.sfx("whoosh", 0, 0.5)
	await at_frame(form, 39)
	g.lines.mode = 0
	g.set_slow(1.0)
	g.cam_to(x.PV + side * 4.2 + UP * 0.8 - d * 1.6, x.PV + UP * 1.0, 0.15, 52)
	# удар — в нижней точке дуги шара
	await at_frame(form, BISHOP_HIT_FR)
	if P.has("flail"):
		(P.flail as Flail).trail(false)
	if c == 1:
		g.fx.cracks(x.PV, cols.b, 5.5)
		g.fx.pillar(x.PV, cols.b, 0.5, 0.8)
	else:
		g.fx.burst(x.PV + UP * 0.4, [Color("ff3010"), Color("ff8a30"), Color("ffd060")], 160, 6.0, 1.0, 2.0, 0.22, 70, UP, 0.4)
		g.fx.cracks(x.PV, Color("ff4010"), 5.0)
		g.sfx("crack")
	g.fx.burst(x.PV, [Color("9a8d7d"), Color("d9cfba")], 100, 5.0, 1.4, 8.0, 0.25, 70, UP, 0.8)
	await impact(x, 1.8, true)
	await at_frame(form, 52)
	moving[0] = false
	if P.has("flail"):
		(P.flail as Flail).track = 0.0
	var endp := form.position
	Fig.play_anim(form, "idle")
	g.create_tween().tween_property(lt, "light_energy", 0.0, 0.3)
	await g.wait(0.3)
	await transform_out(x, form, x.P0)
	return x.P0

# =========================================================
# ЛАДЬЯ: башня с лучниками. Белые — ливень стрел, чёрные — огненные стрелы
# =========================================================
func make_tower(c: int, ang: float) -> Node3D:
	var root := Node3D.new()
	var stone := Fig.mat("tower_w", Color("d6ccb6"), 0.05, 0.75) if c == 1 else Fig.mat("tower_b", Color("231c2a"), 0.3, 0.6)
	var trim := Fig.mat("gold", Color("d8a63c"), 0.9, 0.3) if c == 1 else Fig.mat("crimson", Color("b0102a"), 0.4, 0.4)
	Fig.mi(root, Fig.cyl(0.58, 0.7, 2.6, 24), stone, Vector3(0, 1.3, 0))
	Fig.mi(root, Fig.cyl(0.82, 0.62, 0.3, 24), stone, Vector3(0, 2.72, 0))
	Fig.mi(root, Fig.torus(0.72, 0.8), trim, Vector3(0, 2.6, 0))
	for i in 10:
		var a := i / 10.0 * TAU
		Fig.mi(root, Fig.box(0.24, 0.3, 0.14), stone, Vector3(sin(a) * 0.76, 3.0, cos(a) * 0.76), Vector3(0, a, 0))
	for i in 4:
		var a := i / 4.0 * TAU + 0.4
		Fig.mi(root, Fig.box(0.1, 0.3, 0.04), Fig.glow(Color("ffcf5a") if c == 1 else Color("ff3d20"), 2.5), Vector3(sin(a) * 0.6, 1.6 + (i % 2) * 0.5, cos(a) * 0.6), Vector3(0, a, 0))
	var flag := Fig.node(root, Vector3(0, 2.85, 0.4))
	Fig.mi(flag, Fig.cyl(0.02, 0.02, 1.2), Fig.mat("wood", Color("4a2c1a"), 0, 0.8), Vector3(0, 0.6, 0))
	Fig.mi(flag, Fig.box(0.02, 0.35, 0.5), Fig.mat("tabard_w", Color("2a4aa0"), 0, 0.8) if c == 1 else Fig.mat("tabard_b", Color("6a0c1a"), 0, 0.8), Vector3(0, 1.0, 0.25))
	var archers := []
	for i in 6:
		var off := deg_to_rad(-62.0 + i * 24.8)
		var a := off
		var arc := Fig.humanoid({"armor": Fig.mat("steel", Color("c4cad4"), 0.9, 0.28) if c == 1 else Fig.mat("blackiron", Color("2a2630"), 0.85, 0.35),
			"cloth": Fig.mat("tabard_w", Color("2a4aa0"), 0, 0.8) if c == 1 else Fig.mat("tabard_b", Color("6a0c1a"), 0, 0.8)})
		arc.scale = Vector3.ONE * 0.4
		arc.position = Vector3(-sin(a) * 0.55, 2.87, -cos(a) * 0.55)
		arc.rotation.y = a * 0.3
		var P := Fig.P_(arc)
		Fig.mi(P.head, Fig.cyl(0.15, 0.15, 0.2), Fig.mat("steel", Color("c4cad4"), 0.9, 0.28), Vector3(0, 0.17, 0))
		var bw := Fig.bow(c)
		P.hand_l.add_child(bw)
		bw.rotation = Vector3(PI / 2, 0, 0)
		root.add_child(arc)
		archers.append(arc)
	root.set_meta("archers", archers)
	root.scale = Vector3.ONE * 0.95
	return root

func ult_rook(x: Dictionary) -> Vector3:
	var c: int = x.c
	var cols: Dictionary = x.cols
	var form := make_tower(c, x.ang)
	var archers: Array = form.get_meta("archers")
	await g.cam_to(x.P0 + x.side * 3.6 - x.d * 2.0 + UP * 0.5, x.P0 + UP * 1.6, 0.6, 52).finished
	await transform_in(x, form, true)
	g.show_banner(x.info[0], x.info[1])
	var top: Vector3 = x.P0 + UP * 2.9
	g.cam_to(x.P0 + x.side * 2.4 - x.d * 0.6 + UP * 3.6, top + x.d * 0.6, 0.6, 46)
	for a in archers:
		Fig.pose(a, {"arm_l": Vector3(PI / 2 + 0.25, 0, 0), "arm_r": Vector3(1.45, 0, 0.35), "fore_r": Vector3(1.9, 0, 0), "torso": Vector3(-0.1, 0, 0)}, 0.5)
	charge(x, form, 1.1, Vector3(0, 2.8, 0))
	await g.wait(1.2)
	g.hide_banner()
	var waves := 3
	for w in waves:
		for a in archers:
			Fig.pose(a, {"arm_r": Vector3(1.6, 0, 0.05), "fore_r": Vector3(0.1, 0, 0)}, 0.06)
		g.sfx("arrow", 0, 1.0)
		g.sfx("arrow", -3, 1.25)
		for a in archers:
			var from: Vector3 = Fig.P_(a).hand_l.global_position
			var to: Vector3 = x.PV + Vector3(randf_range(-0.35, 0.35), randf_range(0.15, 0.9), randf_range(-0.35, 0.35))
			var ar := Fig.arrow(c, c == -1)
			if c == -1:
				g.fx.emitter(ar, Vector3(0, 0, -0.3), [Color("ff8a30"), Color("ffd060")], 16, 0.3, 0.3, -1.0, 0.12, 0.03, 3.0)
			var tw = g.fx.projectile(ar, from, to, 1.2 + randf() * 0.6, 0.55 + randf() * 0.1, 1.2)
			tw.finished.connect(func():
				g.sfx("thunk", -6, randf_range(0.8, 1.3))
				if c == -1:
					g.fx.burst(to, [Color("ff8a30"), Color("ffd060"), Color("ff3010")], 30, 2.5, 0.5, -1.0, 0.2)
				else:
					g.fx.burst(to, [Color.WHITE, cols.b], 14, 2.0, 0.3, 4.0, 0.08))
		if w == 0:
			g.cam_to(x.PV + x.side * 2.6 + x.d * 1.0 + UP * 0.7, x.PV + UP * 0.9 - x.d * 0.6, 0.45, 50)
		await g.wait(0.3)
		for a in archers:
			Fig.pose(a, {"arm_r": Vector3(1.45, 0, 0.35), "fore_r": Vector3(1.9, 0, 0)}, 0.2)
		await g.wait(0.28)
		g.shake(0.12)
		g.create_tween().tween_property(x.vic.get_node("body"), "rotation:x", -0.12 * (w + 1), 0.1)
	# финальный залп
	await g.wait(0.35)
	g.set_slow(0.4)
	var finals := []
	for a in archers:
		var from: Vector3 = Fig.P_(a).hand_l.global_position
		var ar := Fig.arrow(c, true)
		ar.scale = Vector3.ONE * 1.6
		g.fx.emitter(ar, Vector3(0, 0, -0.2), [cols.a, Color.WHITE] if c == 1 else [Color("ff3010"), Color("ff8a30")], 30, 0.4, 0.4, 0.0, 0.18, 0.05, 3.0)
		finals.append(g.fx.projectile(ar, from, x.PV + UP * 0.5, 1.6, 0.6, 0.6))
	g.sfx("arrow", 0, 0.7)
	g.lines.mode = 1
	g.lines.center = g.cam.unproject_position(x.PV + UP * 0.5)
	await done(finals[0])
	g.lines.mode = 0
	g.set_slow(1.0)
	if c == -1:
		g.sfx("fire")
		g.fx.burst(x.PV + UP * 0.3, [Color("ff3010"), Color("ff8a30"), Color("ffd060")], 300, 6.0, 1.4, -3.0, 0.4, 50, UP, 0.6)
		g.fx.pillar(x.PV, Color("ff3010"), 0.7, 1.2)
	else:
		g.fx.pillar(x.PV, cols.a, 0.5, 0.8)
	await impact(x, 1.3, true)
	await g.wait(0.5)
	g.cam_to(x.P0 + x.side * 4.0 + UP * 1.5, x.P0 + UP * 1.5, 0.4, 48)
	await g.wait(0.3)
	var tw2 = g.create_tween()
	tw2.tween_property(form, "scale:y", 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	g.sfx("crack", -6, 0.8)
	await tw2.finished
	await transform_out(x, form, x.P0)
	return x.P0

# =========================================================
# ФЕРЗЬ: королева-ниндзя с катаной. Белые — серия разрезов, чёрные — теневые клоны
# =========================================================
func ult_queen(x: Dictionary) -> Vector3:
	var c: int = x.c
	var cols: Dictionary = x.cols
	var form := Fig.ninja(c)
	var P := Fig.P_(form)
	var petals: Array = [Color("ffb7d0"), Color("ffffff"), Color("ff7aa8")] if c == 1 else [Color("2a0a1a"), Color("ff2a48"), Color("4a1060")]
	await shot_start(x, 1.0, 1.0, 2.4, 40)
	await transform_in(x, form)
	g.fx.burst(x.P0 + UP * 0.8, petals, 70, 3.5, 1.6, 0.6, 0.1, 180, UP, 0.6)
	await Fig.pose(form, {"arm_r": Vector3(1.7, 0, 0.5), "fore_r": Vector3(0.6, 0, 0), "arm_l": Vector3(1.2, 0, -0.7), "fore_l": Vector3(1.2, 0, 0), "leg_l": Vector3(0.5, 0, 0), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.3, 0, 0), "hips": Vector3.ZERO}, 0.3).finished
	# крупный план: глаза и отблеск клинка
	var head: Vector3 = P.head.global_position + UP * 0.12
	var fwd := Vector3(-sin(x.ang), 0, -cos(x.ang))
	await g.cam_to(head + fwd * 0.75 + x.side * 0.3, head, 0.4, 28).finished
	g.show_banner(x.info[0], x.info[1])
	g.sfx("slash", -4, 1.7)
	var edge: Node3D = P.weapon.get_node("edge")
	g.fx.glow_ball(edge.global_position, Color.WHITE, 1.2, 0.35)
	g.cam_to(head + fwd * 0.6 + x.side * 0.2, head, 1.1, 22)
	charge(x, form, 1.0, Vector3(0, 0.3, 0))
	await g.wait(1.2)
	g.hide_banner()
	var behind: Vector3 = x.PV + x.d * 1.05
	var vb: Node3D = x.vic.get_node("body")
	if c == 1:
		var orbit_c: Vector3 = x.PV
		var a_start := atan2(x.side.x, x.side.z)
		var tw = g.create_tween()
		tw.tween_method(func(t: float):
			var a := a_start + t * PI * 1.3
			g.cam_pos = orbit_c + Vector3(sin(a) * 3.4, 1.3, cos(a) * 3.4)
			g.cam_look = orbit_c + UP * 0.6
			, 0.0, 1.0, 1.5)
		g.cam_fov = 44
		g.lines.mode = 2
		for i in 7:
			var a: float = x.ang + i * 2.4 + randf() * 0.5
			var pos: Vector3 = x.PV + Vector3(sin(a), 0, cos(a)) * 0.95
			g.fx.burst(form.position + UP * 0.8, petals, 30, 2.0, 0.6, 0.5, 0.1)
			form.position = pos
			form.rotation.y = _ang(pos, x.PV)
			Fig.set_pose(form, {"arm_r": Vector3(PI * 0.9, 0, 0.7)})
			Fig.pose(form, {"arm_r": Vector3(0.3, 0, -0.6)}, 0.08, Tween.TRANS_EXPO, Tween.EASE_OUT)
			g.fx.slash(x.PV + UP * randf_range(0.35, 1.0), Vector3(randf_range(-0.8, 0.8), randf() * TAU, randf_range(-0.8, 0.8)), cols.b if i % 2 == 0 else cols.a, 3.2, 0.3, 0.07)
			g.sfx("slash", -2, randf_range(0.9, 1.3))
			g.shake(0.1)
			vb.position = Vector3(randf_range(-0.05, 0.05), 0, randf_range(-0.05, 0.05))
			await g.wait(0.17)
		await done(tw)
		g.lines.mode = 0
	else:
		await Fig.pose(form, {"arm_l": Vector3(1.4, 0, 0.2), "fore_l": Vector3(1.6, 0, 0), "arm_r": Vector3(PI * 0.9, 0, 0.3)}, 0.2).finished
		g.sfx("roar", -10, 2.0)
		g.cam_to(x.PV + x.side * 4.0 + UP * 2.2, x.PV + UP * 0.5, 0.4, 46)
		var clones := []
		for i in 4:
			var a: float = x.ang + PI / 4 + i * PI / 2
			var pos: Vector3 = x.PV + Vector3(sin(a), 0, cos(a)) * 1.0
			var cl := Fig.ninja(c)
			g.fx.add_child(cl)
			cl.position = pos
			cl.rotation.y = _ang(pos, x.PV)
			Fig.set_pose(cl, {"arm_r": Vector3(PI * 0.95, 0, 0.6), "leg_l": Vector3(0.5, 0, 0), "shin_l": Vector3(-0.6, 0, 0)})
			g.fx.burst(pos + UP * 0.6, [Color("2a0a1a"), Color("4a1060"), Color("ff2a48")], 60, 2.0, 0.9, -1.0, 0.35, 180, UP, 0.3)
			clones.append(cl)
			g.sfx("whoosh", -6, 1.4)
			await g.wait(0.12)
		await g.wait(0.3)
		g.set_slow(0.35)
		for cl in clones:
			Fig.pose(cl, {"arm_r": Vector3(0.3, 0, -0.7)}, 0.1, Tween.TRANS_EXPO, Tween.EASE_OUT)
		for i in 4:
			g.fx.slash(x.PV + UP * (0.4 + i * 0.18), Vector3(0, x.ang + i * PI / 4, (0.6 if i % 2 == 0 else -0.6)), Color("ff2a48"), 3.4, 0.4, 0.09)
		g.sfx("slash", 0, 0.9)
		g.sfx("slash", -2, 1.2)
		g.shake(0.25)
		await g.wait(0.15)
		g.set_slow(1.0)
		for cl in clones:
			g.fx.burst(cl.position + UP * 0.6, [Color("2a0a1a"), Color("4a1060")], 50, 1.5, 0.8, -1.0, 0.4, 180, UP, 0.3)
			cl.queue_free()
		g.fx.burst(form.position + UP * 0.8, petals, 40, 2.0, 0.6, 0.5, 0.12)
	# за спиной жертвы — убрать катану в ножны
	form.position = behind
	form.rotation.y = _ang(x.PV, behind)
	Fig.set_pose(form, {"arm_r": Vector3(0.6, 0, 1.2), "fore_r": Vector3(0, 0, 0), "arm_l": Vector3(0.3, 0, -0.2), "fore_l": Vector3(0, 0, 0), "leg_l": Vector3(0.6, 0, 0), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.4, 0, 0), "shin_r": Vector3(-0.3, 0, 0)})
	g.fx.burst(behind + UP * 0.8, petals, 50, 2.5, 0.8, 0.5, 0.12)
	g.cam_to(x.PV - x.d * 2.3 + x.side * 0.9 + UP * 0.55, x.PV + x.d * 0.5 + UP * 0.75, 0.01, 40)
	vb.position = Vector3.ZERO
	await g.wait(0.15)
	g.set_slow(0.35)
	g.cam_to(x.PV - x.d * 1.9 + x.side * 0.8 + UP * 0.5, x.PV + x.d * 0.5 + UP * 0.75, 0.6, 38)
	await Fig.pose(form, {"arm_r": Vector3(0.4, 0, -0.3), "fore_r": Vector3(1.2, 0, 0)}, 0.35, Tween.TRANS_SINE, Tween.EASE_IN_OUT).finished
	g.set_slow(1.0)
	g.sfx("sheath", 4)
	await g.wait(0.12)
	g.fx.burst(x.PV + UP * 0.6, petals, 120, 3.0, 1.4, 0.6, 0.12, 180, UP, 0.4)
	await impact(x, 1.0, false, "dice")
	await g.wait(0.5)
	await transform_out(x, form, behind)
	return behind

# =========================================================
# КОРОЛЬ: старец на троне. Гневный взгляд → горящий череп → небеса расходятся → луч
# =========================================================
func ult_king(x: Dictionary) -> Vector3:
	var c: int = x.c
	var cols: Dictionary = x.cols
	var form := Fig.old_king(c)
	var P := Fig.P_(form)
	var holy: Color = Color("ffe9a8") if c == 1 else Color("ff2030")
	await shot_start(x, 1.6, 1.5, 3.4, 44)
	await transform_in(x, form)
	g.sfx("choir", -10, 0.6 if c == -1 else 1.0)
	g.show_banner(x.info[0], x.info[1])
	await g.wait(0.6)
	# крупный план гневного взгляда
	var head: Vector3 = P.head.global_position + UP * 0.16
	var fwd := Vector3(-sin(x.ang), 0, -cos(x.ang))
	await g.cam_to(head + fwd * 1.6 + UP * 0.05, head, 0.45, 30).finished
	g.hide_banner()
	g.sfx("roar", -2, 0.7 if c == 1 else 0.55)
	var eyes: Node3D = P.eyes
	var tw = g.create_tween().set_parallel(true)
	tw.tween_property(eyes, "scale", Vector3.ONE * 1.8, 0.9)
	g.cam_to(head + fwd * 1.15 + UP * 0.03, head + UP * 0.02, 1.1, 20, Tween.TRANS_EXPO, Tween.EASE_IN)
	g.shake(0.05)
	await g.wait(1.0)
	# горящий череп
	var sk := Fig.skull(c)
	g.fx.add_child(sk)
	var sk_pos: Vector3 = x.P0 + UP * 3.4 - fwd * 0.6
	sk.global_position = sk_pos
	sk.rotation.y = x.ang
	sk.scale = Vector3.ONE * 0.1
	var fire_cols: Array = [Color("ff9a20"), Color("ffd060"), Color("ff4010")] if c == 1 else [Color("ff2010"), Color("ff6a20"), Color("400008")]
	g.fx.emitter(sk, Vector3(0, 0.4, 0.1), fire_cols, 120, 3.0, 0.7, -4.0, 0.5, 0.6, 2.4)
	g.fx.light(sk_pos, fire_cols[0], 4.0, 10.0, 2.2)
	g.flash(0.7, 0.3, Color("ff8a30"))
	g.sfx("fire")
	g.sfx("roar", 0, 0.5)
	g.cam_to(x.P0 + fwd * 4.2 + x.side * 0.8 + UP * 1.2, x.P0 + UP * 2.4, 0.35, 50, Tween.TRANS_EXPO, Tween.EASE_OUT)
	var tw2 = g.create_tween().set_parallel(true)
	tw2.tween_property(sk, "scale", Vector3.ONE * 1.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(sk.get_meta("jaw"), "rotation:x", 0.6, 0.3).set_delay(0.3)
	g.shake(0.3)
	await g.wait(1.3)
	g.fx.burst(sk.global_position, fire_cols, 200, 5.0, 0.8, -2.0, 0.3)
	sk.queue_free()
	g.flash(1.0, 0.35)
	# небеса расходятся
	var sky := Node3D.new()
	g.fx.add_child(sky)
	var cloud_m := Fig.new_mat(Color("24222e") if c == 1 else Color("2a0810"), 0, 1.0)
	var halves := []
	for s in [-1, 1]:
		var h := Fig.mi(sky, Fig.box(30, 2.5, 40), cloud_m, Vector3(x.PV.x + s * 15.0, 11.0, x.PV.z))
		halves.append(h)
		for k in 6:
			Fig.mi(h, Fig.sph(2.0 + randf() * 1.5), cloud_m, Vector3(-s * 15.0 + randf_range(-0.5, 1.5) * s, -1.0, randf_range(-12, 12)))
	var heaven := Fig.mi(sky, Fig.box(40, 0.2, 40), Fig.glow(holy, 3.0), Vector3(x.PV.x, 15.0, x.PV.z))
	var old_bg: Color = g.env.background_color
	g.env.background_color = Color("1a1420") if c == 1 else Color("300810")
	g.cam_to(x.PV + x.side * 2.6 - x.d * 1.4 + UP * 0.25, x.PV + UP * 7.0 + x.d * 0.5, 0.01, 62)
	await g.wait(0.2)
	g.sfx("crack", 0, 0.5)
	g.sfx("choir" if c == 1 else "roar", 0, 1.0 if c == 1 else 0.6)
	g.shake(0.2)
	var tw3 = g.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw3.tween_property(halves[0], "position:x", x.PV.x - 30.0, 1.4)
	tw3.tween_property(halves[1], "position:x", x.PV.x + 30.0, 1.4)
	for i in 6:
		var a := i / 6.0 * TAU
		g.get_tree().create_timer(0.3 + i * 0.12).timeout.connect(func(): g.fx.pillar(x.PV + Vector3(sin(a), 0, cos(a)) * randf_range(1.5, 3.0), holy, 0.12, 1.6))
	await g.wait(1.0)
	# луч пожирает
	g.cam_to(x.PV + x.side * 3.6 + UP * 1.1 - x.d * 0.5, x.PV + UP * 1.1, 0.5, 46)
	var vic: Node3D = x.vic
	var tw4 = g.create_tween()
	tw4.tween_property(vic, "position:y", 0.9, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	g.fx.pillar(x.PV, holy, 0.95, 2.0)
	g.fx.burst(x.PV + UP * 0.2, [holy, Color.WHITE], 200, 3.0, 1.5, -6.0, 0.2, 40, UP, 0.9)
	g.lines.mode = 1
	g.lines.center = g.cam.unproject_position(x.PV + UP * 1.2)
	await g.wait(0.6)
	g.lines.mode = 0
	await impact(x, 1.0, true, "dissolve", x.PV + UP * 1.3)
	await g.wait(0.6)
	var tw5 = g.create_tween().set_parallel(true)
	tw5.tween_property(halves[0], "position:x", x.PV.x - 15.0, 1.0)
	tw5.tween_property(halves[1], "position:x", x.PV.x + 15.0, 1.0)
	g.cam_to(x.P0 + x.side * 3.4 - x.d * 1.4 + UP * 1.5, x.P0 + UP * 1.1, 0.5, 44)
	await g.wait(0.6)
	g.env.background_color = old_bg
	sky.queue_free()
	await transform_out(x, form, x.P0)
	return x.P0

# ---------- без ульты: короткий удар ----------
func quick(atk: Node3D, vic: Node3D) -> void:
	var c: int = atk.get_meta("c")
	var cols := Fig.side_cols(c)
	var p0 := atk.position
	var pv := vic.position
	var d := (pv - p0)
	d.y = 0
	d = d.normalized()
	atk.set_meta("idle", false)
	await g.turn_to(atk, _ang(p0, pv), 0.15).finished
	var near := pv - d * 0.6
	g.sfx("whoosh")
	var tw = g.create_tween()
	tw.tween_method(func(t: float):
		atk.position = p0.lerp(near, t)
		atk.position.y = sin(t * PI) * 0.4
		, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	g.flash(0.4, 0.3)
	g.shake(0.25)
	g.sfx("boom", -4)
	g.fx.ring(pv, cols.a, 2.5, 0.5)
	g.fx.burst(pv + UP * 0.5, [cols.a, Color.WHITE], 120, 5.0, 0.8, 6.0, 0.12)
	g.fx.shatter(vic, p0, 0.8)
	await g.wait(0.3)
	atk.set_meta("idle", true)
