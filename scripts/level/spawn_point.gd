@tool
## Runner spawn point. Node position = centre of the runner's 28x36 body.
## Only visible in the editor.
class_name SpawnPoint
extends Marker2D

const BODY: Vector2 = Vector2(28, 36)

func _ready() -> void:
	gizmo_extents = 6.0
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(-BODY * 0.5, BODY)
	draw_rect(r, Color(0.42, 0.94, 0.63, 0.25))
	draw_rect(r, Color("#6cf0a0"), false, 2.0)
	DrawUtil.text(self, r.position + Vector2(-6, -10), "START", 11, Color("#6cf0a0"), HORIZONTAL_ALIGNMENT_LEFT, true)
