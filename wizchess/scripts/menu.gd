class_name Menu
extends CanvasLayer
## Главное меню: иллюстрация на фоне, мраморная плита с короной, заголовком и кнопками.
## Пока меню открыто, игра стоит на паузе; Esc в игре открывает меню снова.

## Название на плите — поменяйте здесь, если нужно «Живые шахматы»
const TITLE := ["БОЕВЫЕ", "ШАХМАТЫ"]
const BG_SIZE := Vector2(1672, 941)
## Мраморная плита на фоновой картинке (в её пикселях); содержимое меню живёт внутри неё
const SLAB := Rect2(22, 0, 474, 790)
## Свечи на картинке — для мерцающих ореолов
const CANDLES := [Vector2(515, 122), Vector2(585, 255), Vector2(1075, 262), Vector2(1258, 255),
	Vector2(1625, 105), Vector2(1615, 230), Vector2(860, 150)]
const DIFF := ["НОВИЧОК", "РЫЦАРЬ", "МАГИСТР"]

const TITLE_SHADER := """
shader_type canvas_item;
// Золото с вертикальным градиентом и пробегающим бликом.
// Заливка текста белая, обводка/тень чёрные — по COLOR.r отличаем одно от другого.
uniform vec4 c_top : source_color = vec4(1.0, 0.95, 0.78, 1.0);
uniform vec4 c_mid : source_color = vec4(0.90, 0.67, 0.30, 1.0);
uniform vec4 c_bot : source_color = vec4(0.50, 0.29, 0.08, 1.0);
uniform vec4 c_edge : source_color = vec4(0.07, 0.035, 0.01, 1.0);
uniform float y0 = 0.0;
uniform float y1 = 80.0;
uniform float phase = 0.0;
varying vec2 p;
void vertex() { p = VERTEX; }
void fragment() {
	float t = clamp((p.y - y0) / max(1.0, y1 - y0), 0.0, 1.0);
	vec3 g = t < 0.45 ? mix(c_top.rgb, c_mid.rgb, t / 0.45) : mix(c_mid.rgb, c_bot.rgb, (t - 0.45) / 0.55);
	float band = mod(TIME * 160.0 + phase, 1900.0) - 400.0;
	float s = 1.0 - smoothstep(0.0, 34.0, abs(p.x + p.y * 0.45 - band));
	g += vec3(1.0, 0.92, 0.75) * s * 0.6;
	COLOR.rgb = mix(c_edge.rgb, g, COLOR.r);
}
"""

var g   # main.gd
var root: Control
var stage: Control
var bg: TextureRect
var mirror: TextureRect
var slab: Control
var crown: MenuDeco
var titles := []
var divider: MenuDeco
var pages := {}
var page := ""
var refreshers := []
var btn_continue: MenuBtn
var font_title: FontVariation
var font_btn: FontVariation
var glows := []
var snd: AudioStreamPlayer
var is_open := false
var _pending := false
var _clock := 0.0
var _busy_tw: Tween

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ff: Font = load("res://ui/Forum-Regular.ttf")
	font_title = FontVariation.new()
	font_title.base_font = ff
	font_title.variation_embolden = 0.9
	font_title.spacing_glyph = 1
	font_btn = FontVariation.new()
	font_btn.base_font = ff
	font_btn.variation_embolden = 0.2
	font_btn.spacing_glyph = 2
	snd = AudioStreamPlayer.new()
	add_child(snd)
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()

