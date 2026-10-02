@tool
## Root of a level scene. Holds level metadata and typed accessors for its content.
## Expected children (created by the template / bootstrap tool):
##   Spikes (Node2D), Goal (Goal), Coins (Node2D), Platforms (Node2D), Turrets (Node2D), Spawn (SpawnPoint)
## Everything else can be freely added, moved and resized in the 2D editor.
class_name Level
extends Node2D

@export var level_name: String = "新关卡":
	set(value):
		level_name = value
		queue_redraw()
## World size in pixels. Height below 540 is clamped; tall worlds scroll vertically.
@export var world_size: Vector2i = Vector2i(2000, 540):
	set(value):
		world_size = Vector2i(maxi(960, value.x), clampi(value.y, int(Palette.BASE_H), 12000))
		queue_redraw()
@export var theme: Palette.ThemeId = Palette.ThemeId.DAY:
	set(value):
		theme = value
		queue_redraw()

@onready var spawn: SpawnPoint = $Spawn
@onready var goal: Goal = $Goal
@onready var platforms_root: Node2D = $Platforms

func get_spawn_top_left() -> Vector2:
	return spawn.position - SpawnPoint.BODY * 0.5

func get_coins() -> Array[Coin]:
	var out: Array[Coin] = []
	_collect(self, out, Coin)
	return out

func get_turrets() -> Array[Turret]:
	var out: Array[Turret] = []
	_collect(self, out, Turret)
	return out

func get_spikes() -> Array[Spike]:
	var out: Array[Spike] = []
	_collect(self, out, Spike)
	return out

func _collect(node: Node, out: Array, type: Variant) -> void:
	for child: Node in node.get_children():
		if is_instance_of(child, type):
			out.append(child)
		_collect(child, out, type)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(Vector2.ZERO, Vector2(world_size))
	var colors: Palette.ThemeColors = Palette.get_theme(theme)
	draw_rect(rect, Color(colors.sky[1], 0.18))
	draw_rect(rect, Color(1.0, 0.36, 0.48, 0.9), false, 2.0)
	# Camera frame (960 x 1350) anchored at the world's bottom-left, for scale reference.
	var cam := Rect2(Vector2(0, world_size.y - Palette.VIEW_SIZE.y), Palette.VIEW_SIZE)
	DrawUtil.dashed_line(self, cam.position, Vector2(cam.end.x, cam.position.y), Color(0.47, 0.78, 1.0, 0.6), 2.0, 10.0, 8.0)
	DrawUtil.dashed_line(self, Vector2(cam.end.x, cam.position.y), cam.end, Color(0.47, 0.78, 1.0, 0.6), 2.0, 10.0, 8.0)
	DrawUtil.text(self, Vector2(8, -18), "%s   %d x %d" % [level_name, world_size.x, world_size.y], 18, Color(1.0, 0.36, 0.48), HORIZONTAL_ALIGNMENT_LEFT, true)
