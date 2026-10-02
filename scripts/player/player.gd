## Runner (player 1). Movement constants are a 1:1 port of the web version:
## coyote time, jump buffering, variable jump height, multi-jump, dash with i-frames,
## drop-through one-way planks. Node origin = body centre (28 x 36).
class_name Player
extends CharacterBody2D

## Emitted when a hit is accepted (not blocked by invulnerability). Game decides lives/respawn.
signal damaged(at: Vector2)

const BODY: Vector2 = Vector2(28, 36)
@export var fx: FxLayer
## Movement / jump / dash / invulnerability table (res://config/player_config.tres). Injected by Game.
@export var config: PlayerConfig

var facing: float = 1.0
var max_jumps: int = 2
var invuln: float = 0.0
var dash_cooldown: float = 0.0
var dead: bool = false
var input_enabled: bool = true:
	set(value):
		if value and not input_enabled:
			# Gamepad A both confirms menus and jumps: ignore jump until that press is released.
			_jump_locked = true
		input_enabled = value
## Horizontal world limit (set by Game from the level width).
var world_width: float = 960.0
## Last safe standing position (centre), used for respawn after a hit or fall.
var safe_position: Vector2 = Vector2.ZERO
## Latest camera shake request, read and cleared by the camera.
var shake_request: float = 0.0

var _body_color: Color = Color("#4a7fe0")
var _body_hi: Color = Color("#6ea1ff")
var _coyote: float = 0.0
var _buffer: float = 0.0
var _jumps: int = 0
var _dash_time: float = 0.0
var _dash_dir: float = 1.0
var _anim: float = 0.0
var _ghosts: Array[Vector3] = []  # x, y = global pos, z = life
var _jump_locked: bool = false
var _hurtbox: Area2D
var _safety_probe: RectangleShape2D

func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()
	collision_layer = Palette.LAYER_PLAYER
	collision_mask = Palette.LAYER_SOLID | Palette.LAYER_ONEWAY | Palette.LAYER_MOVING
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	floor_snap_length = 4.0
	RectShape.apply(self, -1, Rect2(-BODY * 0.5, BODY))
	_hurtbox = Area2D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = Palette.LAYER_HAZARD
	_hurtbox.monitorable = false
	add_child(_hurtbox)
	RectShape.apply(_hurtbox, -1, Rect2(-BODY * 0.5, BODY))
	_safety_probe = RectangleShape2D.new()
	_safety_probe.size = BODY + Vector2(8, 8)

## Resets motion state and applies the class style of the new life.
func respawn_at(center: Vector2, runner_class: RunnerClassConfig) -> void:
	global_position = center
	velocity = Vector2.ZERO
	_jumps = 0
	_coyote = 0.0
	_buffer = 0.0
	_dash_time = 0.0
	dash_cooldown = 0.0
	invuln = config.respawn_invuln
	dead = false
	max_jumps = runner_class.max_jumps
	_body_color = runner_class.color
	_body_hi = runner_class.color.lerp(Color.WHITE, 0.35)
	_ghosts.clear()
	reset_physics_interpolation()

## Called by projectiles/hazards. Returns true if the hit was accepted.
## No damage while input is disabled (menus, level-clear sweep).
func take_hit(_knock: float) -> bool:
	if invuln > 0.0 or dead or not input_enabled:
		return false
	invuln = config.respawn_invuln
	damaged.emit(global_position)
	return true

