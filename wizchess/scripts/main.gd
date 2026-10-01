extends Node3D
## Живые шахматы: доска, фигуры, камера, интерфейс, режимы, ИИ.

const MODE_PVAI := 0
const MODE_PVP := 1
const MODE_AIAI := 2

var fx: FX
var ult: Ult
var world: Node3D
var cam: Camera3D
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var cam_fov := 42.0
var cam_hoff := 0.0
var follow_node: Node3D = null
var follow_pos := Vector3.ZERO
var follow_look := Vector3.ZERO
var follow_rate := 6.0
var shake_amt := 0.0
var speed := 1.0
var slow := 1.0
var cine := false
var _hitstop := false

var state: Dictionary
var hist := []
var log_lines := []
var els := []
var sel := -1
var legal := []
var busy := false
var over := {}
var mode := MODE_PVAI
var depth := 2
var ult_on := true
var last_mv := {}
var demo_running := false
var _ai_thread: Thread = null
var _ai_started := 0
var _game_id := 0
var _ai_game := -1
var _ai_wait := 0.0
var _clock := 0.0

var hl := []
var sun: DirectionalLight3D
var torches := []
var env: Environment
var base_light := {}

# интерфейс
var ui: CanvasLayer
var panel: PanelContainer
var lbl_who: Label
var lbl_sub: Label
var lbl_gw: Label
var lbl_gb: Label
var opt_mode: OptionButton
var opt_diff: OptionButton
var chk_ult: CheckButton
var cmd_edit: LineEdit
var log_box: RichTextLabel
var btn_undo: Button
var bar_t: ColorRect
var bar_b: ColorRect
var banner: Control
var ban_strip: ColorRect
var ban_name: Label
var ban_sub: Label
var ono_lbl: Label
var cap_lbl: Label
var flash_rect: ColorRect
var toast_lbl: Label
var skip_lbl: Label
var lines: SpeedLines
var font_big: SystemFont
var font_ui: SystemFont
var font_sym: SystemFont
var sfx_players := []
var sfx_cache := {}

# меню, настройки, сохранение
const SAVE_PATH := "user://save.dat"
const SETTINGS_PATH := "user://settings.cfg"
var menu: Menu
var session := false   # партия начата или продолжена в этом запуске
var volume := 0.8
var fullscreen := false

func _ready() -> void:
	randomize()
	_build_env()
	_build_board()
	fx = FX.new()
	add_child(fx)
	world = Node3D.new()
	add_child(world)
	ult = Ult.new()
	ult.g = self
	add_child(ult)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_build_ui()
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	new_game()
	var v := main_view()
	cam_pos = v.pos
	cam_look = v.look
	cam_hoff = v.hoff
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	load_settings()
	menu = Menu.new()
	menu.g = self
	add_child(menu)
	if Array(OS.get_cmdline_user_args()).filter(func(a: String): return a.begins_with("--")).is_empty():
		menu.open_menu(true)
	if "--knightshow" in OS.get_cmdline_user_args():
		panel.visible = false
		for ch in world.get_children():
			ch.queue_free()
		var frames := [1, 52, 60, 66, 70, 73]
		for i in frames.size():
			var f := Fig.horseman(1 if i % 2 == 0 else -1)
			fx.add_child(f)
			f.position = Vector3(-3.0 + i * 1.2, 0, 0.5)
			f.rotation.y = PI / 2
			if i < 2:
				Fig.play_anim(f, "idle" if i == 0 else "walk", 1.0)
			else:
				Fig.play_anim(f, "throw", 0.0001, frames[i])
		cam_hoff = 0
		cam_pos = Vector3(0.0, 1.2, 6.2)
		cam_look = Vector3(0, 0.9, 0.5)
		cam_fov = 50
		return
	if "--showcase" in OS.get_cmdline_user_args():
		panel.visible = false
		for ch in world.get_children():
			ch.queue_free()
		var i := 0
		for c in [1, -1]:
			var f := Fig.soldier(c)
			fx.add_child(f)
			f.position = Vector3(-0.7 + i * 1.4, 0, 0.5)
			f.rotation.y = PI - 0.35 + i * 0.7
			if c == 1:
				Fig.set_pose(f, {"arm_r": Vector3(PI * 0.95, 0, 0.1), "fore_r": Vector3(0.2, 0, 0), "arm_l": Vector3(0.9, 0, -0.3), "fore_l": Vector3(1.2, 0, 0)})
			else:
				Fig.set_pose(f, {"arm_r": Vector3(1.4, 0, 0.3), "fore_r": Vector3(0.5, 0, 0), "torso": Vector3(0.4, 0, 0), "leg_l": Vector3(0.8, 0, 0), "shin_l": Vector3(-1.0, 0, 0)})
			i += 1
		cam_hoff = 0
		cam_pos = Vector3(0.0, 1.25, 3.6)
		cam_look = Vector3(0, 0.85, 0.5)
		cam_fov = 38
		return
	if "--picktest" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		var ok := 0
		for i in [0, 7, 12, 27, 36, 52, 63, 60, 33]:
			var sp := cam.unproject_position(sq_pos(i) + Vector3(0, 0.6 if state.b[i] != 0 else 0.0, 0))
			var r := pick(sp)
			print("PICK ", i, " -> ", r)
			if r == i: ok += 1
		click_sq(52)
		print("SEL ", sel, " legal ", legal.size())
		click_sq(36)
		await get_tree().create_timer(2.0).timeout
		print("AFTER ", Rules.sq_name(last_mv.get("f", 0)), Rules.sq_name(last_mv.get("t", 0)), " ok=", ok)
		get_tree().quit()
	if "--aiai" in OS.get_cmdline_user_args():
		set_mode(MODE_AIAI)
	if "--demo" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.5).timeout
		var only := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--only="):
				only = a.substr(7)
		await demo(only)
		get_tree().quit()