# ---------------- построение ----------------
func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # клики не проходят к доске
	add_child(root)
	var under := ColorRect.new()
	under.color = Color("07050a")
	under.set_anchors_preset(Control.PRESET_FULL_RECT)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(under)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = BG_SIZE
	root.add_child(stage)
	bg = TextureRect.new()
	bg.texture = load("res://ui/menu_bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = BG_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	# если экран шире картинки — справа её зеркальное продолжение, притушенное
	mirror = TextureRect.new()
	mirror.texture = bg.texture
	mirror.flip_h = true
	mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mirror.stretch_mode = TextureRect.STRETCH_SCALE
	mirror.position = Vector2(BG_SIZE.x, 0)
	mirror.size = BG_SIZE
	mirror.modulate = Color(0.45, 0.42, 0.48)
	mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror.visible = false
	stage.add_child(mirror)
	_build_glows()
	_build_embers()
	# виньетка
	var vig := TextureRect.new()
	var vt := GradientTexture2D.new()
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.62, 0.45)
	vt.fill_to = Vector2(1.25, 1.1)
	vt.gradient = Gradient.new()
	vt.gradient.set_color(0, Color(0, 0, 0, 0))
	vt.gradient.set_color(1, Color(0, 0, 0, 0.55))
	vig.texture = vt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.size = BG_SIZE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(vig)
	# плита
	slab = Control.new()
	slab.position = SLAB.position
	slab.size = SLAB.size
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(slab)
	var rim := ColorRect.new()   # полированная кромка плиты
	rim.color = Color(0.85, 0.62, 0.3, 0.22)
	rim.position = Vector2(SLAB.size.x - 2, 0)
	rim.size = Vector2(2, SLAB.size.y - 30)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab.add_child(rim)
	var cx := 258.0
	crown = MenuDeco.new(MenuDeco.KIND_CROWN)
	crown.position = Vector2(cx - 200, 50)
	crown.size = Vector2(400, 84)
	slab.add_child(crown)
	var sh := Shader.new()
	sh.code = TITLE_SHADER
	for i in TITLE.size():
		var l := Label.new()
		l.text = TITLE[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ls := LabelSettings.new()
		ls.font = font_title
		ls.font_size = _fit_size(TITLE[i], 468.0, 106)
		ls.font_color = Color.WHITE
		ls.outline_size = 7
		ls.outline_color = Color.BLACK
		ls.shadow_size = 10
		ls.shadow_color = Color(0, 0, 0, 0.75)
		ls.shadow_offset = Vector2(0, 5)
		l.label_settings = ls
		l.size = Vector2(500, 96)
		l.position = Vector2(cx - 250, 128 + i * 84)
		var m := ShaderMaterial.new()
		m.shader = sh
		var fs: float = ls.font_size
		m.set_shader_parameter("y0", 48.0 - fs * 0.40)
		m.set_shader_parameter("y1", 48.0 + fs * 0.36)
		m.set_shader_parameter("phase", -i * 60.0)
		l.material = m
		slab.add_child(l)
		titles.append(l)
	divider = MenuDeco.new(MenuDeco.KIND_DIVIDER)
	divider.font = font_btn
	divider.font_size = 21
	divider.position = Vector2(cx - 180, 318)
	divider.size = Vector2(360, 30)
	slab.add_child(divider)
	_page_main()
	_page_play()
	_page_settings()

func _fit_size(t: String, max_w: float, want: int) -> int:
	var fs := want
	while fs > 40 and font_title.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 2
	return fs

func _build_glows() -> void:
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.gradient = Gradient.new()
	gt.gradient.set_color(0, Color(1.0, 0.72, 0.36, 0.55))
	gt.gradient.set_color(1, Color(1.0, 0.5, 0.15, 0.0))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in CANDLES.size():
		var t := TextureRect.new()
		t.texture = gt
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = Vector2(110, 110)
		t.position = CANDLES[i] - t.size / 2
		t.material = add
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(t)
		glows.append(t)

func _build_embers() -> void:
	var p := CPUParticles2D.new()
	var dot := GradientTexture2D.new()
	dot.width = 16
	dot.height = 16
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.gradient = Gradient.new()
	dot.gradient.set_color(0, Color(1, 0.9, 0.6, 1))
	dot.gradient.set_color(1, Color(1, 0.6, 0.2, 0))
	p.texture = dot
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	p.amount = 46
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.local_coords = true
	p.position = Vector2(BG_SIZE.x * 0.5, BG_SIZE.y + 20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(BG_SIZE.x * 0.5, 30)
	p.direction = Vector2(0.15, -1)
	p.spread = 22.0
	p.gravity = Vector2(0, -4)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 75.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.8
	p.angular_velocity_min = 0
	p.angular_velocity_max = 0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.8, 0.45, 0))
	ramp.add_point(0.15, Color(1, 0.8, 0.45, 0.9))
	ramp.add_point(0.7, Color(1, 0.6, 0.25, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 0.5, 0.2, 0))
	p.color_ramp = ramp
	p.hue_variation_min = -0.03
	p.hue_variation_max = 0.03
	stage.add_child(p)

