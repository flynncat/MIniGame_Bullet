## Stationary projectile shield created by the runner (costs coins). Any projectile inside
## the bubble is destroyed. Radius / duration come from PlayerConfig.
class_name ShieldBubble
extends Node2D

## A projectile was destroyed by this shield.
signal blocked(at: Vector2)

const APPEAR_TIME: float = 0.18
const WARN_TIME: float = 1.0

var radius: float = 95.0
var duration: float = 4.0
var defense: DefenseController
var fx: FxLayer

var _life: float = 4.0
var _t: float = 0.0
## Hit ripples: x, y = local position, z = remaining life.
var _hits: Array[Vector3] = []

func setup(p_radius: float, p_duration: float, p_defense: DefenseController, p_fx: FxLayer) -> void:
	radius = p_radius
	duration = p_duration
	_life = p_duration
	defense = p_defense
	fx = p_fx

func remaining() -> float:
	return maxf(0.0, _life)

func _physics_process(delta: float) -> void:
	_t += delta
	_life -= delta
	for i: int in range(_hits.size() - 1, -1, -1):
		_hits[i].z -= delta
		if _hits[i].z <= 0.0:
			_hits.remove_at(i)
	if _life <= 0.0:
		if fx:
			fx.ring(global_position, 24, radius * 1.6, Color("#9fe8ff"))
		queue_free()
		return
	if defense == null:
		return
	var r2: float = radius * radius
	for b: Bullet in defense.live_bullets():
		if b.global_position.distance_squared_to(global_position) <= r2:
			var at: Vector2 = b.global_position
			_hits.append(Vector3(at.x - global_position.x, at.y - global_position.y, 0.35))
			if fx:
				fx.burst(at, 10, Color("#bff3ff"), Vector2(-120, 120), Vector2(-120, 120), 0.0, 0.35, 4.0)
			defense.destroy_node(b)
			Audio.play(&"block")
			blocked.emit(at)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var grow: float = 1.0 - pow(1.0 - clampf(_t / APPEAR_TIME, 0.0, 1.0), 3.0)
	var r: float = radius * (0.55 + 0.45 * grow)
	var a: float = 1.0
	if _life < WARN_TIME:
		a = 0.45 + 0.55 * absf(sin(_t * 18.0))
	var core := Color(0.45, 0.85, 1.0)
	draw_circle(Vector2.ZERO, r, Color(core, 0.10 * a))
	draw_circle(Vector2.ZERO, r * 0.72, Color(core, 0.05 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.7, 0.95, 1.0, 0.9 * a), 3.0, true)
	draw_arc(Vector2.ZERO, r - 7.0, 0.0, TAU, 96, Color(core, 0.35 * a), 2.0, true)
	# Rotating hex segments on the rim.
	for i: int in 6:
		var s: float = _t * 1.3 + float(i) / 6.0 * TAU
		draw_arc(Vector2.ZERO, r + 4.0, s, s + 0.45, 12, Color(0.85, 1.0, 1.0, 0.8 * a), 4.0, true)
	# Glossy highlight.
	draw_circle(Vector2(-r * 0.36, -r * 0.42), r * 0.16, Color(1, 1, 1, 0.12 * a))
	# Remaining time.
	var frac: float = clampf(_life / maxf(duration, 0.001), 0.0, 1.0)
	draw_arc(Vector2.ZERO, r + 11.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 64, Color("#ffd76a", 0.85 * a), 3.0, true)
	for h: Vector3 in _hits:
		var k: float = h.z / 0.35
		draw_arc(Vector2(h.x, h.y), 6.0 + (1.0 - k) * 34.0, 0.0, TAU, 24, Color(1, 1, 1, k), 3.0, true)