# ---------------- окружение ----------------
func _build_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("09070c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a5a88")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color("140e1c")
	env.fog_density = 0.012
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("2a2440")
	sm.sky_horizon_color = Color("7a6878")
	sm.ground_horizon_color = Color("4a3428")
	sm.ground_bottom_color = Color("0a080c")
	sm.sky_energy_multiplier = 1.0
	sky.sky_material = sm
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("fff0dd")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("7f9cff")
	rim.light_energy = 0.4
	rim.rotation = Vector3(deg_to_rad(-25), deg_to_rad(200), 0)
	add_child(rim)
	base_light = {"sun": 1.0, "amb": 0.45, "rim": 0.4, "torch": 1.6}
	base_light["rim_node"] = rim

func _build_board() -> void:
	var nl := FastNoiseLite.new()
	nl.noise_type = FastNoiseLite.TYPE_CELLULAR
	nl.frequency = 0.02
	nl.fractal_type = FastNoiseLite.FRACTAL_FBM
	var mk := func(c1: Color, c2: Color) -> StandardMaterial3D:
		var nt := NoiseTexture2D.new()
		nt.noise = nl
		nt.width = 256
		nt.height = 256
		var gr := Gradient.new()
		gr.set_color(0, c1)
		gr.set_color(1, c2)
		nt.color_ramp = gr
		var m := StandardMaterial3D.new()
		m.albedo_texture = nt
		m.roughness = 0.45
		m.metallic = 0.05
		return m
	var ml: StandardMaterial3D = mk.call(Color("e2d8c4"), Color("b5a891"))
	var md: StandardMaterial3D = mk.call(Color("2e2638"), Color("5a4a6e"))
	var sq_mesh := Fig.box(0.98, 0.22, 0.98)
	for i in 64:
		var r := i >> 3
		var c := i & 7
		var m := MeshInstance3D.new()
		m.mesh = sq_mesh
		m.material_override = md if (r + c) % 2 == 1 else ml
		m.position = sq_pos(i) + Vector3(0, -0.11, 0)
		add_child(m)
	var frame := Fig.mi(self, Fig.box(9.3, 0.34, 9.3), Fig.new_mat(Color("151018"), 0.3, 0.55), Vector3(0, -0.2, 0))
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Fig.mi(self, Fig.box(8.12, 0.3, 8.12), Fig.new_mat(Color("b88a34"), 0.85, 0.3), Vector3(0, -0.17, 0))
	for i in 8:
		for pair in [[Vector3(i - 3.5, -0.02, 4.33), "abcdefgh"[i]], [Vector3(-4.33, -0.02, i - 3.5), str(8 - i)]]:
			var l := Label3D.new()
			l.text = pair[1]
			l.font_size = 64
			l.pixel_size = 0.005
			l.modulate = Color("d9b45a")
			l.rotation = Vector3(-PI / 2, 0, 0)
			l.position = pair[0]
			add_child(l)
	Fig.mi(self, Fig.box(80, 0.1, 80), Fig.new_mat(Color("07060a"), 0, 0.95), Vector3(0, -0.42, 0))
	# физика: доска и пол
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(9.3, 0.4, 9.3)
	cs.shape = bs
	cs.position = Vector3(0, -0.2, 0)
	sb.add_child(cs)
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(80, 0.1, 80)
	cs2.shape = bs2
	cs2.position = Vector3(0, -0.42, 0)
	sb.add_child(cs2)
	add_child(sb)
	# колонны с факелами
	for p in [Vector3(-6, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, 6), Vector3(6, 0, 6)]:
		Fig.mi(self, Fig.cyl(0.2, 0.28, 3.4), Fig.new_mat(Color("2a2230"), 0.1, 0.8), p + Vector3(0, 1.3, 0))
		Fig.mi(self, Fig.cyl(0.3, 0.18, 0.25), Fig.new_mat(Color("b88a34"), 0.85, 0.3), p + Vector3(0, 3.1, 0))
		var l := OmniLight3D.new()
		l.light_color = Color("ff9440")
		l.light_energy = 1.6
		l.omni_range = 14.0
		l.position = p + Vector3(0, 3.6, 0)
		add_child(l)
		torches.append(l)
	call_deferred("_torch_fire")
	# подсветка клеток
	var q := QuadMesh.new()
	q.size = Vector2(0.98, 0.98)
	var dot := Fig.cyl(0.13, 0.13, 0.01, 24)
	var ring := Fig.torus(0.36, 0.46)
	for i in 64:
		var t := MeshInstance3D.new()
		t.mesh = q
		var tm := Fig.fx_mat(Color(1, 1, 1, 0), false)
		t.material_override = tm
		t.rotation = Vector3(-PI / 2, 0, 0)
		t.position = sq_pos(i) + Vector3(0, 0.004, 0)
		add_child(t)
		var d := MeshInstance3D.new()
		d.mesh = dot
		d.material_override = Fig.glow(Color("8fe3ff"), 1.5)
		d.position = sq_pos(i) + Vector3(0, 0.008, 0)
		d.visible = false
		add_child(d)
		var rg := MeshInstance3D.new()
		rg.mesh = ring
		rg.material_override = Fig.glow(Color("ff3d5a"), 2.0)
		rg.scale = Vector3(1, 0.1, 1)
		rg.position = sq_pos(i) + Vector3(0, 0.01, 0)
		rg.visible = false
		add_child(rg)
		hl.append({"t": t, "tm": tm, "d": d, "r": rg})

func _torch_fire() -> void:
	for l in torches:
		fx.emitter(self, l.position + Vector3(0, -0.35, 0), [Color("ffb040"), Color("ff6a20"), Color("ffd890")], 30, 1.2, 0.6, -2.0, 0.22, 0.08)

func sq_pos(i: int) -> Vector3:
	return Vector3((i & 7) - 3.5, 0, (i >> 3) - 3.5)

# ---------------- камера ----------------
func main_view() -> Dictionary:
	var vs := get_viewport().get_visible_rect().size
	var a: float = vs.x / max(1.0, vs.y)
	var dist := 11.6 if a > 1.5 else (13.0 if a > 1.2 else 15.5)
	return {"pos": Vector3(0, dist * 0.86, dist * 0.74), "look": Vector3(0, -0.4, 0.55), "fov": 42.0, "hoff": 1.35 if a > 1.3 else 0.0}

func _on_resize() -> void:
	if not cine:
		var v := main_view()
		cam_pos = v.pos
		cam_look = v.look
		cam_hoff = v.hoff

