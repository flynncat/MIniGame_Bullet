## Parallax sky: gradient (blends to the high-altitude colours as you climb), stars, clouds,
## far hills for horizontal levels, or a cloud sea for tall towers. Lives on a background
## CanvasLayer and reads the viewport's camera each frame.
class_name SkyBackdrop
extends Node2D

var _theme: Palette.ThemeColors = Palette.get_theme(0)
var _world: Vector2 = Vector2(960, 540)
var _clouds: Array[Vector4] = []  # x, y, scale, speed
var _stars: Array[Vector4] = []   # x, y, radius, phase
var _anim_t: float = 0.0

func configure(theme_id: int, world_size: Vector2) -> void:
	_theme = Palette.get_theme(theme_id)
	_world = world_size
	_clouds.clear()
	_stars.clear()
	var cn: int = clampi(roundi(10.0 * world_size.y / Palette.BASE_H), 10, 80)
	for i: int in cn:
		_clouds.append(Vector4(randf_range(0, world_size.x), randf_range(30, world_size.y * 0.98), randf_range(0.6, 1.5), randf_range(4, 14)))
	if theme_id == Palette.ThemeId.NIGHT:
		var sn: int = clampi(roundi(70.0 * world_size.y / Palette.BASE_H), 70, 400)
		for i: int in sn:
			_stars.append(Vector4(randf_range(0, world_size.x), randf_range(20, world_size.y * 0.98), randf_range(0.6, 1.8), randf_range(0, 6)))
	queue_redraw()

func _process(delta: float) -> void:
	_anim_t += delta
	if not get_tree().paused:
		for i: int in _clouds.size():
			var c: Vector4 = _clouds[i]
			c.x += c.w * delta
			if c.x > _world.x + 120.0:
				c.x = -120.0
			_clouds[i] = c
	queue_redraw()

func _camera_pos() -> Vector2:
	var cam := get_viewport().get_camera_2d() as GameCamera
	return cam.top_left() if cam else Vector2.ZERO

func _draw() -> void:
	var v: Vector2 = Palette.VIEW_SIZE
	var cam: Vector2 = _camera_pos()
	var wh: float = _world.y
	var alt: float = clampf(cam.y / maxf(1.0, wh - v.y), 0.0, 1.0) * 0.85 if wh > v.y else 0.0
	var c0: Color = _theme.sky[0].lerp(_theme.high[0], alt)
	var c1: Color = _theme.sky[1].lerp(_theme.high[1], alt)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(v.x, 0), v, Vector2(0, v.y)]), PackedColorArray([c0, c0, c1, c1]))

	for s: Vector4 in _stars:
		var p := Vector2(s.x - cam.x * 0.25, s.y - cam.y * 0.35)
		if p.x < -5 or p.x > v.x + 5 or p.y < -5 or p.y > v.y + 5:
			continue
		draw_circle(p, s.z, Color(1, 1, 1, 0.4 + 0.6 * absf(sin(s.w + _anim_t * 1.6))))

	var cloud_col := Color(1, 1, 1, 0.72)
	for c: Vector4 in _clouds:
		var p := Vector2(c.x - cam.x * 0.4, c.y - cam.y * 0.45)
		if p.x < -140 or p.x > v.x + 140 or p.y < -80 or p.y > v.y + 80:
			continue
		var k: float = c.z
		draw_circle(p, 20 * k, cloud_col)
		draw_circle(p + Vector2(22, -8) * k, 26 * k, cloud_col)
		draw_circle(p + Vector2(48, 2) * k, 20 * k, cloud_col)
		draw_rect(Rect2(p + Vector2(-4, 0) * k, Vector2(58, 18) * k), cloud_col)

	if wh <= Palette.BASE_H + 60.0:
		var b0: float = wh - cam.y
		_draw_hills(b0, cam.x * 0.18, 220.0, 140.0, 290.0, 14, _theme.hill2)
		_draw_hills(b0, cam.x * 0.32, 300.0, 100.0, 220.0, 10, _theme.hill)
		var gy: float = 470.0 - cam.y
		if gy < v.y and gy + 70.0 > 0.0:
			draw_rect(Rect2(0, gy, v.x, 70), _theme.deco)
	else:
		var gy: float = wh - cam.y
		if gy > -160.0 and gy < v.y + 160.0:
			var sea := Color(1, 1, 1, 0.85)
			for i: int in range(-1, 12):
				var bx: float = i * 132.0 - fmod(cam.x * 0.6, 132.0)
				draw_circle(Vector2(bx, gy + 14), 54, sea)
				draw_circle(Vector2(bx + 64, gy - 10), 40, sea)
			draw_rect(Rect2(0, gy + 24, v.x, maxf(0.0, v.y - gy - 24)), sea)

func _draw_hills(base_y: float, scroll: float, period: float, low: float, high: float, count: int, color: Color) -> void:
	var start_x: float = -period - fmod(scroll, period)
	var pts := PackedVector2Array([Vector2(minf(-50.0, start_x - 1.0), base_y), Vector2(start_x, base_y - low)])
	for i: int in range(-1, count):
		var bx: float = i * period - fmod(scroll, period)
		pts.append(Vector2(bx + period * 0.5, base_y - high))
		pts.append(Vector2(bx + period, base_y - low))
	pts.append(Vector2(Palette.VIEW_SIZE.x + 100, base_y))
	draw_colored_polygon(pts, color)
