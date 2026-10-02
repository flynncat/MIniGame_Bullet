@tool
## Tunable stats for one turret type (gun turret / rocket launcher).
## Edit the .tres files under res://config/defense/ in the Inspector.
class_name TurretStats
extends Resource

@export_group("商店")
## Name shown on the shop card and in messages.
@export var display_name: String = "炮塔"
## Description shown on the shop card.
@export_multiline var description: String = ""
## Price (defender funds).
@export_range(0, 5000, 10, "or_greater") var price: int = 200

@export_group("部署")
## Arming time in seconds after a shop placement before the unit fires (0 = immediately). Turrets placed in the level editor are not affected.
@export_range(0.0, 10.0, 0.1, "suffix:s") var arm_time: float = 3.0
## Delay in seconds before the first shot once arming finishes.
@export_range(0.0, 10.0, 0.05, "suffix:s") var first_shot_delay: float = 0.3

@export_group("开火")
## Fire interval in seconds (smaller = faster).
@export_range(0.1, 20.0, 0.05, "suffix:s") var fire_interval: float = 1.8
## Projectile speed.
@export_range(20.0, 2000.0, 5.0, "suffix:px/s") var projectile_speed: float = 280.0
## Projectile lifetime; the projectile disappears automatically after this.
@export_range(0.5, 30.0, 0.5, "suffix:s") var projectile_lifetime: float = 5.0

@export_group("追踪")
## Whether the projectile homes in on the runner (rocket launcher).
@export var homing: bool = false
## Homing turn speed in degrees per second (larger = tighter tracking; only used when homing is on).
@export_range(0.0, 1080.0, 1.0, "suffix:°/s") var homing_turn_rate_deg: float = 149.0

@export_group("升级")
## Upgrade effect flags (combinable). Sine path = projectile snakes along a sine curve;
## death burst = when the projectile dies it bursts into a radial ring of fragments.
enum UpgradeEffect { SINE_PATH = 1, SPLIT_BURST = 2 }
## One-time cost of the "升级" button under the shop icon (0 = free). After upgrading, every NEW
## placement of this item is the upgraded version (units already placed stay as they are).
@export_range(0, 5000, 10, "or_greater") var upgrade_cost: int = 0
## Price per placement after the upgrade (replaces [member price] on the shop card).
@export_range(0, 5000, 10, "or_greater") var upgraded_price: int = 300
## Effects enabled after the upgrade.
@export_flags("正弦弹道", "死亡爆裂") var upgrade_effects: int = 0

@export_subgroup("正弦弹道")
## Amplitude (distance from the centre line to a peak; the full up-down range is twice this).
@export_range(0.0, 400.0, 1.0, "suffix:px") var sine_amplitude: float = 40.0
## Distance travelled per full wave (smaller = tighter wiggles).
@export_range(20.0, 2000.0, 5.0, "suffix:px") var sine_wavelength: float = 180.0

@export_subgroup("死亡爆裂")
## Minimum fragment count (a random count between min and max each time).
@export_range(1, 32, 1) var split_count_min: int = 8
## Maximum fragment count.
@export_range(1, 32, 1) var split_count_max: int = 10
## Fragment speed.
@export_range(20.0, 2000.0, 5.0, "suffix:px/s") var split_speed: float = 240.0
## Fragment lifetime.
@export_range(0.1, 10.0, 0.1, "suffix:s") var split_lifetime: float = 1.4

func has_upgrade_effect(effect: UpgradeEffect) -> bool:
	return (upgrade_effects & effect) != 0

## Human-readable upgrade summary, for the shop card and messages.
func upgrade_summary() -> String:
	var parts := PackedStringArray()
	if has_upgrade_effect(UpgradeEffect.SINE_PATH):
		parts.append("正弦弹道 ±%dpx" % int(sine_amplitude))
	if has_upgrade_effect(UpgradeEffect.SPLIT_BURST):
		parts.append("爆裂 %d~%d 发" % [mini(split_count_min, split_count_max), maxi(split_count_min, split_count_max)])
	return " + ".join(parts) if not parts.is_empty() else "无升级效果"

## Shots per second, for display.
func shots_per_second() -> float:
	return 1.0 / maxf(fire_interval, 0.01)
