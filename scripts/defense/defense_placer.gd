## Player-2 mouse placement inside the game view: press = position, drag = direction, release = place.
## Right click / cancel action aborts. Emits [signal place_requested]; the Game validates and executes.
class_name DefensePlacer
extends Node2D

signal place_requested(item: DefenseCatalog.Item, world_pos: Vector2, dir_index: int)
signal selection_changed(item: DefenseCatalog.Item)

const DRAG_MIN: float = 24.0

var item: DefenseCatalog.Item = DefenseCatalog.Item.NONE
## Used to draw the upgraded look on the placement preview (set by Game).
var defense: DefenseController
var enabled: bool = false:
	set(value):
		enabled = value
		if not value:
			cancel()

var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _last_dir: int = 0

func _ready() -> void:
	# Placement preview is drawn semi-transparent.
	self_modulate = Color(1, 1, 1, 0.62)

func select(p_item: DefenseCatalog.Item) -> void:
	item = DefenseCatalog.Item.NONE if p_item == item else p_item
	_pressing = false
	selection_changed.emit(item)

func cancel() -> void:
	if item == DefenseCatalog.Item.NONE and not _pressing:
		return
	item = DefenseCatalog.Item.NONE
	_pressing = false
	selection_changed.emit(item)

func is_placing() -> bool:
	return item != DefenseCatalog.Item.NONE

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or item == DefenseCatalog.Item.NONE:
		return
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
		if mb.pressed:
			cancel()
			get_viewport().set_input_as_handled()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		begin_drag(get_global_mouse_position())
	else:
		end_drag(get_global_mouse_position())
	get_viewport().set_input_as_handled()

## Press: fixes the placement position (world coordinates).
func begin_drag(world_pos: Vector2) -> void:
	if item == DefenseCatalog.Item.NONE:
		return
	_pressing = true
	_press_pos = world_pos

## Release: direction = drag vector (press -> release); short drags reuse the last direction.
func end_drag(world_pos: Vector2) -> void:
	if not _pressing:
		return
	var dir: int = _dir_between(_press_pos, world_pos)
	_pressing = false
	_last_dir = dir
	place_requested.emit(item, _press_pos, dir)

func _dir_between(from: Vector2, to: Vector2) -> int:
	var v: Vector2 = to - from
	return Palette.dir_from_vector(v, _last_dir) if v.length() >= DRAG_MIN else _last_dir

func _current_dir() -> int:
	return _dir_between(_press_pos, get_global_mouse_position()) if _pressing else _last_dir

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not enabled or item == DefenseCatalog.Item.NONE:
		return
	var mouse: Vector2 = get_global_mouse_position()
	var anchor: Vector2 = _press_pos if _pressing else mouse
	var snapped: Vector2 = (anchor / 10.0).round() * 10.0
	var dir: int = _current_dir()
	match item:
		DefenseCatalog.Item.ROCKET:
			Turret.draw_rocket(self, snapped - DefenseCatalog.ROCKET_SIZE * 0.5, false, 0.0)
			DrawUtil.aim_line(self, snapped, dir, 150.0)
		DefenseCatalog.Item.CALTROP:
			Caltrop.draw_caltrop(self, snapped - DefenseCatalog.CALTROP_SIZE * 0.5, 0.0, 1.0, _upgraded())
		_:
			Turret.draw_gun(self, snapped - DefenseCatalog.TURRET_SIZE * 0.5, dir, false, 0.0)
			DrawUtil.aim_line(self, snapped, dir, 170.0)

	if _upgraded():
		DrawUtil.upgrade_badge(self, snapped + Vector2(22, -18))

func _upgraded() -> bool:
	return defense != null and defense.is_item_upgraded(item)
