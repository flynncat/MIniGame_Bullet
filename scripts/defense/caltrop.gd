## Caltrop dropped by the defender: falls, snaps onto the first static platform top below it
## (moving platforms are ignored), and becomes harmful once landed and armed.
## Upgraded: the spikes periodically burst larger (hitbox grows, anchored to the ground)
## for pulse_duration, then snap back (see CaltropStats "升级").
class_name Caltrop
extends Hazard

## Emitted if the caltrop falls out of the world without landing.
signal lost(caltrop: Caltrop)

var landed: bool = false
var arm_time: float = 3.0
var stats: CaltropStats = CaltropStats.new()
var world_bottom: float = 1e9
## Set by DefenseController when player 2 buys the upgrade.
var upgraded: bool = false:
	set(value):
		upgraded = value
		_cycle = 0.0
		queue_redraw()

const GROW_TIME: float = 0.06
const SHRINK_TIME: float = 0.08

var _vy: float = 0.0
var _anim_t: float = 0.0
var _shape_owner: int = -1
## Time within the current pulse cycle (normal phase, then enlarged phase).
var _cycle: float = 0.0
var _scale: float = 1.0

func _init() -> void:
	knockback_velocity = -360.0

## Applies tunables from the config table (call before adding to the tree).
func setup(p_stats: CaltropStats) -> void:
	stats = p_stats
	arm_time = stats.arm_time
	knockback_velocity = -stats.knockback_speed

func _ready() -> void:
	_shape_owner = RectShape.apply(self, -1, hit_rect())

## Current hitbox in local space: base footprint scaled around its bottom centre.
func hit_rect() -> Rect2:
	var base: Vector2 = DefenseCatalog.CALTROP_SIZE
	var sz: Vector2 = base * _scale
	return Rect2(Vector2(base.x * 0.5 - sz.x * 0.5, base.y - sz.y), sz)

## Current spike scale (1 = normal).
func current_scale() -> float:
	return _scale

## True during the warning shake right before a burst.
func is_warning() -> bool:
	return upgraded and _pulse_active() and _cycle < stats.pulse_interval and stats.pulse_interval - _cycle <= stats.pulse_warning

func _pulse_active() -> bool:
	return landed and arm_time <= 0.0

func _update_pulse(delta: float) -> void:
	var target: float = 1.0
	if upgraded and _pulse_active():
		_cycle += delta
		var period: float = stats.pulse_interval + stats.pulse_duration
		if _cycle >= period:
			_cycle = fmod(_cycle, period)
		if _cycle >= stats.pulse_interval:
			var t: float = _cycle - stats.pulse_interval
			var grow: float = clampf(t / GROW_TIME, 0.0, 1.0)
			var shrink: float = clampf((stats.pulse_duration - t) / SHRINK_TIME, 0.0, 1.0)
			target = lerpf(1.0, stats.pulse_scale, minf(grow, shrink))
	if not is_equal_approx(target, _scale):
		_scale = target
		_shape_owner = RectShape.apply(self, _shape_owner, hit_rect())

func is_harmful() -> bool:
	return landed and arm_time <= 0.0

func _physics_process(delta: float) -> void:
	if arm_time > 0.0:
		arm_time -= delta
	if landed:
		_update_pulse(delta)
		return
	var s: Vector2 = DefenseCatalog.CALTROP_SIZE
	var prev_bottom: float = global_position.y + s.y
	_vy = minf(_vy + stats.fall_gravity * delta, stats.max_fall_speed)
	var new_bottom: float = prev_bottom + _vy * delta
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var best: float = INF
	for fx: float in [1.0, s.x * 0.5, s.x - 1.0]:
		var q := PhysicsRayQueryParameters2D.create(
			Vector2(global_position.x + fx, prev_bottom - 6.0),
			Vector2(global_position.x + fx, new_bottom + 0.5),
			Palette.LAYER_SOLID | Palette.LAYER_ONEWAY)
		q.hit_from_inside = false
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			best = minf(best, (hit["position"] as Vector2).y)
	if best < INF:
		global_position.y = best - s.y
		_vy = 0.0
		landed = true
	else:
		global_position.y = new_bottom - s.y
		if global_position.y > world_bottom + 40.0:
			lost.emit(self)
			queue_free()

func _process(delta: float) -> void:
	_anim_t += delta
	queue_redraw()

func _draw() -> void:
	var base: Vector2 = DefenseCatalog.CALTROP_SIZE
	var pivot := Vector2(base.x * 0.5, base.y)
	var shake: float = sin(_anim_t * 70.0) * 1.6 if is_warning() else 0.0
	var pulsing: bool = _scale > 1.01
	if pulsing:
		draw_circle(pivot - Vector2(0, base.y * 0.5 * _scale), base.x * 0.62 * _scale, Color(1.0, 0.35, 0.3, 0.18))
	draw_set_transform(pivot + Vector2(shake, 0), 0.0, Vector2(_scale, _scale))
	draw_caltrop(self, -pivot, 0.0 if landed else _anim_t * 3.0, 1.25 if pulsing else 1.0, upgraded)
	draw_set_transform(Vector2.ZERO)
	if upgraded:
		DrawUtil.upgrade_badge(self, Vector2(base.x + 2, -4))
	if arm_time > 0.0:
		DrawUtil.arm_badge(self, base * 0.5, arm_time, stats.arm_time, _anim_t)

## [param spike_boost] lengthens the spikes; [param upgraded] tints them red-gold.
static func draw_caltrop(ci: CanvasItem, at: Vector2, rot: float, spike_boost: float = 1.0, upgraded: bool = false) -> void:
	var s: Vector2 = DefenseCatalog.CALTROP_SIZE
	var c: Vector2 = at + s * 0.5
	var r0: float = s.x * 0.30
	var r1: float = s.x * 0.54 * spike_boost
	var spike: Color = Color("#ffb08a") if upgraded else Color("#aab6d2")
	for i: int in 8:
		var a: float = float(i) / 8.0 * TAU + rot
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2.from_angle(a) * r0,
			c + Vector2.from_angle(a + 0.32) * r1,
			c + Vector2.from_angle(a - 0.32) * r1,
		]), spike)
	ci.draw_circle(c, s.x * 0.34, Color("#3a4156"))
	ci.draw_circle(c + Vector2(-2, -2), s.x * 0.16, Color("#ffd76a") if upgraded else Color("#6f7d9a"))
