## Game camera. Uses a top-left anchor so [member position] equals the web version's cam.x/cam.y.
## Worlds shorter than the view are bottom-aligned (camera y becomes negative).
class_name GameCamera
extends Camera2D

const FOLLOW_RATE: float = 9.0

var world_size: Vector2 = Vector2(960, 540)
var shake: float = 0.0

func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	position_smoothing_enabled = false

func view_size() -> Vector2:
	return Palette.VIEW_SIZE

func focus_ratio() -> float:
	return 0.62 if world_size.y > view_size().y * 0.8 else 0.72

func clamp_y(y: float, pad: float = 0.0) -> float:
	var d: float = world_size.y - view_size().y
	var lo: float = minf(0.0, d)
	return clampf(y, lo - pad, d + pad)

func target_for(focus: Vector2) -> Vector2:
	var v: Vector2 = view_size()
	return Vector2(
		clampf(focus.x - v.x * 0.5, 0.0, maxf(0.0, world_size.x - v.x)),
		clamp_y(focus.y - v.y * focus_ratio()))

func snap_to(focus: Vector2) -> void:
	position = target_for(focus)
	reset_smoothing()
	reset_physics_interpolation()

func follow(focus: Vector2, delta: float) -> void:
	position = position.lerp(target_for(focus), minf(1.0, delta * FOLLOW_RATE))

func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)

func _physics_process(delta: float) -> void:
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 40.0)

func _process(_delta: float) -> void:
	offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) * 0.4 if shake > 0.0 else Vector2.ZERO

## Top-left of the visible area in world coordinates (without shake).
func top_left() -> Vector2:
	return position