func cam_to(pos: Vector3, look: Vector3, dur: float, fov := -1.0, trans := Tween.TRANS_CUBIC, ease := Tween.EASE_IN_OUT) -> Tween:
	var p0 := cam_pos
	var l0 := cam_look
	var f0 := cam_fov
	var f1 := fov if fov > 0 else cam_fov
	var tw := create_tween().set_trans(trans).set_ease(ease)
	tw.tween_method(func(t: float):
		cam_pos = p0.lerp(pos, t)
		cam_look = l0.lerp(look, t)
		cam_fov = lerpf(f0, f1, t), 0.0, 1.0, max(0.001, dur))
	return tw

## Камера следит за узлом: позиция = узел + pos_off, взгляд = узел + look_off
func follow_cam(n: Node3D, pos_off: Vector3, look_off: Vector3, rate := 6.0) -> void:
	follow_node = n
	follow_pos = pos_off
	follow_look = look_off
	follow_rate = rate

func unfollow() -> void:
	follow_node = null

func shake(a: float) -> void:
	shake_amt = max(shake_amt, a)

func _apply_time() -> void:
	if not _hitstop:
		Engine.time_scale = speed * slow

func set_slow(f: float) -> void:
	slow = f
	_apply_time()

func hit_stop(t := 0.12) -> void:
	_hitstop = true
	Engine.time_scale = 0.03
	get_tree().create_timer(t, true, false, true).timeout.connect(func():
		_hitstop = false
		_apply_time())

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _process(delta: float) -> void:
	var rdt: float = delta / max(0.001, Engine.time_scale)
	_clock += delta
	for g in world.get_children():
		if g.has_meta("t") and g.get_meta("idle", true):
			var b: Node3D = g.get_node("body")
			b.position.y = sin(_clock * 2.0 + g.get_meta("bob")) * 0.025
			b.rotation.z = sin(_clock * 1.3 + g.get_meta("bob")) * 0.02
	if sel >= 0 and els[sel] != null:
		els[sel].get_node("body").position.y = 0.12 + sin(_clock * 6.0) * 0.05
	for i in torches.size():
		torches[i].light_energy = base_light.torch * torch_mul * (0.88 + sin(_clock * 9.0 + i * 2) * 0.07 + randf() * 0.06)
	if follow_node != null and is_instance_valid(follow_node):
		var k := 1.0 - exp(-follow_rate * rdt)
		var np := follow_node.global_position
		cam_pos = cam_pos.lerp(np + follow_pos, k)
		cam_look = cam_look.lerp(np + follow_look, k)
	var sh := Vector3.ZERO
	if shake_amt > 0.001:
		sh = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * shake_amt
		shake_amt *= pow(0.02, rdt)
	cam.global_position = cam_pos + sh
	if cam_pos.distance_to(cam_look) > 0.01:
		var up := Vector3.UP if abs((cam_look - cam_pos).normalized().y) < 0.98 else Vector3.FORWARD
		cam.look_at(cam_look + sh * 0.5, up)
	cam.fov = cam_fov
	cam.h_offset = cam_hoff
	# прячем фигуры, загораживающие камеру во время ульты
	if cine:
		for g in world.get_children():
			if not g.has_meta("t") or g == ult.cur_atk or g == ult.cur_vic:
				continue
			var ax := cam_look.x - cam_pos.x
			var az := cam_look.z - cam_pos.z
			var L: float = ax * ax + az * az
			if L < 0.0001:
				L = 1.0
			var k: float = clamp(((g.position.x - cam_pos.x) * ax + (g.position.z - cam_pos.z) * az) / L, 0.0, 1.0)
			var dx: float = cam_pos.x + ax * k - g.position.x
			var dz: float = cam_pos.z + az * k - g.position.z
			g.visible = Vector2(dx, dz).length() > 0.7 and Vector2(g.position.x - cam_pos.x, g.position.z - cam_pos.z).length() > 2.2
	# ИИ
	if _ai_thread != null and not _ai_thread.is_alive() and Time.get_ticks_msec() - _ai_started > int(_ai_wait * 1000):
		var m: Dictionary = _ai_thread.wait_to_finish()
		_ai_thread = null
		if _ai_game == _game_id:
			busy = false
			if not m.is_empty() and not demo_running:
				do_move(m)
		else:
			maybe_ai()

var torch_mul := 1.0
var cam_light: OmniLight3D = null

func dim_world(k: float, dur := 0.4) -> Tween:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sun, "light_energy", base_light.sun * k, dur)
	tw.tween_property(env, "ambient_light_energy", base_light.amb * k, dur)
	tw.tween_property(base_light.rim_node, "light_energy", base_light.rim * k, dur)
	tw.tween_property(self, "torch_mul", k, dur)
	return tw

# ---------------- интерфейс ----------------
func _sysfont(names: PackedStringArray, weight := 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = names
	f.font_weight = weight
	return f

func _build_ui() -> void:
	font_big = _sysfont(PackedStringArray(["Impact", "Arial Black", "Franklin Gothic Heavy", "Bahnschrift", "DejaVu Sans"]), 900)
	font_ui = _sysfont(PackedStringArray(["Segoe UI", "Arial", "Helvetica", "DejaVu Sans", "Noto Sans"]), 400)
	font_sym = _sysfont(PackedStringArray(["Segoe UI Symbol", "DejaVu Sans", "Noto Sans Symbols 2", "Arial Unicode MS"]), 400)
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var th := Theme.new()
	th.default_font = font_ui
	th.default_font_size = 15
	root.theme = th
	# кинематографический слой
	lines = SpeedLines.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lines)
	banner = Control.new()
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	root.add_child(banner)
	ban_strip = ColorRect.new()
	ban_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(ban_strip)
	ban_name = _label("", font_big, 84, Color.WHITE, 14, Color("0a0710"))
	banner.add_child(ban_name)
	ban_sub = _label("", font_big, 22, Color("ffcf5a"), 6, Color.BLACK)
	banner.add_child(ban_sub)
	ono_lbl = _label("", font_big, 150, Color.WHITE, 20, Color("08050c"))
	ono_lbl.visible = false
	root.add_child(ono_lbl)
	cap_lbl = _label("", font_big, 34, Color("ffcf5a"), 8, Color.BLACK)
	cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cap_lbl.offset_top = -190
	cap_lbl.offset_bottom = -130
	cap_lbl.modulate.a = 0
	root.add_child(cap_lbl)
	bar_t = ColorRect.new()
	bar_t.color = Color.BLACK
	bar_t.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_t.offset_bottom = 0
	bar_t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_t)
	bar_b = ColorRect.new()
	bar_b.color = Color.BLACK
	bar_b.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_b.offset_top = 0
	bar_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_b)
	skip_lbl = _label("клик — ускорить", font_ui, 14, Color(1, 1, 1, 0.6), 0, Color.BLACK)
	skip_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_lbl.offset_left = -170
	skip_lbl.offset_top = -40
	skip_lbl.visible = false
	root.add_child(skip_lbl)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)
	toast_lbl = _label("", font_ui, 17, Color.WHITE, 6, Color.BLACK)
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_lbl.offset_top = 18
	toast_lbl.offset_left = -400
	toast_lbl.offset_right = 400
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.modulate.a = 0
	root.add_child(toast_lbl)
	_build_panel(root)