func _page(rows: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = Vector2(58, 368)
	v.size = Vector2(400, 350)
	v.add_theme_constant_override("separation", 20 if rows <= 4 else 12)
	v.visible = false
	slab.add_child(v)
	return v

func _btn(v: Control, t: String, fsize := 33, h := 70.0) -> MenuBtn:
	var b := MenuBtn.new(t, font_btn, fsize)
	b.custom_minimum_size = Vector2(400, h)
	b.focus_entered.connect(func(): _snd("step", -18.0, 1.9))
	b.pressed.connect(func(): _snd("sheath", -10.0, 1.15))
	v.add_child(b)
	return b

## Кнопка-переключатель: клик/→ — следующее значение, правый клик/← — предыдущее
func _cycler(v: Control, label: String, get_txt: Callable, step: Callable) -> MenuBtn:
	var b := _btn(v, "", 24, 58.0)
	b.cycle = true
	var upd := func(): b.text = label + ":  " + str(get_txt.call())
	upd.call()
	refreshers.append(upd)
	b.pressed.connect(func():
		step.call(1)
		upd.call())
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			step.call(-1)
			upd.call()
			_snd("sheath", -10.0, 1.15)
		elif e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
			step.call(1 if e.is_action_pressed("ui_right") else -1)
			upd.call()
			_snd("sheath", -10.0, 1.15)
			b.accept_event())
	return b

func _page_main() -> void:
	var v := _page(4)
	pages["main"] = v
	_btn(v, "ИГРАТЬ").pressed.connect(func(): go("play"))
	btn_continue = _btn(v, "ПРОДОЛЖИТЬ")
	btn_continue.pressed.connect(_on_continue)
	_btn(v, "НАСТРОЙКИ").pressed.connect(func(): go("settings"))
	_btn(v, "ВЫХОД").pressed.connect(func(): get_tree().quit())

func _page_play() -> void:
	var v := _page(5)
	pages["play"] = v
	var names := ["ПРОТИВ ИИ", "ВДВОЁМ", "ИИ ПРОТИВ ИИ"]
	for i in names.size():
		var m: int = i
		_btn(v, names[i], 29, 58.0).pressed.connect(func(): _start(m))
	_cycler(v, "СЛОЖНОСТЬ", func(): return DIFF[g.depth - 1],
		func(d: int): g.set_depth(wrapi(g.depth - 1 + d, 0, 3) + 1))
	_btn(v, "НАЗАД", 29, 58.0).pressed.connect(func(): go("main"))

func _page_settings() -> void:
	var v := _page(5)
	pages["settings"] = v
	_cycler(v, "ГРОМКОСТЬ", func(): return "%d%%" % roundi(g.volume * 100),
		func(d: int): g.set_volume(wrapf(snappedf(g.volume + d * 0.1, 0.1), -0.05, 1.05)))
	_cycler(v, "ПОЛНЫЙ ЭКРАН", func(): return "ВКЛ" if g.fullscreen else "ВЫКЛ",
		func(_d: int): g.set_fullscreen(not g.fullscreen))
	_cycler(v, "УЛЬТЫ ПРИ ВЗЯТИИ", func(): return "ВКЛ" if g.ult_on else "ВЫКЛ",
		func(_d: int): g.set_ult(not g.ult_on))
	_cycler(v, "СЛОЖНОСТЬ ИИ", func(): return DIFF[g.depth - 1],
		func(d: int): g.set_depth(wrapi(g.depth - 1 + d, 0, 3) + 1))
	_btn(v, "НАЗАД", 29, 58.0).pressed.connect(func(): go("main"))

# ---------------- раскладка ----------------
## Картинка прижата к левому верхнему углу и заполняет экран; снизу допускаем
## обрезку не больше ~12%, иначе (сверхширокий экран) справа видно её зеркальное продолжение.
func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var s := minf(maxf(vs.x / BG_SIZE.x, vs.y / BG_SIZE.y), vs.y / (BG_SIZE.y * 0.88))
	stage.scale = Vector2(s, s)
	stage.position = Vector2.ZERO
	mirror.visible = BG_SIZE.x * s < vs.x - 1.0

