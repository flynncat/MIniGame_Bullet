@tool
## Player-2 item identifiers and fixed visual footprints.
## All tunable numbers (price, fire rate, arm time, ...) live in DefenseConfig (res://config/).
class_name DefenseCatalog
extends RefCounted

enum Item { NONE, TURRET, ROCKET, CALTROP }

const TURRET_SIZE: Vector2 = Vector2(34, 26)
const ROCKET_SIZE: Vector2 = Vector2(38, 30)
const CALTROP_SIZE: Vector2 = Vector2(26, 16)

static func needs_direction(item: Item) -> bool:
	return item == Item.TURRET or item == Item.ROCKET

static func shop_items() -> Array[Item]:
	return [Item.TURRET, Item.ROCKET, Item.CALTROP]