func _label(t: String, f: Font, size: int, col: Color, outline: int, ocol: Color) -> Label:
	var l := Label.new()
	l.text = t
	var ls := LabelSettings.new()
	ls.font = f
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = outline
	ls.outline_color = ocol
	ls.shadow_size = 0
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_panel(root: Control) -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -350
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.055, 0.09, 0.92)
	sb.border_color = Color("2b2533")
	sb.border_width_left = 1
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(300, 0)
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	var title := _label("ЖИВЫЕ ШАХМАТЫ", font_big, 27, Color("f0bf4c"), 0, Color.BLACK)
	v.add_child(title)
	var tag := _label("Каждое взятие — ульта.", font_ui, 14, Color("968ba3"), 0, Color.BLACK)
	v.add_child(tag)
	v.add_child(HSeparator.new())
	lbl_who = _label("Ход белых", font_big, 26, Color("fff4dc"), 0, Color.BLACK)
	v.add_child(lbl_who)
	lbl_sub = _label("", font_ui, 14, Color("968ba3"), 0, Color.BLACK)
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lbl_sub)
	v.add_child(_label("ПАВШИЕ", font_ui, 12, Color("968ba3"), 0, Color.BLACK))
	lbl_gw = _label("", font_sym, 22, Color("ff6a80"), 0, Color.BLACK)
	lbl_gw.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(lbl_gw)
	lbl_gb = _label("", font_sym, 22, Color("f4eee2"), 0, Color.BLACK)
	lbl_gb.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(lbl_gb)
	v.add_child(HSeparator.new())
	v.add_child(_label("РЕЖИМ", font_ui, 12, Color("968ba3"), 0, Color.BLACK))
	opt_mode = OptionButton.new()
	for s in ["Игрок против ИИ", "Вдвоём за одним экраном", "ИИ против ИИ"]:
		opt_mode.add_item(s)
	opt_mode.item_selected.connect(func(i): set_mode(i))
	v.add_child(opt_mode)
	opt_diff = OptionButton.new()
	for s in ["ИИ: Новичок", "ИИ: Рыцарь", "ИИ: Магистр"]:
		opt_diff.add_item(s)
	opt_diff.select(1)
	opt_diff.item_selected.connect(func(i): set_depth(i + 1))
	v.add_child(opt_diff)
	chk_ult = CheckButton.new()
	chk_ult.text = "Ульты при взятии"
	chk_ult.button_pressed = true
	chk_ult.toggled.connect(func(b): set_ult(b))
	v.add_child(chk_ult)
	var row := HBoxContainer.new()
	var bn := Button.new()
	bn.text = "Новая партия"
	bn.pressed.connect(func():
		if not cine and (not busy or _ai_thread != null):
			new_game()
			save_game()
			maybe_ai())
	row.add_child(bn)
	btn_undo = Button.new()
	btn_undo.text = "Отменить ход"
	btn_undo.pressed.connect(undo)
	row.add_child(btn_undo)
	v.add_child(row)
	row.add_theme_constant_override("separation", 8)
	for b in row.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bm := Button.new()
	bm.text = "Главное меню  (Esc)"
	bm.pressed.connect(func():
		if can_open_menu():
			menu.open_menu())
	v.add_child(bm)
	var bd := Button.new()
	bd.text = "Показать все 12 ульт"
	bd.pressed.connect(func():
		if not busy and not cine:
			demo(""))
	v.add_child(bd)
	v.add_child(HSeparator.new())
	v.add_child(_label("ПРИКАЗ ФИГУРЕ", font_ui, 12, Color("968ba3"), 0, Color.BLACK))
	cmd_edit = LineEdit.new()
	cmd_edit.placeholder_text = "конь f3 · e2 e4 · рокировка"
	cmd_edit.text_submitted.connect(func(_t): _on_cmd())
	v.add_child(cmd_edit)
	var bc := Button.new()
	bc.text = "Приказать"
	bc.pressed.connect(_on_cmd)
	v.add_child(bc)
	var hint := _label("Нажмите на фигуру, потом на клетку — она сама пойдёт.\nПробел или клик во время ульты — ускорить.", font_ui, 13, Color("968ba3"), 0, Color.BLACK)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	v.add_child(HSeparator.new())
	v.add_child(_label("ЛЕТОПИСЬ", font_ui, 12, Color("968ba3"), 0, Color.BLACK))
	log_box = RichTextLabel.new()
	log_box.custom_minimum_size = Vector2(0, 200)
	log_box.scroll_following = true
	log_box.add_theme_font_override("normal_font", font_sym)
	log_box.add_theme_font_size_override("normal_font_size", 15)
	v.add_child(log_box)

func toast(t: String) -> void:
	toast_lbl.text = t
	var tw := create_tween()
	tw.tween_property(toast_lbl, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.4)
	tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.4)

