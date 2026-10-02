## Coin-powered runner abilities (shield, screen clear) and the level-clear sweep.
## Costs, radius, duration and timings come from PlayerConfig. Created by Game at runtime
## inside the game world, so its effects pause with the game.
class_name RunnerAbilities
extends Node2D

## Short feedback text for the HUD.
signal notice(text: String, color: Color)

var config: PlayerConfig = PlayerConfig.new()
var defense: DefenseController
var fx: FxLayer
var camera: GameCamera

var _shield_cd: float = 0.0
var _boom_cd: float = 0.0

func reset() -> void:
	for c: Node in get_children():
		c.queue_free()
	_shield_cd = 0.0

func active_shields() -> Array[ShieldBubble]:
	var out: Array[ShieldBubble] = []
	for c: Node in get_children():
		if c is ShieldBubble and not c.is_queued_for_deletion():
			out.append(c as ShieldBubble)
	return out

func shield_ready() -> bool:
	return _shield_cd <= 0.0

func _physics_process(delta: float) -> void:
	_shield_cd = maxf(0.0, _shield_cd - delta)
	_boom_cd = maxf(0.0, _boom_cd - delta)

# ------------------------------------------------------------------ shield

## Spends coins from [param run] and creates a shield at [param center]. Returns true on success.
func try_shield(center: Vector2, run: RunState) -> bool:
	if not shield_ready():
		return false
	if not run.spend(config.shield_cost):
		notice.emit("金币不足：护盾需要 %d 金币（当前 %d）" % [config.shield_cost, run.wallet], Color("#ff8a8a"))
		Audio.play(&"hurt")
		return false
	_shield_cd = config.shield_cooldown
	var s := ShieldBubble.new()
	s.setup(config.shield_radius, config.shield_duration, defense, fx)
	s.position = center
	add_child(s)
	if fx:
		fx.ring(center, 20, config.shield_radius * 2.2, Color("#9fe8ff"))
	Audio.play(&"shield")
	notice.emit("护盾展开 · %s 秒 · -%d 金币" % [DefenseController._fmt_s(config.shield_duration), config.shield_cost], Color("#9fe8ff"))
	return true

# ------------------------------------------------------------------ screen clear

## Spends coins and sends a wave from [param origin] that destroys every turret, rocket launcher
## and projectile inside [param view] (caltrops optional). Returns the wave, or null if short.
func try_screen_clear(origin: Vector2, view: Rect2, run: RunState) -> ClearWave:
	if not run.spend(config.screen_clear_cost):
		notice.emit("金币不足：清屏需要 %d 金币（当前 %d）" % [config.screen_clear_cost, run.wallet], Color("#ff8a8a"))
		Audio.play(&"hurt")
		return null
	var include_caltrops: bool = config.screen_clear_includes_caltrops
	var w := ClearWave.new()
	w.position = origin
	w.area = view
	w.max_radius = _farthest_corner(origin, view)
	w.expand_time = config.screen_clear_wave_time
	w.fade_time = 0.25
	w.main_color = Color("#7fd4ff")
	w.accent_color = Color("#ffffff")
	w.flash_strength = 0.25
	w.rays = false
	w.source = func() -> Array[Node2D]: return defense.targets(true, include_caltrops, true)
	w.destroy = _destroy_target
	add_child(w)
	if camera:
		camera.add_shake(10.0)
	Audio.play(&"wave")
	notice.emit("清屏冲击波 · -%d 金币" % config.screen_clear_cost, Color("#7fd4ff"))
	return w

# ------------------------------------------------------------------ level-clear sweep

## Big golden sweep from the flag that wipes every damaging object in [param level].
func goal_sweep(origin: Vector2, level: Level) -> ClearWave:
	var include_spikes: bool = config.goal_sweep_includes_spikes
	var w := ClearWave.new()
	w.position = origin
	w.max_radius = _farthest_corner(origin, Rect2(Vector2.ZERO, Vector2(level.world_size))) + 60.0
	w.expand_time = config.goal_sweep_time * 0.72
	w.fade_time = config.goal_sweep_time * 0.2
	w.main_color = Color("#ffd76a")
	w.accent_color = Color("#ff8c42")
	w.flash_strength = 0.6
	w.rays = true
	w.source = func() -> Array[Node2D]:
		var list: Array[Node2D] = defense.targets(true, true, true)
		if include_spikes and is_instance_valid(level):
			list.append_array(level.get_spikes())
		return list
	w.destroy = _destroy_target
	add_child(w)
	if camera:
		camera.add_shake(16.0)
	if fx:
		var ring_colors: Array[Color] = [Color("#ffd76a"), Color("#ffffff"), Color("#ff8c42")]
		for i: int in ring_colors.size():
			fx.ring(origin, 32, 260.0 + i * 140.0, ring_colors[i])
		fx.burst(origin, 40, Color("#ffe08a"), Vector2(-320, 320), Vector2(-420, 60), 260.0, 1.0, 6.0)
	Audio.play(&"sweep")
	return w

# ------------------------------------------------------------------ helpers

func _destroy_target(n: Node2D) -> void:
	var c: Vector2 = DefenseController.target_center(n)
	if fx:
		var big: bool = n is Turret
		fx.burst(c, 22 if big else 10, Color("#ff9f43"), Vector2(-240, 240), Vector2(-280, 60), 380.0, 0.8, 6.0 if big else 4.0)
		fx.burst(c, 12 if big else 5, Color("#fff2c2"), Vector2(-150, 150), Vector2(-150, 60), 200.0, 0.5, 4.0)
		if big:
			fx.ring(c, 14, 170.0, Color("#ffd76a"))
	if camera:
		camera.add_shake(7.0 if n is Turret else 3.0)
	if _boom_cd <= 0.0:
		Audio.play(&"boom")
		_boom_cd = 0.09
	if n is Spike:
		n.queue_free()
	elif defense:
		defense.destroy_node(n)

static func _farthest_corner(origin: Vector2, r: Rect2) -> float:
	var d: float = 0.0
	for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		d = maxf(d, origin.distance_to(p))
	return d