func _process(delta: float) -> void:
	if not visible:
		if _pending and g.can_open_menu():
			_pending = false
			open_menu()
		return
	_clock += delta
	for i in glows.size():
		var f := 0.75 + sin(_clock * (7.0 + i * 1.3) + i * 2.1) * 0.12 + sin(_clock * 17.0 + i) * 0.06 + randf() * 0.07
		glows[i].modulate.a = f
		glows[i].scale = Vector2.ONE * (0.95 + f * 0.08)
		glows[i].pivot_offset = glows[i].size / 2
	crown.position.y = 50 + sin(_clock * 1.6) * 2.0

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE):
		return
	get_viewport().set_input_as_handled()
	if is_open:
		if page != "main":
			go("main")
		elif g.session:
			_snd("sheath", -10.0, 1.15)
			close_menu()
	elif visible:
		return
	elif g.can_open_menu():
		open_menu()
	else:
		_pending = true   # идёт ход или ульта — откроем, как только закончится

# ---------------- открытие / страницы ----------------
func open_menu(intro := false) -> void:
	if is_open:
		return
	is_open = true
	_pending = false
	get_tree().paused = true
	visible = true
	_go_now("main")
	btn_continue.disabled = not (g.session or g.has_save())
	if _busy_tw != null:
		_busy_tw.kill()
	if intro:
		root.modulate.a = 1.0
		g.get_viewport().disable_3d = true
		_intro()
	else:
		root.modulate.a = 0.0
		_busy_tw = create_tween()
		_busy_tw.tween_property(root, "modulate:a", 1.0, 0.3)
		_busy_tw.tween_callback(func(): g.get_viewport().disable_3d = true)
	_focus_first()

func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	g.get_viewport().disable_3d = false
	get_tree().paused = false
	if _busy_tw != null:
		_busy_tw.kill()
	_busy_tw = create_tween()
	_busy_tw.tween_property(root, "modulate:a", 0.0, 0.35)
	_busy_tw.tween_callback(func(): visible = false)

func _intro() -> void:
	var items: Array = [crown]
	items.append_array(titles)
	items.append(divider)
	items.append_array(pages.main.get_children())
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in items.size():
		var c: Control = items[i]
		c.modulate.a = 0.0
		var d := 0.15 + i * 0.09
		tw.tween_property(c, "modulate:a", 1.0, 0.6).set_delay(d)
		if c is MenuBtn:
			var x := c.position.x
			c.position.x = x - 40
			tw.tween_property(c, "position:x", x, 0.6).set_delay(d)

func go(name: String) -> void:
	if name == page:
		return
	var old: Control = pages.get(page)
	page = name
	divider.set_label({"main": "", "play": "НОВАЯ ПАРТИЯ", "settings": "НАСТРОЙКИ"}[name])
	for r in refreshers:
		r.call()
	var nw: Control = pages[name]
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if old != null:
		tw.tween_property(old, "modulate:a", 0.0, 0.12)
		tw.parallel().tween_property(old, "position:x", 58.0 - 24.0, 0.12)
		tw.tween_callback(func(): old.visible = false)
	nw.modulate.a = 0.0
	nw.position.x = 58.0 + 24.0
	tw.tween_callback(func():
		nw.visible = true
		_focus_first())
	tw.tween_property(nw, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(nw, "position:x", 58.0, 0.22)

func _go_now(name: String) -> void:
	page = name
	divider.set_label("")
	for k in pages:
		var p: Control = pages[k]
		p.visible = k == name
		p.modulate.a = 1.0
		p.position.x = 58.0
	for r in refreshers:
		r.call()

func _focus_first() -> void:
	var p: Control = pages.get(page)
	if p == null:
		return
	for b in p.get_children():
		if b is MenuBtn and not b.disabled:
			b.grab_focus()
			return

# ---------------- действия ----------------
func _on_continue() -> void:
	if g.session:
		close_menu()
	elif g.load_game():
		close_menu()
		g.maybe_ai()
	else:
		btn_continue.disabled = true
		_focus_first()

func _start(m: int) -> void:
	_snd("taiko", -6.0, 1.0)
	close_menu()
	g.start_game(m)

func _snd(n: String, vol := 0.0, pitch := 1.0) -> void:
	var s = load("res://sfx/%s.wav" % n)
	if s == null:
		return
	snd.stream = s
	snd.volume_db = vol
	snd.pitch_scale = pitch
	snd.play()