# ----- кинематографические элементы -----
func cine_begin(cols: Dictionary) -> void:
	cine = true
	var vs := get_viewport().get_visible_rect().size
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar_t, "offset_bottom", vs.y * 0.11, 0.35)
	tw.tween_property(bar_b, "offset_top", -vs.y * 0.11, 0.35)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "cam_hoff", 0.0, 0.5)
	skip_lbl.visible = true
	dim_world(0.35, 0.5)
	if cam_light == null:
		cam_light = OmniLight3D.new()
		cam_light.light_color = Color("fff2e0")
		cam_light.omni_range = 14.0
		cam_light.omni_attenuation = 0.6
		cam.add_child(cam_light)
	cam_light.light_energy = 0.0
	create_tween().tween_property(cam_light, "light_energy", 1.1, 0.5)
	cap_lbl.label_settings.font_color = cols.a
	var g := Gradient.new()
	g.set_color(0, cols.deep)
	g.add_point(0.2, cols.a)
	g.set_color(1, cols.b)
	ban_sub.label_settings.font_color = cols.a
	ban_strip.color = cols.a
	ban_strip.set_meta("cols", cols)

func cine_end() -> void:
	hide_banner()
	lines.mode = 0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bar_t, "offset_bottom", 0.0, 0.4)
	tw.tween_property(bar_b, "offset_top", 0.0, 0.4)
	tw.tween_property(panel, "modulate:a", 1.0, 0.4)
	tw.tween_property(cap_lbl, "modulate:a", 0.0, 0.3)
	var v := main_view()
	tw.tween_property(self, "cam_hoff", v.hoff, 0.7)
	dim_world(1.0, 0.6)
	if cam_light != null:
		create_tween().tween_property(cam_light, "light_energy", 0.0, 0.5)
	await cam_to(v.pos, v.look, 0.8, v.fov).finished
	skip_lbl.visible = false
	cine = false
	speed = 1.0
	set_slow(1.0)
	follow_node = null
	for g in world.get_children():
		if g is Node3D:
			g.visible = true

func show_banner(name: String, sub: String) -> void:
	var vs := get_viewport().get_visible_rect().size
	banner.visible = true
	banner.modulate.a = 1
	var h := clampf(vs.y * 0.12, 60, 130)
	var y := vs.y * 0.17
	ban_strip.size = Vector2(vs.x * 1.3, h)
	ban_strip.pivot_offset = Vector2(vs.x * 0.65, h / 2)
	ban_strip.rotation = deg_to_rad(-3.5)
	ban_strip.position = Vector2(-vs.x * 1.4, y)
	ban_name.text = name
	ban_name.label_settings.font_size = int(clampf(vs.x * 0.055, 40, 96))
	ban_name.rotation = deg_to_rad(-3.5)
	ban_name.size = Vector2(vs.x, h)
	ban_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ban_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ban_name.position = Vector2(vs.x * 1.2, y)
	ban_sub.text = sub
	ban_sub.position = Vector2(vs.x * 0.08, y - 40)
	ban_sub.modulate.a = 0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ban_strip, "position:x", -vs.x * 0.15, 0.4)
	tw.tween_property(ban_name, "position:x", 0.0, 0.5).set_delay(0.1)
	tw.tween_property(ban_sub, "modulate:a", 1.0, 0.3).set_delay(0.35)
	sfx("taiko", 0, 0.9)

