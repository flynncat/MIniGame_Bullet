@tool
## Runner (player 1) attributes. Main file: res://config/player_config.tres.
class_name PlayerConfig
extends Resource

@export_group("移动")
## Maximum horizontal run speed.
@export_range(10.0, 2000.0, 5.0, "suffix:px/s") var run_speed: float = 310.0
## Acceleration on the ground.
@export_range(10.0, 20000.0, 10.0, "suffix:px/s²") var ground_accel: float = 3200.0
## Acceleration in the air (air control).
@export_range(10.0, 20000.0, 10.0, "suffix:px/s²") var air_accel: float = 2200.0
## Deceleration on the ground after releasing direction (larger = stops faster).
@export_range(10.0, 20000.0, 10.0, "suffix:px/s²") var ground_friction: float = 3000.0
## Deceleration in the air after releasing direction.
@export_range(10.0, 20000.0, 10.0, "suffix:px/s²") var air_friction: float = 1400.0

@export_group("跳跃与重力")
## Gravity.
@export_range(100.0, 10000.0, 10.0, "suffix:px/s²") var gravity: float = 2100.0
## Maximum fall speed.
@export_range(50.0, 5000.0, 10.0, "suffix:px/s") var max_fall_speed: float = 920.0
## Initial speed of the ground jump (larger = higher).
@export_range(50.0, 3000.0, 10.0, "suffix:px/s") var jump_speed: float = 700.0
## Initial speed of air jumps (second jump onward).
@export_range(50.0, 3000.0, 10.0, "suffix:px/s") var air_jump_speed: float = 620.0
## Upward speed cap after releasing jump early (short hop). 0 = no short hop.
@export_range(0.0, 3000.0, 10.0, "suffix:px/s") var jump_cut_speed: float = 240.0
## Coyote time: grace window in seconds to still jump after walking off a ledge.
@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time: float = 0.10
## Jump buffer: a jump pressed this long before landing still triggers on landing.
@export_range(0.0, 0.5, 0.01, "suffix:s") var jump_buffer: float = 0.13

@export_group("冲刺")
## Dash speed.
@export_range(50.0, 5000.0, 10.0, "suffix:px/s") var dash_speed: float = 620.0
## Dash duration.
@export_range(0.02, 2.0, 0.01, "suffix:s") var dash_time: float = 0.16
## Horizontal speed kept after the dash ends.
@export_range(0.0, 3000.0, 10.0, "suffix:px/s") var dash_exit_speed: float = 300.0
## Dash cooldown.
@export_range(0.0, 10.0, 0.05, "suffix:s") var dash_cooldown: float = 0.55
## Invulnerability during a dash (dash through bullets).
@export_range(0.0, 2.0, 0.01, "suffix:s") var dash_invuln: float = 0.18

@export_group("生命")
## Invulnerability after being hit or respawning (blinking).
@export_range(0.0, 10.0, 0.1, "suffix:s") var respawn_invuln: float = 1.6
## Runner classes: one entry per life, in order of use; the entry count is the life count.
@export var classes: Array[RunnerClassConfig] = []

@export_group("兵种能力")
## Bomb squad death explosion radius.
@export_range(0.0, 2000.0, 5.0, "suffix:px") var bomb_radius: float = 180.0
## Width of the engineer's patrol platform.
@export_range(20.0, 1000.0, 5.0, "suffix:px") var engineer_platform_width: float = 130.0
## Patrol distance of the engineer's platform.
@export_range(30.0, 2000.0, 5.0, "suffix:px") var engineer_platform_distance: float = 90.0
## Patrol speed of the engineer's platform.
@export_range(5.0, 1000.0, 5.0, "suffix:px/s") var engineer_platform_speed: float = 60.0

@export_group("金币技能 · 护盾")
## Coins spent to create a shield at the runner's current position.
@export_range(0, 999, 1, "suffix:金币") var shield_cost: int = 5
## Shield radius. Projectiles entering the bubble are destroyed.
@export_range(20.0, 1000.0, 5.0, "suffix:px") var shield_radius: float = 95.0
## How long the shield lasts.
@export_range(0.1, 60.0, 0.1, "suffix:s") var shield_duration: float = 4.0
## Minimum time between two shields (prevents accidental double spending).
@export_range(0.0, 30.0, 0.1, "suffix:s") var shield_cooldown: float = 0.5

@export_group("金币技能 · 清屏")
## Coins spent to destroy every turret / rocket launcher / projectile on screen.
@export_range(0, 999, 1, "suffix:金币") var screen_clear_cost: int = 15
## Also destroy caltrops on screen.
@export var screen_clear_includes_caltrops: bool = false
## Time for the clearing wave to sweep across the screen.
@export_range(0.05, 3.0, 0.05, "suffix:s") var screen_clear_wave_time: float = 0.45

@export_group("通关")
## Duration of the level-clear sweep animation before the success prompt appears.
@export_range(0.2, 10.0, 0.1, "suffix:s") var goal_sweep_time: float = 2.0
## The sweep also removes the level's spikes (in addition to turrets / caltrops / projectiles).
@export var goal_sweep_includes_spikes: bool = true
## Number of entries shown on the level-clear / victory leaderboard.
@export_range(1, 20, 1) var leaderboard_show: int = 5

func max_lives() -> int:
	return maxi(1, classes.size())

## Class for a given number of remaining lives (lives = max -> first entry).
func class_for_lives(lives: int) -> RunnerClassConfig:
	if classes.is_empty():
		return RunnerClassConfig.new()
	return classes[clampi(max_lives() - maxi(1, lives), 0, classes.size() - 1)]
