@tool
## Level finish flag. Node position = top-left of the 46x86 trigger.
class_name Goal
extends Area2D

## Emitted when the runner touches the flag.
signal reached

const SIZE: Vector2 = Vector2(46, 86)

var _anim_t: float = 0.0
var _done: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = Palette.LAYER_PLAYER
	monitorable = false
	RectShape.apply(self, -1, Rect2(Vector2.ZERO, SIZE))
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_anim_t += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if _done or not (body is Player):
		return
	_done = true
	reached.emit()

func _draw() -> void:
	var glow := Rect2(-6, -60, SIZE.x + 12, SIZE.y + 60)
	var cols := PackedColorArray([Color(1, 0.88, 0.55, 0.0), Color(1, 0.88, 0.55, 0.0), Color(1, 0.88, 0.55, 0.35), Color(1, 0.88, 0.55, 0.35)])
	draw_polygon(PackedVector2Array([glow.position, Vector2(glow.end.x, glow.position.y), glow.end, Vector2(glow.position.x, glow.end.y)]), cols)
	draw_rect(Rect2(4, -10, 5, SIZE.y + 10), Color("#d8d2c4"))
	var wav: float = sin(_anim_t * 4.0) * 5.0
	var flag := PackedVector2Array()
	for i: int in 9:
		var t: float = i / 8.0
		flag.append(Vector2(9, -4).lerp(Vector2(44, -2), t) + Vector2(0, sin(t * PI) * (8.0 + wav)))
	for i: int in 9:
		var t: float = i / 8.0
		flag.append(Vector2(44, 26 + wav * 0.4).lerp(Vector2(9, 24), t) + Vector2(0, sin(t * PI) * (4.0 + wav)))
	draw_colored_polygon(flag, Color("#ff5c7a"))
	DrawUtil.round_rect(self, Rect2(-4, SIZE.y - 8, SIZE.x + 8, 10), 4.0, Color("#ffd76a"))
