@tool
## Static level platform. Node position = top-left corner; resize with [member size] in the Inspector.
## SOLID blocks from every side, ONEWAY can be jumped through from below and dropped through with Down.
class_name Platform
extends StaticBody2D

enum Kind { SOLID, ONEWAY }

@export var size: Vector2 = Vector2(120, 18):
	set(value):
		size = value.max(Vector2(6, 6))
		_rebuild()
@export var kind: Kind = Kind.SOLID:
	set(value):
		kind = value
		_rebuild()

var _shape_owner: int = -1

func _ready() -> void:
	_rebuild()

func get_rect_global() -> Rect2:
	return Rect2(global_position, size)

func _rebuild() -> void:
	if not is_inside_tree():
		return
	collision_layer = Palette.LAYER_ONEWAY if kind == Kind.ONEWAY else Palette.LAYER_SOLID
	collision_mask = 0
	var shape_rect := Rect2(Vector2.ZERO, size)
	if kind == Kind.ONEWAY:
		# One-way shapes only need a thin top edge; the visual keeps full height.
		shape_rect = Rect2(Vector2.ZERO, Vector2(size.x, minf(size.y, 8.0)))
	_shape_owner = RectShape.apply(self, _shape_owner, shape_rect, kind == Kind.ONEWAY)
	queue_redraw()

func _draw() -> void:
	if kind == Kind.ONEWAY:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#a9713d"))
		draw_rect(Rect2(0, 0, size.x, 4), Color("#c98c52"))
		var x: float = 6.0
		while x < size.x:
			draw_rect(Rect2(x, 4, 2, size.y - 4), Color(0, 0, 0, 0.18))
			x += 22.0
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#7a4a2b"))
	draw_rect(Rect2(0, 0, size.x, 6), Color("#5aa86e"))
	draw_rect(Rect2(0, 6, size.x, 2), Color(1, 1, 1, 0.14))
	if size.y > 30.0:
		var bx: float = 10.0
		while bx < size.x - 6.0:
			draw_rect(Rect2(bx, 14, 10, 8), Color(0, 0, 0, 0.16))
			bx += 26.0
