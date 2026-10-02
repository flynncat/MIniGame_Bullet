@tool
## Base class for damaging areas (spikes, caltrops). The runner's hurtbox polls overlapping
## hazards every physics frame so continuous contact still hurts after invulnerability ends.
class_name Hazard
extends Area2D

## Vertical velocity applied to the runner after being hit (negative = upward).
@export var knockback_velocity: float = -380.0

func _enter_tree() -> void:
	collision_layer = Palette.LAYER_HAZARD
	collision_mask = 0
	monitoring = false
	monitorable = true

## Override: whether touching this hazard currently deals damage.
func is_harmful() -> bool:
	return true