func _physics_process(delta: float) -> void:
	if dead:
		return
	_anim += delta
	invuln = maxf(0.0, invuln - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	_update_ghosts(delta)

	var dir: float = 0.0
	var jump_pressed: bool = false
	var jump_held: bool = false
	var dash_pressed: bool = false
	var down_held: bool = false
	if input_enabled:
		dir = signf(Input.get_axis(&"move_left", &"move_right"))
		jump_held = Input.is_action_pressed(&"jump")
		if _jump_locked and not jump_held:
			_jump_locked = false
		if _jump_locked:
			jump_held = false
		else:
			jump_pressed = Input.is_action_just_pressed(&"jump")
		dash_pressed = Input.is_action_just_pressed(&"dash")
		down_held = Input.is_action_pressed(&"move_down")

	var on_floor: bool = is_on_floor()
	# Horizontal movement / dash.
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = Vector2(_dash_dir * config.dash_speed, 0.0)
		if randf() < 0.7:
			_ghosts.append(Vector3(global_position.x, global_position.y, 0.22))
		if _dash_time <= 0.0:
			velocity.x = _dash_dir * config.dash_exit_speed
	else:
		var accel: float = config.ground_accel if on_floor else config.air_accel
		var fric: float = config.ground_friction if on_floor else config.air_friction
		if dir != 0.0:
			velocity.x = clampf(velocity.x + dir * accel * delta, -config.run_speed, config.run_speed)
			facing = dir
		else:
			velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	if dash_pressed and dash_cooldown <= 0.0 and _dash_time <= 0.0:
		_dash_time = config.dash_time
		dash_cooldown = config.dash_cooldown
		_dash_dir = dir if dir != 0.0 else facing
		invuln = maxf(invuln, config.dash_invuln)
		shake_request = maxf(shake_request, 6.0)
		_burst(global_position, 10, Color("#8fd6ff"), Vector2(-60, 60), Vector2(-60, 60), 0.0)
		Audio.play(&"dash")

	# Jump: coyote time + input buffer + multi-jump.
	if on_floor:
		_coyote = config.coyote_time
		_jumps = 0
	elif _coyote > 0.0:
		_coyote -= delta
	if jump_pressed:
		_buffer = config.jump_buffer
	elif _buffer > 0.0:
		_buffer -= delta
	if _buffer > 0.0:
		if on_floor or _coyote > 0.0:
			velocity.y = -config.jump_speed
			_jumps = 1
			_buffer = 0.0
			_coyote = 0.0
			_burst(global_position + Vector2(0, BODY.y * 0.5), 8, Color.WHITE, Vector2(-70, 70), Vector2(-20, 40), 260.0, 4.0)
			Audio.play(&"jump")
		elif _jumps < max_jumps:
			velocity.y = -config.air_jump_speed
			_jumps += 1
			_buffer = 0.0
			if fx:
				fx.ring(global_position, 12, 130.0, Color("#b7e4ff"))
			Audio.play(&"djump")
	if not jump_held and config.jump_cut_speed > 0.0 and velocity.y < -config.jump_cut_speed:
		velocity.y = -config.jump_cut_speed

	if _dash_time <= 0.0:
		velocity.y = minf(velocity.y + config.gravity * delta, config.max_fall_speed)

	set_collision_mask_value(2, not down_held)
	var pre_vy: float = velocity.y
	var was_air: bool = not on_floor
	move_and_slide()

	if is_on_floor():
		if was_air and pre_vy > 420.0:
			_burst(global_position + Vector2(0, BODY.y * 0.5), 7, Color("#e8e2d0"), Vector2(-100, 100), Vector2(-60, -10), 400.0, 4.0, 0.4)
			shake_request = maxf(shake_request, 3.0)
	if is_on_ceiling() and pre_vy < 0.0:
		_burst(global_position - Vector2(0, BODY.y * 0.5), 5, Color("#e8e2d0"), Vector2(-90, 90), Vector2(-140, -20), 500.0, 5.0, 0.35)

	global_position.x = clampf(global_position.x, BODY.x * 0.5, world_width - BODY.x * 0.5)
	_check_hazards()
	if is_on_floor() and _standing_on_static() and not _hazard_near():
		safe_position = global_position

## Immediate physics query (no one-frame area latency): is any hazard within a few pixels?
func _hazard_near() -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _safety_probe
	q.transform = Transform2D(0.0, global_position)
	q.collision_mask = Palette.LAYER_HAZARD
	q.collide_with_areas = true
	q.collide_with_bodies = false
	return not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()

## True when the floor under the runner is a static Platform (moving platforms are not safe points).
func _standing_on_static() -> bool:
	for i: int in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col.get_normal().y < -0.7:
			return col.get_collider() is Platform
	return false

## Applies damage from the first harmful hazard overlapping the hurtbox.
func _check_hazards() -> void:
	if invuln > 0.0:
		return
	for area: Area2D in _hurtbox.get_overlapping_areas():
		var hazard := area as Hazard
		if hazard and hazard.is_harmful() and take_hit(0.0):
			velocity.y = hazard.knockback_velocity
			return

func _update_ghosts(delta: float) -> void:
	for i: int in range(_ghosts.size() - 1, -1, -1):
		_ghosts[i].z -= delta
		if _ghosts[i].z <= 0.0:
			_ghosts.remove_at(i)

func _burst(at: Vector2, n: int, color: Color, vx: Vector2, vy: Vector2, gravity: float, size_max: float = 5.0, life_max: float = 0.7) -> void:
	if fx:
		fx.burst(at, n, color, vx, vy, gravity, life_max, size_max)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if dead:
		return
	for g: Vector3 in _ghosts:
		var local: Vector2 = Vector2(g.x, g.y) - global_position
		DrawUtil.round_rect(self, Rect2(local - BODY * 0.5, BODY), 8, Color(0.5, 0.83, 1.0, (g.z / 0.22) * 0.35))
	var alpha: float = 0.4 if (invuln > 0.0 and int(invuln * 22.0) % 2 == 0) else 1.0
	var moving: bool = absf(velocity.x) > 20.0 and is_on_floor()
	var sq: float = 1.0 if is_on_floor() else (1.08 if velocity.y < 0.0 else 0.94)
	draw_set_transform(Vector2(0, BODY.y * 0.5), 0.0, Vector2(1.0 / sq, sq))
	var w: float = BODY.x
	var h: float = BODY.y
	var leg := Color("#2f4a86", alpha)
	if moving:
		var s: float = sin(_anim * 18.0) * 5.0
		draw_rect(Rect2(-9 + s * 0.5, -10, 7, 10), leg)
		draw_rect(Rect2(3 - s * 0.5, -10, 7, 10), leg)
	else:
		draw_rect(Rect2(-9, -9, 7, 9), leg)
		draw_rect(Rect2(3, -9, 7, 9), leg)
	DrawUtil.round_rect(self, Rect2(-w * 0.5, -h, w, h - 8), 8, Color(_body_color, alpha))
	DrawUtil.round_rect(self, Rect2(-w * 0.5 + 3, -h + 4, w - 6, 10), 5, Color(_body_hi, alpha))
	var scarf := Color("#ff6b6b", alpha)
	DrawUtil.round_rect(self, Rect2(-w * 0.5 - 1, -h + 12, w + 2, 6), 3, scarf)
	var fl: float = sin(_anim * 10.0) * 4.0 + minf(14.0, absf(velocity.x) * 0.05)
	draw_rect(Rect2(-w * 0.5 - fl * facing * 0.6 - 2, -h + 14, 10 + fl, 5), scarf)
	var eo: float = 3.0 if facing > 0.0 else -3.0
	draw_circle(Vector2(eo - 4, -h + 14), 4, Color(1, 1, 1, alpha))
	draw_circle(Vector2(eo + 5, -h + 14), 4, Color(1, 1, 1, alpha))
	draw_circle(Vector2(eo - 4 + facing * 1.5, -h + 14), 1.9, Color("#1b2440", alpha))
	draw_circle(Vector2(eo + 5 + facing * 1.5, -h + 14), 1.9, Color("#1b2440", alpha))
	draw_set_transform(Vector2.ZERO)
