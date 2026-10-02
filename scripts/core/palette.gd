## Static colour themes and shared layout constants ported from the web version.
class_name Palette
extends RefCounted

enum ThemeId { DAY, DUSK, NIGHT }

## Camera (game view) size. The web version renders a 960x1350 canvas.
const VIEW_SIZE: Vector2 = Vector2(960.0, 1350.0)
## Design height of the original horizontal levels.
const BASE_H: float = 540.0

## Physics layer bit values (see project.godot layer_names).
const LAYER_SOLID: int = 1
const LAYER_ONEWAY: int = 2
const LAYER_PLAYER: int = 4
const LAYER_MOVING: int = 8
const LAYER_HAZARD: int = 16
const LAYER_PICKUP: int = 32

class ThemeColors:
	var sky: PackedColorArray
	var high: PackedColorArray
	var hill: Color
	var hill2: Color
	var deco: Color

	func _init(p_sky: PackedColorArray, p_high: PackedColorArray, p_hill: Color, p_hill2: Color, p_deco: Color) -> void:
		sky = p_sky
		high = p_high
		hill = p_hill
		hill2 = p_hill2
		deco = p_deco

static func get_theme(id: int) -> ThemeColors:
	match clampi(id, 0, 2):
		ThemeId.DUSK:
			return ThemeColors.new(PackedColorArray([Color("#f7a45c"), Color("#ffd9a0")]), PackedColorArray([Color("#7a4b8f"), Color("#e2a6c4")]), Color("#a9603f"), Color("#87452f"), Color("#6f3826"))
		ThemeId.NIGHT:
			return ThemeColors.new(PackedColorArray([Color("#2b2a5e"), Color("#6d5b9e")]), PackedColorArray([Color("#0a0920"), Color("#2b1e52")]), Color("#3b3a72"), Color("#2c2b58"), Color("#232246"))
		_:
			return ThemeColors.new(PackedColorArray([Color("#7ec8f2"), Color("#c9ecff")]), PackedColorArray([Color("#2b5fa8"), Color("#84bceb")]), Color("#5aa86e"), Color("#43855a"), Color("#3f7a53"))

## 8 directions, index 0 = right, clockwise (y down).
const DIR8: Array[Vector2] = [
	Vector2(1, 0), Vector2(0.7071, 0.7071), Vector2(0, 1), Vector2(-0.7071, 0.7071),
	Vector2(-1, 0), Vector2(-0.7071, -0.7071), Vector2(0, -1), Vector2(0.7071, -0.7071),
]
const DIR8_NAME: PackedStringArray = ["右", "右下", "下", "左下", "左", "左上", "上", "右上"]

static func dir_vector(index: int) -> Vector2:
	return DIR8[clampi(index, 0, 7)]

## Quantise a drag vector into one of the 8 directions; returns [param fallback] for tiny drags.
static func dir_from_vector(v: Vector2, fallback: int) -> int:
	if absf(v.x) < 1.0 and absf(v.y) < 1.0:
		return fallback
	var i: int = roundi(atan2(v.y, v.x) / (PI / 4.0))
	return ((i % 8) + 8) % 8
