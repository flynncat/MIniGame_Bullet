@tool
## Draws a shop item's in-game sprite as its icon (reuses the world drawing code).
class_name ItemIcon
extends Control

@export var item: DefenseCatalog.Item = DefenseCatalog.Item.TURRET:
	set(value):
		item = value
		queue_redraw()
## Draws the upgraded look (gold badge / upgraded caltrop colours).
var upgraded: bool = false:
	set(value):
		upgraded = value
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(44, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c: Vector2 = size * 0.5
	match item:
		DefenseCatalog.Item.ROCKET:
			Turret.draw_rocket(self, c - DefenseCatalog.ROCKET_SIZE * 0.5, false, 0.0)
		DefenseCatalog.Item.CALTROP:
			draw_set_transform(c, 0.0, Vector2(1.3, 1.3))
			Caltrop.draw_caltrop(self, -DefenseCatalog.CALTROP_SIZE * 0.5, 0.3, 1.0, upgraded)
			draw_set_transform(Vector2.ZERO)
		_:
			Turret.draw_gun(self, c - DefenseCatalog.TURRET_SIZE * 0.5, 7, false, 0.0)
	if upgraded:
		DrawUtil.upgrade_badge(self, Vector2(size.x - 7, 7))
