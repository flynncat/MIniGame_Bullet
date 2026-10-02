@tool
## Round settings button with a vector gear icon (the bundled font has no gear glyph).
class_name SettingsButton
extends Button

func _init() -> void:
	custom_minimum_size = Vector2(44, 44)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "设置"
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	var hover: bool = is_hovered()
	draw_circle(c, r, Color("#26304c") if hover else Color(0.086, 0.114, 0.192, 0.92))
	draw_arc(c, r - 0.5, 0.0, TAU, 40, Color(1, 1, 1, 0.22), 1.0, true)
	var col := Color("#ffd76a") if hover else Color("#cfd8ec")
	var teeth: int = 8
	var outer: float = r * 0.62
	var inner: float = r * 0.46
	var pts := PackedVector2Array()
	for i: int in teeth * 4:
		var a: float = float(i) / float(teeth * 4) * TAU
		var rad: float = outer if (i % 4 == 1 or i % 4 == 2) else inner
		pts.append(c + Vector2.from_angle(a) * rad)
	draw_colored_polygon(pts, col)
	draw_circle(c, r * 0.2, Color("#161d31"))
