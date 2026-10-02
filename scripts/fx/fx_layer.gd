## Lightweight CPU particle layer (square sparks), a port of the web version's burst().
class_name FxLayer
extends Node2D

class Spark:
	var pos: Vector2
	var vel: Vector2
	var gravity: float
	var life: float
	var max_life: float
	var size: float
	var color: Color

const MAX_SPARKS: int = 1500

var _sparks: Array[Spark] = []

func burst(at: Vector2, n: int, color: Color, vx: Vector2 = Vector2(-90, 90), vy: Vector2 = Vector2(-140, -20), gravity: float = 420.0, life_max: float = 0.7, size_max: float = 5.0) -> void:
	for i: int in n:
		if _sparks.size() >= MAX_SPARKS:
			return
		var s := Spark.new()
		s.pos = at
		s.vel = Vector2(randf_range(vx.x, vx.y), randf_range(vy.x, vy.y))
		s.gravity = gravity
		s.life = randf_range(0.3, life_max)
		s.max_life = 0.7
		s.size = randf_range(2.0, size_max)
		s.color = color
		_sparks.append(s)

## Radial ring of sparks (double-jump effect).
func ring(at: Vector2, n: int, speed: float, color: Color) -> void:
	for i: int in n:
		var s := Spark.new()
		s.pos = at
		s.vel = Vector2.from_angle(float(i) / float(n) * TAU) * speed
		s.gravity = 240.0
		s.life = 0.4
		s.max_life = 0.4
		s.size = 3.0
		s.color = color
		_sparks.append(s)

func clear() -> void:
	_sparks.clear()

func _physics_process(delta: float) -> void:
	for i: int in range(_sparks.size() - 1, -1, -1):
		var s: Spark = _sparks[i]
		s.life -= delta
		if s.life <= 0.0:
			_sparks.remove_at(i)
			continue
		s.vel.y += s.gravity * delta
		s.pos += s.vel * delta

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for s: Spark in _sparks:
		draw_rect(Rect2(s.pos, Vector2(s.size, s.size)), Color(s.color, clampf(s.life / s.max_life, 0.0, 1.0)))
