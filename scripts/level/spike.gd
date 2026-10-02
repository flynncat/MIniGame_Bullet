@tool
## Row of spikes. Node position = top-left; width controls the number of teeth.
class_name Spike
extends Hazard

@export var size: Vector2 = Vector2(44, 12):
	set(value):
		size = value.max(Vector2(8, 6))
		_rebuild()

var _shape_owner: int = -1

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_shape_owner = RectShape.apply(self, _shape_owner, Rect2(Vector2.ZERO, size))
	queue_redraw()

func _draw() -> void:
	var n: int = maxi(1, roundi(size.x / 11.0))
	var tooth: float = size.x / float(n)
	for i: int in n:
		var bx: float = i * tooth
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx, size.y), Vector2(bx + tooth * 0.5, 0.0), Vector2(bx + tooth, size.y),
		]), Color("#c9d2e0"))
	draw_rect(Rect2(0, size.y - 2, size.x, 3), Color(0, 0, 0, 0.2))
