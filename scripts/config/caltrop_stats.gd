@tool
## Tunable stats for the caltrop (player-2 shop item). Edit res://config/defense/caltrop.tres.
class_name CaltropStats
extends Resource

@export_group("商店")
## Name shown on the shop card and in messages.
@export var display_name: String = "铁刺"
## Description shown on the shop card.
@export_multiline var description: String = ""
## Price (defender funds).
@export_range(0, 5000, 10, "or_greater") var price: int = 120

@export_group("部署")
## Arming time in seconds after being dropped; it can hurt only after it has landed and armed.
@export_range(0.0, 10.0, 0.1, "suffix:s") var arm_time: float = 3.0
## Gravity while falling.
@export_range(50.0, 5000.0, 10.0, "suffix:px/s²") var fall_gravity: float = 900.0
## Maximum fall speed.
@export_range(50.0, 5000.0, 10.0, "suffix:px/s") var max_fall_speed: float = 1000.0

@export_group("伤害")
## Upward bounce speed given to the runner when it steps on the caltrop.
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var knockback_speed: float = 360.0

@export_group("升级")
## One-time cost of the "升级" button under the shop icon (0 = free). After upgrading, every NEW
## placement of this item is the upgraded version (units already placed stay as they are).
@export_range(0, 5000, 10, "or_greater") var upgrade_cost: int = 0
## Price per placement after the upgrade (replaces [member price] on the shop card).
@export_range(0, 5000, 10, "or_greater") var upgraded_price: int = 180
## After the upgrade the spikes periodically burst larger. Seconds between bursts (normal-size time).
@export_range(0.2, 20.0, 0.1, "suffix:s") var pulse_interval: float = 2.0
## How long the enlarged spikes stay out before snapping back.
@export_range(0.05, 5.0, 0.05, "suffix:s") var pulse_duration: float = 0.5
## Scale while enlarged (the hitbox grows with it, anchored to the ground).
@export_range(1.0, 6.0, 0.1, "suffix:x") var pulse_scale: float = 2.0
## Warning shake before each burst (0 = no warning).
@export_range(0.0, 2.0, 0.05, "suffix:s") var pulse_warning: float = 0.3

func upgrade_summary() -> String:
	return "每 %ss 尖刺放大 %sx 持续 %ss" % [DefenseController._fmt_s(pulse_interval), DefenseController._fmt_s(pulse_scale), DefenseController._fmt_s(pulse_duration)]
