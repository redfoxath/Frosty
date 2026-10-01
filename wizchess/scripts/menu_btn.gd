class_name MenuBtn
extends Button
## Кнопка главного меню: тёмная плашка, двойная золотая рамка со срезанными углами,
## ромбы по краям. При наведении/фокусе рамка разгорается, ромбы вырастают.

const GOLD := Color("d6a754")
const GOLD_HI := Color("ffe3a3")
const GOLD_DIM := Color("6e5228")

## Переключатель «‹ значение ›»: рисует стрелки по бокам
var cycle := false
var hl := 0.0
var _frame: Control

func _init(t := "", fnt: Font = null, fsize := 30) -> void:
	text = t
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, 70)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if fnt != null:
		add_theme_font_override("font", fnt)
	add_theme_font_size_override("font_size", fsize)
	add_theme_color_override("font_color", Color("e4cf9f"))
	for k in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(k, Color("fff4da"))
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", Color(0.62, 0.55, 0.44, 0.45))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("outline_size", 5)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	# рамку рисуем дочерним узлом «позади родителя», чтобы текст кнопки был поверх
	_frame = Control.new()
	_frame.show_behind_parent = true
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	mouse_entered.connect(func():
		if not disabled:
			grab_focus())

func _process(delta: float) -> void:
	var to := 1.0 if (has_focus() or is_hovered()) and not disabled else 0.0
	if button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not disabled):
		to = 1.25
	if not is_equal_approx(hl, to):
		hl = move_toward(hl, to, delta * 6.0)
		_frame.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _frame != null:
		_frame.queue_redraw()

static func _oct(r: Rect2, cut: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([
		Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut),
		Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y),
		Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut)])

static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q

static func diamond(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill_top: Color, fill_bot: Color, edge: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)])
	ci.draw_polygon(pts, PackedColorArray([fill_top, fill_top.lerp(fill_bot, 0.5), fill_bot, fill_top.lerp(fill_bot, 0.5)]))
	ci.draw_polyline(_closed(pts), edge, 1.0, true)

func _draw_frame() -> void:
	var f := _frame
	var s := size
	var k := clampf(hl, 0.0, 1.0)
	var boost := maxf(0.0, hl - 1.0) * 4.0
	var a := 0.45 if disabled else 1.0
	var r := Rect2(Vector2.ZERO, s)
	var cut := minf(10.0, s.y * 0.16)
	# свечение вокруг активной кнопки
	if k > 0.01:
		for i in 5:
			var g := 2.0 + i * 2.5
			var pts := _oct(r.grow(g), cut + g * 0.6)
			f.draw_polyline(_closed(pts), Color(1.0, 0.72, 0.3, (0.16 - i * 0.03) * k), 2.5, true)
	# плашка: вертикальный градиент
	var top := Color(0.085, 0.072, 0.066, 0.93).lerp(Color(0.22, 0.15, 0.07, 0.95), k * 0.8 + boost * 0.3)
	var bot := Color(0.018, 0.016, 0.02, 0.95).lerp(Color(0.07, 0.045, 0.025, 0.96), k)
	var poly := _oct(r, cut)
	var cols := PackedColorArray()
	for p in poly:
		cols.append(top.lerp(bot, p.y / maxf(1.0, s.y)))
	f.draw_polygon(poly, cols)
	# блик по верхней кромке
	f.draw_line(Vector2(cut + 4, 3), Vector2(s.x - cut - 4, 3), Color(1, 0.85, 0.55, 0.05 + 0.1 * k), 2.0)
	# двойная рамка
	var outer := GOLD.lerp(GOLD_HI, k)
	outer.a = a
	f.draw_polyline(_closed(poly), outer, 1.6 + k * 0.6, true)
	var inner := GOLD_DIM.lerp(GOLD, k * 0.7)
	inner.a = 0.9 * a
	f.draw_polyline(_closed(_oct(r.grow(-5), maxf(2.0, cut - 3))), inner, 1.0, true)
	# ромбы на торцах
	var dr := lerpf(6.0, 12.0, k)
	var dy := s.y * 0.5
	for x in [0.0, s.x]:
		var c := Vector2(x, dy)
		if k > 0.01:
			f.draw_circle(c, dr * 1.9, Color(1.0, 0.75, 0.35, 0.12 * k))
			f.draw_circle(c, dr * 1.1, Color(1.0, 0.8, 0.45, 0.18 * k))
		var tc := Color("fff0c4").lerp(Color("ffe08a"), 1.0 - k)
		tc.a = a
		var bc := Color("8a5f24")
		bc.a = a
		diamond(f, c, dr * 0.75, dr * 1.15, tc, bc, Color(0.12, 0.07, 0.02, a))
	# стрелки переключателя
	if cycle:
		var ac := GOLD.lerp(GOLD_HI, k)
		ac.a = (0.55 + 0.45 * k) * a
		var m := 20.0
		var h := 7.0
		f.draw_colored_polygon(PackedVector2Array([Vector2(m, dy), Vector2(m + h, dy - h), Vector2(m + h, dy + h)]), ac)
		f.draw_colored_polygon(PackedVector2Array([Vector2(s.x - m, dy), Vector2(s.x - m - h, dy - h), Vector2(s.x - m - h, dy + h)]), ac)
