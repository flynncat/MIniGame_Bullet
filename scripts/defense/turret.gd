@tool
## Gun turret / rocket launcher. Node position = top-left.
## Can be placed in level scenes (active immediately) or bought in the shop (arms first).
## Fire rate / projectile values come from TurretStats (res://config/defense/turret.tres, rocket.tres);
## a level-placed turret may use its own [member stats_override].
## Turrets never spawn projectiles themselves: they emit [signal fire_requested]
## and the DefenseController owns the projectile lifecycle.
class_name Turret
extends Node2D

enum Kind { GUN, ROCKET }
enum Dir8 { RIGHT, DOWN_RIGHT, DOWN, DOWN_LEFT, LEFT, UP_LEFT, UP, UP_RIGHT }

## Emitted when the turret fires. [param muzzle] is in global coordinates.
signal fire_requested(turret: Turret, muzzle: Vector2, direction: Vector2)

@export var kind: Kind = Kind.GUN:
	set(value):
		kind = value
		queue_redraw()
@export var direction: Dir8 = Dir8.RIGHT:
	set(value):
		direction = value
		queue_redraw()
## Upgraded (effects from the stats table's "升级" group). Level designers may pre-upgrade a turret;
## player 2 upgrades shop / level turrets in game via the shop's "升级" mode.
@export var upgraded: bool = false:
	set(value):
		upgraded = value
		queue_redraw()
## Optional: per-instance stats for this level-placed turret. Leave empty to use the global
## table (config/defense/turret.tres or rocket.tres, depending on [member kind]).
@export var stats_override: TurretStats

## Effective stats (assigned by DefenseController; falls back to defaults if never assigned).
var stats: TurretStats = null

## Remaining arming time; > 0 means charging (does not fire).
var arm_time: float = 0.0
## True for shop-placed units (cleared at level end).
var is_runtime: bool = false

var _cooldown: float = 0.9
var _flash: float = 0.0
var _anim_t: float = 0.0

func _ready() -> void:
	if not Engine.is_editor_hint() and not is_runtime:
		_cooldown = randf_range(0.2, 1.4)

func body_size() -> Vector2:
	return DefenseCatalog.ROCKET_SIZE if kind == Kind.ROCKET else DefenseCatalog.TURRET_SIZE

func center_global() -> Vector2:
	return global_position + body_size() * 0.5

## Assigns effective stats. The override (if any) wins over [param global_stats].
func apply_stats(global_stats: TurretStats) -> void:
	stats = stats_override if stats_override else global_stats
	if stats == null:
		stats = TurretStats.new()

## Configures a shop-placed turret (arms before firing).
func setup_runtime(p_kind: Kind, p_dir: int, p_stats: TurretStats) -> void:
	kind = p_kind
	direction = clampi(p_dir, 0, 7) as Dir8
	is_runtime = true
	apply_stats(p_stats)
	arm_time = stats.arm_time
	_cooldown = stats.first_shot_delay if arm_time <= 0.0 else stats.fire_interval * 0.5

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if stats == null:
		apply_stats(null)
	if _flash > 0.0:
		_flash -= delta
	if arm_time > 0.0:
		arm_time -= delta
		if arm_time <= 0.0:
			arm_time = 0.0
			_cooldown = minf(_cooldown, stats.first_shot_delay)
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown += maxf(stats.fire_interval, 0.05)
		_flash = 0.12
		var d: Vector2 = Palette.dir_vector(direction)
		fire_requested.emit(self, center_global() + d * 20.0, d)

func _process(delta: float) -> void:
	_anim_t += delta
	queue_redraw()

func _draw() -> void:
	var warn: bool = not Engine.is_editor_hint() and arm_time <= 0.0 and _cooldown < 0.35
	if kind == Kind.ROCKET:
		draw_rocket(self, Vector2.ZERO, warn, _flash)
	else:
		draw_gun(self, Vector2.ZERO, direction, warn, _flash)
	if upgraded:
		draw_rect(Rect2(Vector2(-2, -2), body_size() + Vector2(4, 4)), Color("#ffd76a", 0.8), false, 1.5)
		DrawUtil.upgrade_badge(self, Vector2(body_size().x + 1, -3))
	if arm_time > 0.0:
		DrawUtil.arm_badge(self, Vector2(body_size().x * 0.5, -6.0), arm_time, stats.arm_time if stats else arm_time, _anim_t)

## Draws a gun turret whose top-left is [param at] in [param ci]'s local space.
static func draw_gun(ci: CanvasItem, at: Vector2, dir_index: int, about_to_fire: bool, flash: float) -> void:
	var s: Vector2 = DefenseCatalog.TURRET_SIZE
	var c: Vector2 = at + s * 0.5
	var d: Vector2 = Palette.dir_vector(dir_index)
	DrawUtil.round_rect(ci, Rect2(at + Vector2(2, s.y - 7), Vector2(s.x - 4, 8)), 3, Color(0.08, 0.1, 0.16, 0.35))
	DrawUtil.round_rect(ci, Rect2(at + Vector2(3, 8), Vector2(s.x - 6, s.y - 12)), 5, Color("#4a5570"))
	DrawUtil.round_rect(ci, Rect2(at + Vector2(5, 10), Vector2(s.x - 10, 5)), 2, Color("#5d6a8a"))
	var recoil: float = -5.0 if flash > 0.0 else 0.0
	ci.draw_set_transform(c + Vector2(0, -2), d.angle())
	DrawUtil.round_rect(ci, Rect2(Vector2(2 + recoil, -5), Vector2(20, 10)), 3, Color("#8e9cb8"))
	DrawUtil.round_rect(ci, Rect2(Vector2(17 + recoil, -6), Vector2(6, 12)), 2, Color("#c3ccdd"))
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_circle(c + Vector2(0, -2), 11, Color("#6b7899"))
	ci.draw_circle(c + Vector2(-2, -4), 7, Color("#8d9ab8"))
	ci.draw_circle(c + Vector2(8, -10), 2.6, Color("#ff5c7a") if about_to_fire else Color("#6cf0a0"))
	if flash > 0.0:
		ci.draw_circle(c + Vector2(0, -2) + d * 26.0, 9, Color(1, 0.84, 0.42, clampf(flash / 0.12, 0, 1)))

## Draws a rocket launcher whose top-left is [param at].
static func draw_rocket(ci: CanvasItem, at: Vector2, about_to_fire: bool, flash: float) -> void:
	var s: Vector2 = DefenseCatalog.ROCKET_SIZE
	var c: Vector2 = at + s * 0.5
	DrawUtil.round_rect(ci, Rect2(at + Vector2(2, s.y - 7), Vector2(s.x - 4, 8)), 3, Color(0.08, 0.1, 0.16, 0.35))
	DrawUtil.round_rect(ci, Rect2(at + Vector2(3, 8), Vector2(s.x - 6, s.y - 12)), 5, Color("#7a2b3a"))
	DrawUtil.round_rect(ci, Rect2(at + Vector2(5, 10), Vector2(s.x - 10, 5)), 2, Color("#a23a4e"))
	ci.draw_circle(c + Vector2(0, -2), 11, Color("#c0445a"))
	ci.draw_circle(c + Vector2(-2, -4), 7, Color("#e06a80"))
	ci.draw_circle(c + Vector2(8, -10), 2.6, Color("#ffe066") if about_to_fire else Color("#ff5c7a"))
	if flash > 0.0:
		ci.draw_circle(c + Vector2(0, -2), 9, Color(1, 0.84, 0.42, clampf(flash / 0.12, 0, 1)))
