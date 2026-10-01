class_name MenuDeco
extends Control
## Украшения меню: корона над заголовком и разделитель-ромб (с подписью раздела).

const KIND_CROWN := 0
const KIND_DIVIDER := 1

var kind := KIND_CROWN
var label := ""
var font: Font
var font_size := 22

func _init(k := KIND_CROWN) -> void:
	kind = k
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_label(t: String) -> void:
	label = t
	queue_redraw()

func _draw() -> void:
	if kind == KIND_CROWN:
		_crown()
	else:
		_divider()

## Линия, растворяющаяся к дальнему концу
func _fade_line(a: Vector2, b: Vector2, col: Color, w := 1.2) -> void:
	var n := 12
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var c := col
		c.a = col.a * (1.0 - t0)
		draw_line(a.lerp(b, t0), a.lerp(b, t1), c, w, true)

func _crown() -> void:
	var s := size
	var cx := s.x * 0.5
	var w := s.y * 1.05          # ширина короны от высоты контрола
	var h := s.y
	var x0 := cx - w * 0.5
	var p := func(u: float, v: float) -> Vector2: return Vector2(x0 + u * w, v * h)
	var hi := Color("fff0c2")
	var mid := Color("e2b25a")
	var lo := Color("8c5a1e")
	var edge := Color(0.16, 0.09, 0.02, 1)
	# линии по сторонам у основания
	var by: float = h * 0.86
	_fade_line(Vector2(cx - w * 0.62, by), Vector2(cx - s.x * 0.5, by), Color(0.85, 0.64, 0.3, 0.8))
	_fade_line(Vector2(cx + w * 0.62, by), Vector2(cx + s.x * 0.5, by), Color(0.85, 0.64, 0.3, 0.8))
	# тело короны: три зубца
	var body := PackedVector2Array([p.call(0.12, 0.72), p.call(0.02, 0.30), p.call(0.30, 0.50), p.call(0.5, 0.16),
		p.call(0.70, 0.50), p.call(0.98, 0.30), p.call(0.88, 0.72)])
	var cols := PackedColorArray()
	for q in body:
		cols.append(hi.lerp(lo, clampf((q.y / h - 0.15) / 0.6, 0, 1)))
	draw_polygon(body, cols)
	var cl := body.duplicate()
	cl.append(body[0])
	draw_polyline(cl, edge, 1.4, true)
	# внутренние грани
	draw_line(p.call(0.30, 0.50), p.call(0.30, 0.72), Color(0.4, 0.24, 0.06, 0.8), 1.0, true)
	draw_line(p.call(0.70, 0.50), p.call(0.70, 0.72), Color(0.4, 0.24, 0.06, 0.8), 1.0, true)
	# обруч
	var band := PackedVector2Array([p.call(0.10, 0.72), p.call(0.90, 0.72), p.call(0.88, 0.90), p.call(0.12, 0.90)])
	draw_polygon(band, PackedColorArray([mid, mid, lo, lo]))
	var bl := band.duplicate()
	bl.append(band[0])
	draw_polyline(bl, edge, 1.4, true)
	draw_line(p.call(0.13, 0.76), p.call(0.87, 0.76), Color(1, 0.93, 0.7, 0.6), 1.0, true)
	# камни на обруче
	for u in [0.3, 0.5, 0.7]:
		MenuBtn.diamond(self, p.call(u, 0.81), w * 0.035, h * 0.05, Color("fff6d8"), Color("b07a30"), edge)
	# шары на зубцах и навершие
	for q in [Vector2(0.02, 0.27), Vector2(0.98, 0.27)]:
		var c: Vector2 = p.call(q.x, q.y)
		draw_circle(c, w * 0.055, edge)
		draw_circle(c, w * 0.045, mid)
		draw_circle(c - Vector2(1, 1) * w * 0.015, w * 0.018, hi)
	MenuBtn.diamond(self, p.call(0.5, 0.08), w * 0.06, h * 0.1, hi, mid.lerp(lo, 0.4), edge)
	draw_circle(p.call(0.5, 0.2), w * 0.03, hi)

func _divider() -> void:
	var s := size
	var c := s * 0.5
	var gold := Color(0.86, 0.66, 0.32, 0.95)
	var gap := 16.0
	if label != "" and font != null:
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		gap = tw * 0.5 + 22.0
		var asc := font.get_ascent(font_size)
		var dsc := font.get_descent(font_size)
		var base := Vector2(c.x - tw * 0.5, c.y + (asc - dsc) * 0.5)
		draw_string_outline(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
		draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f0d397"))
		for d in [-1, 1]:
			MenuBtn.diamond(self, Vector2(c.x + d * (gap - 8.0), c.y), 3.0, 5.0, Color("fff0c2"), Color("a8752c"), Color(0.15, 0.08, 0.02))
	else:
		MenuBtn.diamond(self, c, 7.0, 12.0, Color("fff0c2"), Color("a8752c"), Color(0.15, 0.08, 0.02))
		draw_circle(c + Vector2(-gap - 2, 0), 1.6, gold)
		draw_circle(c + Vector2(gap + 2, 0), 1.6, gold)
		gap += 8.0
	_fade_line(Vector2(c.x - gap, c.y), Vector2(0, c.y), gold)
	_fade_line(Vector2(c.x + gap, c.y), Vector2(s.x, c.y), gold)
