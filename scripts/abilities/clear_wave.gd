## Expanding shockwave that destroys targets as the ring reaches them.
## Used by the runner's screen clear (small, fast) and the level-clear sweep (large, flashy).
## Targets come from [member source] every frame, so units spawned during the wave are caught too.
class_name ClearWave
extends Node2D

## Emitted for every target the ring reaches (before it is destroyed).
signal target_hit(target: Node2D, at: Vector2)
signal finished

const FLASH_TIME: float = 0.3
const RAY_COUNT: int = 18
const SPARK_COUNT: int = 36

## Returns the current candidate targets (Array[Node2D]).
var source: Callable
## Destroys one target (receives the Node2D).
var destroy: Callable
## Only targets whose centre lies in this rect are affected (size 0 = whole world).
var area: Rect2 = Rect2()
var max_radius: float = 1500.0
var expand_time: float = 1.5
var fade_time: float = 0.4
var main_color: Color = Color("#ffd76a")
var accent_color: Color = Color("#7fd4ff")
var flash_strength: float = 0.55
var rays: bool = true

var _t: float = 0.0
var _hit_count: int = 0
## Explosion rings: x, y = local position, z = remaining life, w = max size.
var _pops: Array[Vector4] = []

func hit_count() -> int:
	return _hit_count

func radius() -> float:
	var k: float = clampf(_t / maxf(expand_time, 0.001), 0.0, 1.0)
	return max_radius * (1.0 - pow(1.0 - k, 3.0))

func is_expanding() -> bool:
	return _t < expand_time

func _physics_process(delta: float) -> void:
	_t += delta
	for i: int in range(_pops.size() - 1, -1, -1):
		_pops[i].z -= delta
		if _pops[i].z <= 0.0:
			_pops.remove_at(i)
	# One extra pass after expansion ends so nothing inside the final radius survives.
	if _t - delta < expand_time and source.is_valid():
		var r: float = radius() if is_expanding() else max_radius + 1.0
		var r2: float = r * r
		var list: Array = source.call()
		for v: Variant in list:
			var n := v as Node2D
			if n == null or not is_instance_valid(n) or n.is_queued_for_deletion():
				continue
			var c: Vector2 = DefenseController.target_center(n)
			if area.has_area() and not area.has_point(c):
				continue
			if c.distance_squared_to(global_position) <= r2:
				_hit_count += 1
				_pops.append(Vector4(c.x - global_position.x, c.y - global_position.y, 0.5, 70.0))
				target_hit.emit(n, c)
				if destroy.is_valid():
					destroy.call(n)
	if _t >= expand_time + fade_time and _pops.is_empty():
		finished.emit()
		queue_free()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var r: float = radius()
	var a: float = 1.0 - clampf((_t - expand_time) / maxf(fade_time, 0.001), 0.0, 1.0)
	if _t < FLASH_TIME and flash_strength > 0.0:
		var f: float = flash_strength * (1.0 - _t / FLASH_TIME)
		draw_rect(Rect2(-6000, -6000, 12000, 12000), Color(1.0, 0.97, 0.88, f))
	if a > 0.0:
		draw_circle(Vector2.ZERO, r, Color(main_color, 0.07 * a))
		if rays:
			for i: int in RAY_COUNT:
				var ang: float = float(i) / RAY_COUNT * TAU + _t * 0.9
				var w: float = 0.035 + 0.02 * sin(_t * 6.0 + i)
				draw_colored_polygon(PackedVector2Array([
					Vector2.ZERO,
					Vector2.from_angle(ang - w) * r,
					Vector2.from_angle(ang + w) * r,
				]), Color(accent_color, 0.16 * a))
		var width: float = 18.0 * (0.4 + 0.6 * a)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 160, Color(main_color, 0.85 * a), width, true)
		draw_arc(Vector2.ZERO, maxf(0.0, r - width * 0.9), 0.0, TAU, 160, Color(1, 1, 1, 0.75 * a), 4.0, true)
		draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 128, Color(accent_color, 0.5 * a), 8.0, true)
		draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 96, Color(main_color, 0.25 * a), 3.0, true)
		# Sparks riding the ring.
		for i: int in SPARK_COUNT:
			var ang: float = float(i) / SPARK_COUNT * TAU + sin(i * 12.9898) * 0.3
			var jitter: float = sin(_t * 23.0 + i * 3.1) * 10.0
			var p: Vector2 = Vector2.from_angle(ang) * (r + jitter)
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.95, 0.75, 0.9 * a))
	for pop: Vector4 in _pops:
		var k: float = pop.z / 0.5
		var pr: float = 10.0 + (1.0 - k) * pop.w
		draw_circle(Vector2(pop.x, pop.y), pr * 0.6, Color(1.0, 0.75, 0.35, 0.35 * k))
		draw_arc(Vector2(pop.x, pop.y), pr, 0.0, TAU, 32, Color(1, 1, 1, k), 4.0 * k + 1.0, true)