func hide_banner() -> void:
	if not banner.visible:
		return
	var vs := get_viewport().get_visible_rect().size
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(ban_strip, "position:x", vs.x * 1.2, 0.25)
	tw.tween_property(ban_name, "position:x", -vs.x * 1.2, 0.25)
	tw.tween_property(banner, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(func(): banner.visible = false)

func ono(text: String, world_pos: Vector3, cols: Dictionary, size := 150) -> void:
	var p := cam.unproject_position(world_pos)
	ono_lbl.text = text
	ono_lbl.label_settings.font_size = size
	ono_lbl.label_settings.font_color = Color.WHITE
	ono_lbl.label_settings.shadow_size = 1
	ono_lbl.label_settings.shadow_color = cols.b
	ono_lbl.label_settings.shadow_offset = Vector2(8, 8)
	ono_lbl.reset_size()
	var vs := get_viewport().get_visible_rect().size
	ono_lbl.position = Vector2(clampf(p.x, 200, vs.x - 200), clampf(p.y - 120, 140, vs.y - 260)) - ono_lbl.size / 2
	ono_lbl.pivot_offset = ono_lbl.size / 2
	ono_lbl.rotation = deg_to_rad(-9)
	ono_lbl.scale = Vector2.ONE * 2.6
	ono_lbl.modulate.a = 1
	ono_lbl.visible = true
	var tw := create_tween()
	tw.tween_property(ono_lbl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ono_lbl, "scale", Vector2.ONE * 1.08, 0.8)
	tw.parallel().tween_property(ono_lbl, "position:y", ono_lbl.position.y - 30, 0.8)
	tw.tween_property(ono_lbl, "modulate:a", 0.0, 0.25)

func caption(t: String) -> void:
	cap_lbl.text = t
	create_tween().tween_property(cap_lbl, "modulate:a", 1.0, 0.4)

func flash(a := 0.95, dur := 0.45, col := Color.WHITE) -> void:
	flash_rect.color = Color(col.r, col.g, col.b, a)
	create_tween().set_ignore_time_scale(true).tween_property(flash_rect, "color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func sfx(n: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not sfx_cache.has(n):
		sfx_cache[n] = load("res://sfx/%s.wav" % n)
	var s = sfx_cache[n]
	if s == null:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = s
			p.volume_db = vol_db
			p.pitch_scale = pitch * randf_range(0.95, 1.05)
			p.play()
			return

# ---------------- игра ----------------
func new_game() -> void:
	_game_id += 1
	busy = false
	state = Rules.init_state()
	hist = []
	log_lines = []
	over = {}
	sel = -1
	legal = []
	last_mv = {}
	render_all()
	refresh()

func render_all() -> void:
	for ch in world.get_children():
		ch.queue_free()
	els = []
	els.resize(64)
	for i in 64:
		if state.b[i] != 0:
			add_piece(state.b[i], i)

func add_piece(code: int, sq: int) -> Node3D:
	var g := Fig.piece(abs(code), sign(code))
	world.add_child(g)
	g.position = sq_pos(sq)
	els[sq] = g
	return g

func set_mode(i: int) -> void:
	mode = i
	opt_mode.select(i)
	opt_diff.disabled = i == MODE_PVP
	refresh()
	save_game()
	if not busy:
		maybe_ai()

func is_ai_turn() -> bool:
	return mode == MODE_AIAI or (mode == MODE_PVAI and state.turn == -1)

func refresh() -> void:
	var chk := Rules.king_sq(state.b, state.turn) if Rules.in_check(state) else -1
	for i in 64:
		var h: Dictionary = hl[i]
		var m = null
		for x in legal:
			if x.t == i:
				m = x
				break
		h.d.visible = m != null and m.x == 0
		h.r.visible = m != null and m.x != 0
		var col := Color(1, 1, 1, 0)
		if i == sel:
			col = Color(0.56, 0.89, 1, 0.45)
		elif i == chk:
			col = Color(1, 0.24, 0.35, 0.6)
		elif not last_mv.is_empty() and (last_mv.f == i or last_mv.t == i):
			col = Color(0.94, 0.75, 0.3, 0.3)
		h.tm.albedo_color = col
	if not over.is_empty():
		if over.type == "mate":
			lbl_who.text = "Белые победили" if over.win == 1 else "Чёрные победили"
			lbl_sub.text = "Мат. Король пал."
		else:
			lbl_who.text = "Ничья"
			lbl_sub.text = over.why
	else:
		lbl_who.text = "Ход белых" if state.turn == 1 else "Ход чёрных"
		lbl_who.label_settings.font_color = Color("fff4dc") if state.turn == 1 else Color("ff3d5a")
		var ai := is_ai_turn()
		if Rules.in_check(state):
			lbl_sub.text = "Шах! " + ("ИИ думает…" if ai else "Спасайте короля.")
		elif ai:
			lbl_sub.text = "ИИ думает…"
		elif busy:
			lbl_sub.text = "Фигура выполняет приказ…"
		elif sel >= 0:
			lbl_sub.text = "Куда пойдёт %s?" % Rules.NAMES[abs(state.b[sel])].to_lower()
		else:
			lbl_sub.text = "Выберите фигуру или напишите приказ"
	var cnt := {}
	for p in state.b:
		if p != 0:
			cnt[p] = cnt.get(p, 0) + 1
	var init := {5: 1, 4: 2, 3: 2, 2: 2, 1: 8}
	var gl := ["", "♟", "♞", "♝", "♜", "♛", "♚"]
	var lw := ""
	var lb := ""
	for t in [5, 4, 3, 2, 1]:
		for k in max(0, init[t] - cnt.get(-t, 0)):
			lw += gl[t]
		for k in max(0, init[t] - cnt.get(t, 0)):
			lb += gl[t]
	lbl_gw.text = "у белых: " + lw if lw != "" else "у белых: —"
	lbl_gb.text = "у чёрных: " + lb if lb != "" else "у чёрных: —"
	var txt := ""
	for i in range(0, log_lines.size(), 2):
		txt += "%d. %s    %s\n" % [i / 2 + 1, log_lines[i], log_lines[i + 1] if i + 1 < log_lines.size() else ""]
	log_box.text = txt
	btn_undo.disabled = hist.is_empty()

func notation(m: Dictionary, ns: Dictionary) -> String:
	if m.castle == 1:
		return "O-O"
	if m.castle == 2:
		return "O-O-O"
	var gl := ["", "♟", "♞", "♝", "♜", "♛", "♚"]
	var s: String = gl[m.p] + " " + Rules.sq_name(m.f) + ("×" if m.x != 0 else "–") + Rules.sq_name(m.t)
	if m.promo != 0:
		s += "=♛"
	if Rules.in_check(ns):
		s += "#" if Rules.gen(ns).is_empty() else "+"
	return s

func face_angle(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.x - from.x), -(to.z - from.z))

func turn_to(g: Node3D, ang: float, dur := 0.18) -> Tween:
	var a0 := g.rotation.y
	var d := wrapf(ang - a0, -PI, PI)
	var tw := create_tween()
	tw.tween_property(g, "rotation:y", a0 + d, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw

func walk(g: Node3D, to_pos: Vector3, knight := false) -> void:
	var p0 := g.position
	var steps: int = max(1, int(round(max(abs(to_pos.x - p0.x), abs(to_pos.z - p0.z)))))
	g.set_meta("idle", false)
	await turn_to(g, face_angle(p0, to_pos), 0.15).finished
	var dur: float = 0.7 if knight else min(1.5, 0.26 * steps + 0.12)
	var b: Node3D = g.get_node("body")
	var last_step := [0]
	var form: Node3D = g.get_meta("form") if g.has_meta("form") else null
	if form != null and not knight:
		Fig.play_anim(form, "walk", 1.7)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float):
		g.position = p0.lerp(to_pos, t)
		if knight:
			g.position.y = sin(t * PI) * 1.3
			b.rotation.x = -sin(t * PI) * 0.4
		elif form != null:
			var ph := t * steps
			if int(ph) > last_step[0]:
				last_step[0] = int(ph)
				sfx("step", -6)
		else:
			var ph := t * steps
			g.position.y = abs(sin(ph * PI)) * 0.16
			b.rotation.z = sin(ph * PI) * 0.12
			if int(ph) > last_step[0]:
				last_step[0] = int(ph)
				sfx("step", -6)
		, 0.0, 1.0, dur)
	await tw.finished
	g.position.y = 0
	b.rotation = Vector3.ZERO
	if form != null:
		Fig.play_anim(form, "idle")
	sfx("step", -4)
	fx.burst(to_pos, [Color("a99d86"), Color("6a5f72")], 14, 0.8, 0.6, 2.0, 0.12, 60, Vector3.UP, 0.25)
	await turn_to(g, g.get_meta("face"), 0.25).finished
	g.set_meta("idle", true)

