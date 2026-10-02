## Projectile fired by turrets. Straight shell, homing rocket, or a burst fragment.
## Upgraded turrets can add a sine path and/or a death burst (see TurretStats "升级").
## Dies on solid/moving terrain (passes one-way planks), on timeout, out of bounds, or on the runner.
## Removal by shield / screen clear / sweep uses queue_free directly and never triggers the burst.
class_name Bullet
extends Area2D

## Emitted when the projectile is destroyed. [param hit_runner] is true if it struck the runner.
signal expired(at: Vector2, hit_runner: bool, homing: bool)
## Emitted on a natural death (terrain / timeout / runner) when the death burst is enabled.
signal burst_requested(at: Vector2, stats: TurretStats)

enum Style { SHELL, ROCKET, FRAGMENT }

var velocity: Vector2 = Vector2.ZERO
var homing: bool = false
var target: Node2D = null
var bounds: Rect2 = Rect2()
var style: Style = Style.SHELL
## Sine path (upgrade): offset perpendicular to the travel direction.
var sine_amplitude: float = 0.0
var sine_wavelength: float = 180.0
## Death burst (upgrade).
var burst_on_death: bool = false

var _stats: TurretStats = null
var _speed: float = 0.0
var _turn_rate: float = 2.6
var _life: float = 5.0
var _radius: float = 5.0
var _dead: bool = false
## Centre line position (without the sine offset) and distance travelled along it.
var _base: Vector2 = Vector2.ZERO
var _travel: float = 0.0
var _started: bool = false
## Recent global positions of sine shells (drawn as a fading trail).
var _trail: PackedVector2Array = PackedVector2Array()
const TRAIL_POINTS: int = 14

## Shell / rocket fired by a turret. [param upgraded] enables the table's upgrade effects.
func setup(direction: Vector2, stats: TurretStats, p_target: Node2D, p_bounds: Rect2, upgraded: bool = false) -> void:
	_stats = stats
	homing = stats.homing
	style = Style.ROCKET if homing else Style.SHELL
	_speed = stats.projectile_speed
	velocity = direction.normalized() * _speed
	_turn_rate = deg_to_rad(stats.homing_turn_rate_deg)
	_life = stats.projectile_lifetime
	target = p_target
	bounds = p_bounds
	_radius = 8.0 if homing else 5.0
	if upgraded:
		if stats.has_upgrade_effect(TurretStats.UpgradeEffect.SINE_PATH):
			sine_amplitude = stats.sine_amplitude
			sine_wavelength = maxf(stats.sine_wavelength, 1.0)
		burst_on_death = stats.has_upgrade_effect(TurretStats.UpgradeEffect.SPLIT_BURST)

## Straight fragment from a death burst (never bursts again).
func setup_fragment(direction: Vector2, speed: float, lifetime: float, p_bounds: Rect2) -> void:
	style = Style.FRAGMENT
	_speed = speed
	velocity = direction.normalized() * speed
	_life = lifetime
	bounds = p_bounds
	_radius = 4.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = Palette.LAYER_SOLID | Palette.LAYER_MOVING | Palette.LAYER_PLAYER
	monitorable = false
	RectShape.apply(self, -1, Rect2(-Vector2.ONE * _radius, Vector2.ONE * _radius * 2.0))
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _started:
		_started = true
		_base = global_position
	if homing and is_instance_valid(target):
		var desired: float = (target.global_position - global_position).angle()
		var cur: float = velocity.angle()
		var diff: float = wrapf(desired - cur, -PI, PI)
		cur += clampf(diff, -_turn_rate * delta, _turn_rate * delta)
		velocity = Vector2.from_angle(cur) * _speed
	_base += velocity * delta
	_travel += _speed * delta
	global_position = _base + sine_offset()
	if sine_amplitude > 0.0:
		_trail.append(global_position)
		if _trail.size() > TRAIL_POINTS:
			_trail.remove_at(0)
	_life -= delta
	if not bounds.has_point(global_position):
		_expire(false, false)
	elif _life <= 0.0:
		_expire(false, true)

## Current sideways offset from the centre line (zero without the sine upgrade).
func sine_offset() -> Vector2:
	if sine_amplitude <= 0.0 or velocity == Vector2.ZERO:
		return Vector2.ZERO
	return velocity.normalized().orthogonal() * sine_amplitude * sin(TAU * _travel / sine_wavelength)

func _on_body_entered(body: Node2D) -> void:
	if _dead:
		return
	if body is Player:
		(body as Player).take_hit(0.0)
		_expire(true, true)
	else:
		_expire(false, true)

func _expire(hit_runner: bool, can_burst: bool) -> void:
	_dead = true
	if can_burst and burst_on_death and _stats:
		burst_requested.emit(global_position, _stats)
	expired.emit(global_position, hit_runner, homing)
	queue_free()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var up: bool = burst_on_death or sine_amplitude > 0.0
	for i: int in range(1, _trail.size()):
		var k: float = float(i) / float(_trail.size())
		draw_line(_trail[i - 1] - global_position, _trail[i] - global_position, Color(1.0, 0.84, 0.42, 0.55 * k), 1.0 + 4.0 * k, true)
	match style:
		Style.ROCKET:
			var ang: float = velocity.angle()
			draw_circle(-Vector2.from_angle(ang) * 13.0, 8, Color(1, 0.55, 0.26, 0.32))
			draw_set_transform(Vector2.ZERO, ang)
			DrawUtil.round_rect(self, Rect2(-9, -5, 18, 10), 4, Color("#ff5c7a"))
			DrawUtil.round_rect(self, Rect2(5, -3, 5, 6), 2, Color("#ffe066") if up else Color("#ffd0d8"))
			draw_set_transform(Vector2.ZERO)
			if up:
				draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 20, Color("#ffd76a", 0.7), 1.5, true)
		Style.FRAGMENT:
			draw_circle(-velocity * 0.02, 6, Color(1, 0.4, 0.3, 0.28))
			draw_circle(Vector2.ZERO, 4, Color("#ff7a5c"))
			draw_circle(Vector2(-1, -1), 1.6, Color("#ffe0c8"))
		_:
			draw_circle(-velocity * 0.025, 10, Color(1, 0.62, 0.26, 0.30))
			draw_circle(Vector2.ZERO, 6, Color("#ffd76a") if up else Color("#ff9f43"))
			draw_circle(Vector2(-1.5, -1.5), 2.4, Color("#ffe0a8"))
