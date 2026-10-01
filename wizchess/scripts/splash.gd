class_name Splash
extends CanvasLayer
## Заставка студии перед меню: из темноты проявляется ледяной лис, вспыхивают глаза,
## надпись нарастает инеем слева направо, по логотипу пробегает блик.
## Клик или любая клавиша — пропустить.

signal finished   # экран уже чёрный: можно открывать меню под ним

const LOGO_SIZE := Vector2(1962, 802)     # исходный логотип целиком
const FOX_RECT := Rect2(0, 0, 700, 802)    # ui/logo_fox.png в его координатах
const TEXT_RECT := Rect2(660, 0, 1302, 802) # ui/logo_text.png
const EYES := [Vector2(254, 405), Vector2(440, 403)]

const LOGO_SHADER := """
shader_type canvas_item;
// Проявление инеем по экрану слева направо, ледяная кромка, пробегающий блик.
uniform float reveal = 2.0;  // граница проявления, доля ширины экрана
uniform float shine = -1.0;  // положение блика, доля ширины экрана
uniform float glow = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec4 c = COLOR;
	// зубчатая «кристаллическая» граница
	float n = hash(floor(SCREEN_UV * vec2(220.0, 120.0)));
	float edge = reveal - SCREEN_UV.x + (n - 0.5) * 0.03;
	float vis = smoothstep(0.0, 0.012, edge);
	float rim = 1.0 - smoothstep(0.0, 0.035, abs(edge));
	vec3 rgb = c.rgb + vec3(0.55, 0.85, 1.0) * rim * 1.4;
	float s = 1.0 - smoothstep(0.0, 0.05, abs(SCREEN_UV.x - SCREEN_UV.y * 0.25 - shine));
	rgb += vec3(0.75, 0.93, 1.0) * s * 0.8;
	rgb += vec3(0.35, 0.65, 1.0) * glow * 0.18;
	COLOR = vec4(rgb, c.a * clamp(max(vis, rim * 0.85), 0.0, 1.0));
}
"""

var root: Control
var logo: Control
var fox: TextureRect
var text: TextureRect
var mat_fox: ShaderMaterial
var mat_text: ShaderMaterial
var halo: TextureRect
var eyes := []
var frost: CPUParticles2D
var snow: CPUParticles2D
var black: ColorRect
var snd: AudioStreamPlayer
var _tw: Tween
var _done := false
var _t := 0.0

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	snd = AudioStreamPlayer.new()
	add_child(snd)
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_play()

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	# фон: глубокая ночная синева
	var bg := TextureRect.new()
	var bt := GradientTexture2D.new()
	bt.fill = GradientTexture2D.FILL_RADIAL
	bt.fill_from = Vector2(0.5, 0.48)
	bt.fill_to = Vector2(1.1, 1.0)
	bt.gradient = Gradient.new()
	bt.gradient.set_color(0, Color("13253d"))
	bt.gradient.set_color(1, Color("02040a"))
	bg.texture = bt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	snow = _particles(Color(0.85, 0.93, 1.0), 70, 9.0)
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.direction = Vector2(0.2, 1)
	snow.spread = 20
	snow.gravity = Vector2(6, 12)
	snow.initial_velocity_min = 15
	snow.initial_velocity_max = 45
	snow.scale_amount_min = 0.15
	snow.scale_amount_max = 0.55
	snow.preprocess = 9.0
	root.add_child(snow)
	# логотип
	logo = Control.new()
	logo.size = LOGO_SIZE
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo = _glow_rect(Color(0.3, 0.6, 1.0, 0.5), Vector2(1100, 1100))
	halo.position = Vector2(350, 405) - halo.size / 2
	halo.material = add
	halo.modulate.a = 0
	logo.add_child(halo)
	var sh := Shader.new()
	sh.code = LOGO_SHADER
	mat_fox = ShaderMaterial.new()
	mat_fox.shader = sh
	mat_text = ShaderMaterial.new()
	mat_text.shader = sh
	mat_text.set_shader_parameter("reveal", -1.0)
	fox = _img("res://ui/logo_fox.png", FOX_RECT, mat_fox)
	text = _img("res://ui/logo_text.png", TEXT_RECT, mat_text)
	for e in EYES:
		var g := _glow_rect(Color(0.55, 0.9, 1.0, 1.0), Vector2(150, 150))
		g.position = e - g.size / 2
		g.pivot_offset = g.size / 2
		g.material = add
		g.modulate.a = 0
		logo.add_child(g)
		eyes.append(g)
	# ледяные искры у кромки проявления
	frost = _particles(Color(0.7, 0.92, 1.0), 90, 0.9)
	frost.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	frost.emission_rect_extents = Vector2(6, 190)
	frost.direction = Vector2(1, -0.3)
	frost.spread = 70
	frost.gravity = Vector2(0, 40)
	frost.initial_velocity_min = 40
	frost.initial_velocity_max = 160
	frost.scale_amount_min = 0.2
	frost.scale_amount_max = 0.6
	frost.emitting = false
	frost.position = Vector2(TEXT_RECT.position.x, 420)
	logo.add_child(frost)
	black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(black)