func do_move(m: Dictionary) -> void:
	busy = true
	sel = -1
	legal = []
	refresh()
	var mover: int = state.turn
	var atk: Node3D = els[m.f]
	var vsq: int = m.ep_cap if m.ep_cap >= 0 else (m.t if m.x != 0 else -1)
	var vic: Node3D = els[vsq] if vsq >= 0 else null
	if vic != null:
		if ult_on:
			await ult.play(atk, vic, m)
		else:
			await ult.quick(atk, vic)
		els[vsq] = null
		await walk(atk, sq_pos(m.t), false)
	else:
		await walk(atk, sq_pos(m.t), m.p == Rules.N)
	if m.castle != 0:
		var base := 56 if mover == 1 else 0
		var rf := base + 7 if m.castle == 1 else base
		var rt := base + 5 if m.castle == 1 else base + 3
		var rk: Node3D = els[rf]
		await walk(rk, sq_pos(rt))
		els[rt] = rk
		els[rf] = null
	els[m.t] = atk
	if m.f != m.t:
		els[m.f] = null
	if m.promo != 0:
		var cols := Fig.side_cols(mover)
		sfx("choir", -6, 1.2)
		fx.pillar(sq_pos(m.t), cols.a, 0.5, 1.2)
		fx.burst(sq_pos(m.t) + Vector3.UP * 0.5, [cols.a, Color.WHITE], 140, 3.0, 1.2, -1.0, 0.15)
		await wait(0.35)
		atk.queue_free()
		var q := add_piece(mover * Rules.Q, m.t)
		q.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_property(q, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
		flash(0.5)
	var ns := Rules.apply(state, m)
	hist.append({"state": state, "last": last_mv, "log": log_lines.duplicate()})
	log_lines.append(notation(m, ns))
	if OS.is_debug_build():
		print("MOVE ", log_lines.size(), " ", log_lines[-1])
	state = ns
	last_mv = {"f": m.f, "t": m.t}
	check_over()
	busy = false
	refresh()
	save_game()
	maybe_ai()

func check_over() -> void:
	var ms := Rules.gen(state)
	if ms.is_empty():
		if Rules.in_check(state):
			over = {"type": "mate", "win": -state.turn}
			var k: Node3D = els[Rules.king_sq(state.b, state.turn)]
			if k != null:
				var cols := Fig.side_cols(-state.turn)
				await wait(0.4)
				flash()
				sfx("boom_big")
				fx.ring(k.position, cols.a, 6)
				fx.burst(k.position + Vector3.UP * 0.6, [cols.a, Color.WHITE], 300, 7, 1.2)
				fx.shatter(k, k.position + Vector3(0, 0, 1), 1.3)
				toast("МАТ! " + ("Белые" if over.win == 1 else "Чёрные") + " победили")
		else:
			over = {"type": "draw", "why": "Пат: ходить некуда."}
	else:
		var left := []
		for p in state.b:
			if p != 0:
				left.append(abs(p))
		if left.size() == 2:
			over = {"type": "draw", "why": "Остались одни короли."}
		elif left.size() == 3 and (Rules.N in left or Rules.B in left):
			over = {"type": "draw", "why": "Матовать нечем."}
	if not over.is_empty() and mode == MODE_AIAI:
		get_tree().create_timer(4.0).timeout.connect(func():
			if mode == MODE_AIAI and not over.is_empty() and not busy:
				new_game()
				save_game()
				maybe_ai())

func maybe_ai() -> void:
	if not over.is_empty() or not is_ai_turn() or _ai_thread != null or demo_running:
		return
	busy = true
	refresh()
	_ai_game = _game_id
	_ai_thread = Thread.new()
	_ai_started = Time.get_ticks_msec()
	_ai_wait = 0.9 if mode == MODE_AIAI else 0.35
	var s := Rules.copy_state(state)
	var d := depth
	_ai_thread.start(func(): return Rules.best_move(s, d))

func undo() -> void:
	if busy or cine or hist.is_empty():
		return
	var h: Dictionary = hist.pop_back()
	if mode == MODE_PVAI and h.state.turn == -1 and not hist.is_empty():
		h = hist.pop_back()
	state = h.state
	last_mv = h.last
	log_lines = h.log
	over = {}
	sel = -1
	legal = []
	render_all()
	refresh()
	save_game()

# ---------------- ввод ----------------
func _unhandled_input(e: InputEvent) -> void:
	if cine and ((e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed and e.keycode == KEY_SPACE)):
		speed = 3.0
		_apply_time()
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var s := pick(e.position)
		if s >= 0:
			click_sq(s)

func pick(sp: Vector2) -> int:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var best := -1
	var best_t := 1e9
	for i in 64:
		var g = els[i]
		if g == null:
			continue
		for y in [0.2, 0.5, 0.8, 1.1]:
			var p: Vector3 = g.position + Vector3(0, y, 0)
			var t := (p - o).dot(d)
			if t <= 0:
				continue
			if (o + d * t).distance_to(p) < 0.3 and t < best_t:
				best_t = t
				best = i
	if best >= 0:
		return best
	if abs(d.y) < 0.0001:
		return -1
	var t2 := -o.y / d.y
	if t2 <= 0:
		return -1
	var hp := o + d * t2
	var c := int(floor(hp.x + 4.0))
	var r := int(floor(hp.z + 4.0))
	if c < 0 or c > 7 or r < 0 or r > 7:
		return -1
	return r * 8 + c

func click_sq(i: int) -> void:
	if busy or cine or not over.is_empty() or is_ai_turn():
		return
	var p: int = state.b[i]
	if sel >= 0:
		for m in legal:
			if m.t == i:
				do_move(m)
				return
	if sel >= 0 and els[sel] != null:
		els[sel].get_node("body").position.y = 0
	if p != 0 and sign(p) == state.turn:
		sel = i
		legal = Rules.gen(state).filter(func(m): return m.f == i)
		sfx("step", -8, 1.3)
	else:
		sel = -1
		legal = []
	refresh()

const RU := {"пешка": 1, "пешку": 1, "пешкой": 1, "конь": 2, "коня": 2, "конем": 2, "слон": 3, "слона": 3, "слоном": 3,
	"ладья": 4, "ладью": 4, "ладьей": 4, "тура": 4, "ферзь": 5, "ферзя": 5, "ферзем": 5, "королева": 5, "король": 6, "короля": 6, "королем": 6}

func _on_cmd() -> void:
	var txt := cmd_edit.text
	if busy or cine or not over.is_empty() or is_ai_turn():
		toast("Сейчас не ваш ход.")
		return
	var r = parse_cmd(txt)
	if r is String:
		toast(r)
		return
	cmd_edit.text = ""
	toast("%s %s → %s: «Слушаюсь!»" % [Rules.NAMES[r.p], Rules.sq_name(r.f), Rules.sq_name(r.t)])
	do_move(r)

func parse_cmd(txt: String):
	var s := txt.to_lower().replace("ё", "е").strip_edges()
	var moves := Rules.gen(state)
	if "рокиров" in s or "o-o" in s or "0-0" in s:
		var long := "длинн" in s or "o-o-o" in s or "0-0-0" in s
		for m in moves:
			if m.castle == (2 if long else 1):
				return m
		return "Рокировка сейчас невозможна."
	var map := {"а": "a", "в": "b", "с": "c", "е": "e"}
	var sqs := []
	var re := RegEx.new()
	re.compile("([a-hавсе])\\s*([1-8])")
	for mt in re.search_all(s):
		var l: String = mt.get_string(1)
		sqs.append(map.get(l, l) + mt.get_string(2))
	var piece := 0
	for w in s.split(" ", false):
		if RU.has(w):
			piece = RU[w]
			break
	if sqs.size() >= 2:
		var f := Rules.sq_index(sqs[0])
		var t := Rules.sq_index(sqs[1])
		for m in moves:
			if m.f == f and m.t == t:
				return m
		return "Ход %s–%s невозможен." % [sqs[0], sqs[1]]
	if sqs.size() == 1:
		var t := Rules.sq_index(sqs[0])
		var c := moves.filter(func(m): return m.t == t and (piece == 0 or m.p == piece))
		if piece == 0 and c.size() > 1:
			var pw := c.filter(func(m): return m.p == Rules.P)
			if pw.size() > 0:
				c = pw
		if c.size() == 1:
			return c[0]
		if c.is_empty():
			return "Никто не может пойти на %s." % sqs[0]
		return "На %s могут пойти несколько фигур — уточните, например «%s %s»." % [sqs[0], Rules.sq_name(c[0].f), sqs[0]]
	return "Не понял приказ. Примеры: «конь f3», «e2 e4», «рокировка»."

# ---------------- меню, настройки, сохранение ----------------
func can_open_menu() -> bool:
	return not cine and not demo_running and (not busy or _ai_thread != null)

func start_game(m: int) -> void:
	session = true
	new_game()
	set_mode(m)   # сохранит партию и при необходимости запустит ИИ

func save_game() -> void:
	if demo_running or not session:
		return
	if not over.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_var({"v": 1, "state": state, "hist": hist, "log": log_lines, "last": last_mv, "mode": mode, "depth": depth})

func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	if not (d is Dictionary) or d.get("v", 0) != 1 or not d.has("state"):
		return {}
	return d

func has_save() -> bool:
	return not _read_save().is_empty()

func load_game() -> bool:
	var d := _read_save()
	if d.is_empty():
		return false
	_game_id += 1
	busy = false
	state = d.state
	hist = d.hist
	log_lines = d.log
	last_mv = d.last
	over = {}
	sel = -1
	legal = []
	set_depth(d.get("depth", depth))
	mode = d.get("mode", MODE_PVAI)
	opt_mode.select(mode)
	opt_diff.disabled = mode == MODE_PVP
	session = true
	render_all()
	refresh()
	return true

func load_settings() -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS_PATH)
	set_volume(c.get_value("audio", "volume", volume), false)
	set_fullscreen(c.get_value("video", "fullscreen", fullscreen), false)
	set_ult(c.get_value("game", "ults", ult_on), false)
	set_depth(c.get_value("game", "depth", depth), false)

