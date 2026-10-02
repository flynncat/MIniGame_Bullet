## Canvas drawing helpers shared by world objects, HUD and UI icons.
class_name DrawUtil
extends RefCounted

const FONT_PATH: String = "res://assets/fonts/ui_font.ttf"
static var _font: Font = null
static var _bold: FontVariation = null

static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
	return _font

static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = font()
		_bold.variation_embolden = 0.7
	return _bold

## Filled rounded rectangle (corner radius clamped to half the shortest side).
static func round_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r <= 0.5 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		ci.draw_rect(rect, color)
		return
	var pts := PackedVector2Array()
	var corners: Array[Vector2] = [
		rect.position + Vector2(rect.size.x - r, r),
		rect.position + Vector2(rect.size.x - r, rect.size.y - r),
		rect.position + Vector2(r, rect.size.y - r),
		rect.position + Vector2(r, r),
	]
	var start_angles: PackedFloat32Array = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c: int in 4:
		for s: int in 5:
			var a: float = start_angles[c] + (PI * 0.5) * float(s) / 4.0
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, color)

static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, is_bold: bool = false) -> void:
	var f: Font = bold() if is_bold else font()
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	# pos.y is treated as the vertical middle of the text line.
	var y: float = pos.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5
	ci.draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

## Gold double chevron marking an upgraded unit; [param at] = badge centre.
static func upgrade_badge(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_circle(at, 7.5, Color("#2a2210"))
	ci.draw_circle(at, 6.5, Color("#ffd76a"))
	for k: int in 2:
		var y: float = at.y + 2.5 - k * 4.0
		ci.draw_polyline(PackedVector2Array([Vector2(at.x - 3.5, y), Vector2(at.x, y - 3.0), Vector2(at.x + 3.5, y)]), Color("#5a3d00"), 1.6, true)

## Arm (charging) countdown: pulsing halo + ring + remaining seconds.
static func arm_badge(ci: CanvasItem, center: Vector2, remaining: float, total: float, anim_t: float) -> void:
	var r: float = 16.0
	var pulse: float = 0.5 + 0.5 * sin(anim_t * 8.0)
	ci.draw_circle(center, r + 7.0, Color(1.0, 0.824, 0.29, 0.10 + 0.13 * pulse))
	ci.draw_arc(center, r, 0.0, TAU, 32, Color(1, 1, 1, 0.22), 3.0, true)
	var frac: float = 1.0 - clampf(remaining / maxf(total, 0.001), 0.0, 1.0)
	if frac > 0.0:
		ci.draw_arc(center, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Color("#ffd24a"), 3.0, true)
	text(ci, center, str(maxi(1, ceili(remaining))), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)

## Dashed line from a to b.
static func dashed_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var total: float = a.distance_to(b)
	if total <= 0.0:
		return
	var dir: Vector2 = (b - a) / total
	var d: float = 0.0
	while d < total:
		var e: float = minf(d + dash, total)
		ci.draw_line(a + dir * d, a + dir * e, color, width)
		d = e + gap

## Aim line with arrow head used by turret placement previews.
static func aim_line(ci: CanvasItem, from: Vector2, dir_index: int, length: float) -> void:
	var d: Vector2 = Palette.dir_vector(dir_index)
	var tip: Vector2 = from + d * length
	dashed_line(ci, from, tip, Color(1.0, 0.624, 0.263, 0.85), 2.0, 9.0, 7.0)
	var a: float = d.angle()
	var head := PackedVector2Array([
		tip + Vector2.from_angle(a) * 12.0,
		tip + Vector2.from_angle(a + 2.5) * 11.0,
		tip + Vector2.from_angle(a - 2.5) * 11.0,
	])
	ci.draw_colored_polygon(head, Color(1.0, 0.624, 0.263, 0.9))