func _img(path: String, r: Rect2, m: ShaderMaterial) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = r.position
	t.size = r.size
	t.pivot_offset = r.size / 2
	t.material = m
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(t)
	return t

func _glow_rect(col: Color, sz: Vector2) -> TextureRect:
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.gradient = Gradient.new()
	gt.gradient.set_color(0, col)
	gt.gradient.set_color(1, Color(col.r, col.g, col.b, 0))
	var t := TextureRect.new()
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = sz
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _particles(col: Color, amount: int, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var dot := GradientTexture2D.new()
	dot.width = 16
	dot.height = 16
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.gradient = Gradient.new()
	dot.gradient.set_color(0, Color.WHITE)
	dot.gradient.set_color(1, Color(1, 1, 1, 0))
	p.texture = dot
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	p.amount = amount
	p.lifetime = life
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col.r, col.g, col.b, 0))
	ramp.add_point(0.2, col)
	ramp.set_color(ramp.get_point_count() - 1, Color(col.r, col.g, col.b, 0))
	p.color_ramp = ramp
	return p

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var s := minf(vs.x * 0.74 / LOGO_SIZE.x, vs.y * 0.52 / LOGO_SIZE.y)
	logo.scale = Vector2(s, s)
	logo.position = (vs - LOGO_SIZE * s) * 0.5
	snow.position = Vector2(vs.x * 0.5, -20)
	snow.emission_rect_extents = Vector2(vs.x * 0.6, 10)

## Доля ширины экрана для точки логотипа (x в пикселях логотипа)
func _sx(x: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return (logo.position.x + x * logo.scale.x) / maxf(1.0, vs.x)

func _play() -> void:
	fox.modulate.a = 0
	fox.scale = Vector2.ONE * 0.82
	var x0 := _sx(TEXT_RECT.position.x) - 0.02
	var x1 := _sx(LOGO_SIZE.x) + 0.04
	_tw = create_tween()
	_tw.tween_property(black, "color:a", 0.0, 0.5)
	# лис
	_tw.tween_callback(func(): _snd("whoosh", -6.0, 0.8))
	_tw.tween_property(fox, "modulate:a", 1.0, 0.7)
	_tw.parallel().tween_property(fox, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.parallel().tween_property(halo, "modulate:a", 1.0, 0.9)
	# вспышка глаз
	_tw.tween_callback(func():
		_snd("zap", -14.0, 1.6)
		for g in eyes:
			var e := create_tween()
			g.scale = Vector2.ONE * 0.3
			e.tween_property(g, "modulate:a", 1.0, 0.12)
			e.parallel().tween_property(g, "scale", Vector2.ONE * 1.3, 0.2)
			e.tween_property(g, "modulate:a", 0.35, 0.6)
			e.parallel().tween_property(g, "scale", Vector2.ONE * 0.6, 0.6))
	_tw.tween_interval(0.25)
	# иней проявляет надпись
	_tw.tween_callback(func():
		_snd("crack", -10.0, 1.35)
		frost.emitting = true)
	_tw.tween_method(func(v: float):
		mat_text.set_shader_parameter("reveal", v)
		var vs := get_viewport().get_visible_rect().size
		frost.position.x = (v * vs.x - logo.position.x) / logo.scale.x
		, x0, x1, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_callback(func(): frost.emitting = false)
	# блик по всему логотипу
	_tw.tween_callback(func(): _snd("choir", -16.0, 1.25))
	_tw.tween_method(func(v: float):
		mat_fox.set_shader_parameter("shine", v)
		mat_text.set_shader_parameter("shine", v)
		, _sx(0) - 0.15, _sx(LOGO_SIZE.x) + 0.15, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_interval(1.1)
	_tw.tween_callback(_finish)

func _process(delta: float) -> void:
	_t += delta
	var gl := 0.5 + sin(_t * 2.2) * 0.5
	mat_fox.set_shader_parameter("glow", gl)
	mat_text.set_shader_parameter("glow", gl)
	if halo.modulate.a > 0.5:
		halo.modulate.a = 0.85 + sin(_t * 1.7) * 0.15

func _input(e: InputEvent) -> void:
	if _done:
		return
	if (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed) \
			or (e is InputEventScreenTouch and e.pressed) or (e is InputEventJoypadButton and e.pressed):
		get_viewport().set_input_as_handled()
		_finish(0.25)

func _finish(dur := 0.6) -> void:
	if _done:
		return
	_done = true
	if _tw != null:
		_tw.kill()
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, dur)
	tw.tween_callback(func():
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in root.get_children():
			if c != black:
				c.visible = false
		finished.emit())
	tw.tween_property(black, "color:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _snd(n: String, vol := 0.0, pitch := 1.0) -> void:
	var s = load("res://sfx/%s.wav" % n)
	if s == null:
		return
	snd.stream = s
	snd.volume_db = vol
	snd.pitch_scale = pitch
	snd.play()
