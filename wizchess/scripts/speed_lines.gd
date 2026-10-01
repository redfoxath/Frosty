class_name SpeedLines
extends Control
## Манга-линии: 1 — линии концентрации к точке, 2 — горизонтальные линии скорости.

var mode := 0
var center := Vector2.ZERO
var col := Color(1, 1, 1, 1)
var _was := 0

func _process(_d: float) -> void:
	if mode != 0 or _was != 0:
		queue_redraw()
	_was = mode

func _draw() -> void:
	if mode == 0:
		return
	var s := size
	if mode == 1:
		var R := s.length()
		for i in 70:
			var a := randf() * TAU
			var r0: float = min(s.x, s.y) * randf_range(0.22, 0.4)
			var w := randf_range(0.004, 0.016)
			var c := col
			c.a = randf_range(0.08, 0.32)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(cos(a), sin(a)) * r0,
				center + Vector2(cos(a - w), sin(a - w)) * R,
				center + Vector2(cos(a + w), sin(a + w)) * R]), c)
	else:
		for i in 46:
			var c := col
			c.a = randf_range(0.08, 0.35)
			draw_rect(Rect2(randf_range(-0.2, 1.0) * s.x, randf() * s.y, s.x * randf_range(0.2, 0.6), randf_range(1.0, 3.0)), c)
