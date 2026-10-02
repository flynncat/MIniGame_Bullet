@tool
## Platform that ping-pongs along one axis. Node position = start (top-left) of the path.
## The dashed line drawn in the editor shows the travel range.
class_name MovingPlatform
extends AnimatableBody2D

enum Axis { HORIZONTAL, VERTICAL }

@export var size: Vector2 = Vector2(110, 18):
	set(value):
		size = value.max(Vector2(10, 6))
		_rebuild()
@export var axis: Axis = Axis.HORIZONTAL:
	set(value):
		axis = value
		queue_redraw()
## Travel distance in pixels.
@export_range(30.0, 2000.0, 1.0) var distance: float = 120.0:
	set(value):
		distance = value
		queue_redraw()
## Travel speed in pixels per second.
@export_range(5.0, 600.0, 1.0) var speed: float = 60.0

var _shape_owner: int = -1
var _base: Vector2 = Vector2.ZERO
var _progress: float = 0.0
var _dir: float = 1.0

func _ready() -> void:
	_base = position
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	collision_layer = Palette.LAYER_MOVING
	collision_mask = 0
	_shape_owner = RectShape.apply(self, _shape_owner, Rect2(Vector2.ZERO, size))
	queue_redraw()

func _axis_vector() -> Vector2:
	return Vector2.RIGHT if axis == Axis.HORIZONTAL else Vector2.DOWN

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_progress += delta * (speed / maxf(30.0, distance)) * _dir
	if _progress >= 1.0:
		_progress = 1.0
		_dir = -1.0
	elif _progress <= 0.0:
		_progress = 0.0
		_dir = 1.0
	position = _base + _axis_vector() * (_progress * distance)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#4b6bb5"))
	draw_rect(Rect2(0, 0, size.x, 6), Color("#6f97e8"))
	draw_rect(Rect2(0, 6, size.x, 2), Color(1, 1, 1, 0.14))
	var glyph: String = "→" if axis == Axis.HORIZONTAL else "↕"
	DrawUtil.text(self, Vector2(size.x * 0.5, size.y * 0.5), glyph, 12, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, true)
	# Travel track, drawn relative to the current offset so it stays fixed in world space.
	var offset: Vector2 = Vector2.ZERO if Engine.is_editor_hint() else (_base - position)
	var track_color := Color(1, 1, 1, 0.25)
	if axis == Axis.HORIZONTAL:
		var y: float = size.y * 0.5
		DrawUtil.dashed_line(self, offset + Vector2(0, y), offset + Vector2(distance, y), track_color, 1.0, 4.0, 4.0)
	else:
		var x: float = size.x * 0.5
		DrawUtil.dashed_line(self, offset + Vector2(x, 0), offset + Vector2(x, distance), track_color, 1.0, 4.0, 4.0)
	if Engine.is_editor_hint():
		var ghost := Rect2(_axis_vector() * distance, size)
		draw_rect(ghost, Color(0.44, 0.59, 0.91, 0.35), false, 1.0)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()
