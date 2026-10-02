@tool
## Collectible coin. Node position = top-left of the 16x16 coin.
class_name Coin
extends Area2D

## Emitted once when the runner touches the coin.
signal collected(coin: Coin)

const SIZE: float = 16.0

var _phase: float = 0.0
var _anim_t: float = 0.0
var _taken: bool = false

func _ready() -> void:
	collision_layer = Palette.LAYER_PICKUP
	collision_mask = Palette.LAYER_PLAYER
	monitorable = false
	# 2 px pickup margin, same as the web version.
	RectShape.apply(self, -1, Rect2(-2, -2, SIZE + 4, SIZE + 4))
	_phase = randf() * 6.0
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim_t += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body is Player):
		return
	_taken = true
	collected.emit(self)
	set_deferred(&"monitoring", false)
	queue_free()

func _draw() -> void:
	var bob: float = sin(_anim_t * 3.0 + _phase) * 4.0
	var sq: float = 0.35 + absf(cos(_anim_t * 3.4 + _phase)) * 0.65
	var c := Vector2(8, 8 + bob)
	draw_set_transform(c, 0.0, Vector2(sq, 1.0))
	draw_circle(Vector2.ZERO, 8.0, Color("#ffd76a"))
	draw_circle(Vector2(-2, -2), 3.0, Color("#fff2b8"))
	draw_set_transform(Vector2.ZERO)