func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "volume", volume)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("game", "ults", ult_on)
	c.set_value("game", "depth", depth)
	c.save(SETTINGS_PATH)

func set_volume(v: float, store := true) -> void:
	volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	if store:
		save_settings()

func set_fullscreen(on: bool, store := true) -> void:
	fullscreen = on
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if store:
		save_settings()

func set_ult(on: bool, store := true) -> void:
	ult_on = on
	chk_ult.set_pressed_no_signal(on)
	if store:
		save_settings()

func set_depth(d: int, store := true) -> void:
	depth = clampi(d, 1, 3)
	opt_diff.select(depth - 1)
	if store:
		save_settings()

# ---------------- демонстрация ----------------
func demo(only := "") -> void:
	if busy:
		return
	demo_running = true
	busy = true
	var saved := {"state": state, "hist": hist, "log": log_lines, "last": last_mv, "over": over}
	var types := [Rules.P, Rules.N, Rules.B, Rules.R, Rules.Q, Rules.K]
	var victims := [Rules.R, Rules.Q, Rules.N, Rules.B, Rules.R, Rules.Q]
	for i in types.size():
		for c in [1, -1]:
			var t: int = types[i]
			var key := "pnbrqk"[i] + ("w" if c == 1 else "b")
			if only != "" and not (key in only.split(",")):
				continue
			var b := PackedInt32Array()
			b.resize(64)
			var f := 44 if c == 1 else 19
			var dist: int = {1: 9, 2: 17, 3: 18, 4: 24, 5: 27, 6: 9}[t]
			var to: int = f - dist if c == 1 else f + dist
			if t == Rules.K:
				to = f - 8 if c == 1 else f + 8
			b[f] = c * t
			b[to] = -c * victims[i]
			if t != Rules.K:
				b[60 if c == 1 else 4] = c * Rules.K
			b[63 if c == 1 else 7] = -c * Rules.K
			state = {"b": b, "turn": c, "cr": PackedInt32Array([0, 0, 0, 0]), "ep": -1}
			render_all()
			refresh()
			await wait(0.6)
			var m := {"f": f, "t": to, "p": t, "x": -c * victims[i], "promo": 0, "dbl": false, "ep_cap": -1, "castle": 0}
			await ult.play(els[f], els[to], m)
			await wait(0.5)
	state = saved.state
	hist = saved.hist
	log_lines = saved.log
	last_mv = saved.last
	over = saved.over
	render_all()
	demo_running = false
	busy = false
	refresh()
	maybe_ai()
