## Owns player-2 (defender) economy and every defense unit/projectile in the current level.
## Level-authored turrets are adopted via [method adopt_level_turrets]; shop units via [method try_place].
class_name DefenseController
extends Node2D

## Balance changed (integer part).
signal budget_changed(budget: int)
## Short feedback text for the shop panel.
signal notice(text: String)
## The set of upgraded item types changed (shop refresh).
signal upgrades_changed

@export var fx: FxLayer
@export var runner: Player
## Defender economy + item stats table (res://config/defense_config.tres). Injected by Game.
@export var config: DefenseConfig

var budget: float = 0.0
var active: bool = false
var world_size: Vector2 = Vector2(960, 540)

var _turrets: Array[Turret] = []
var _caltrops: Array[Caltrop] = []
var _bullets: Array[Bullet] = []

func _ready() -> void:
	if config == null:
		config = DefenseConfig.new()

func reset_for_level(p_world_size: Vector2, reset_budget: bool) -> void:
	world_size = p_world_size
	for child: Node in get_children():
		child.queue_free()
	_turrets.clear()
	_caltrops.clear()
	_bullets.clear()
	if reset_budget:
		budget = config.start_budget
		# A new run starts with every item at base level.
		_upgraded_items.clear()
		upgrades_changed.emit()
	budget_changed.emit(int(budget))

func adopt_level_turrets(turrets: Array[Turret]) -> void:
	for t: Turret in turrets:
		t.apply_stats(config.turret_stats(t.kind))
		_register_turret(t)

func unit_count() -> int:
	_prune()
	return _turrets.size() + _caltrops.size()

func add_budget(amount: float) -> void:
	var before: int = int(budget)
	budget += amount
	if int(budget) != before:
		budget_changed.emit(int(budget))

func can_afford(item: DefenseCatalog.Item) -> bool:
	return budget >= current_price(item)

func _physics_process(delta: float) -> void:
	if active:
		add_budget(config.income_per_sec * delta)

## Buys and places [param item] centred at [param world_pos]. Returns true on success.
func try_place(item: DefenseCatalog.Item, world_pos: Vector2, dir_index: int) -> bool:
	var price: int = current_price(item)
	var up: bool = is_item_upgraded(item)
	if budget < price:
		notice.emit("余额不足，%s需要 %d（每秒 +%d）" % [config.display_name(item), price, int(config.income_per_sec)])
		Audio.play(&"hurt")
		return false
	var snapped: Vector2 = (world_pos / 10.0).round() * 10.0
	match item:
		DefenseCatalog.Item.TURRET, DefenseCatalog.Item.ROCKET:
			var t := Turret.new()
			var kind: Turret.Kind = Turret.Kind.ROCKET if item == DefenseCatalog.Item.ROCKET else Turret.Kind.GUN
			t.setup_runtime(kind, dir_index, config.turret_stats(kind))
			t.upgraded = up
			t.position = _clamp_to_world(snapped - t.body_size() * 0.5, t.body_size())
			add_child(t)
			_register_turret(t)
			_place_fx(t.center_global(), Color("#ff8c42") if kind == Turret.Kind.ROCKET else Color("#ffd76a"), 12)
			var extra: String = "（自动追踪跑者）" if t.stats.homing else ""
			notice.emit("%s已放置 · 方向 %s · %s 秒后生效%s · 余额 %d" % [config.display_name(item), Palette.DIR8_NAME[dir_index], _fmt_s(t.stats.arm_time), extra, int(budget - price)])
		DefenseCatalog.Item.CALTROP:
			var k := Caltrop.new()
			k.setup(config.caltrop_stats())
			k.upgraded = up
			k.position = _clamp_to_world(snapped - DefenseCatalog.CALTROP_SIZE * 0.5, DefenseCatalog.CALTROP_SIZE)
			k.world_bottom = world_size.y
			k.lost.connect(_on_caltrop_lost)
			add_child(k)
			_caltrops.append(k)
			_place_fx(k.position + DefenseCatalog.CALTROP_SIZE * 0.5, Color("#9fb0cf"), 8)
			notice.emit("%s已投放 · 下落吸附地形 · %s 秒后生效（踩到掉血）· 余额 %d" % [config.display_name(item), _fmt_s(k.stats.arm_time), int(budget - price)])
		_:
			return false
	add_budget(-price)
	Audio.play(&"place")
	return true

# ------------------------------------------------------------------ upgrades

## Item types upgraded via the shop's "升级" button this run. New placements of an upgraded
## type are the upgraded version and cost [method DefenseConfig.upgraded_price].
var _upgraded_items: Dictionary[DefenseCatalog.Item, bool] = {}

func is_item_upgraded(item: DefenseCatalog.Item) -> bool:
	return _upgraded_items.get(item, false)

## Current price per placement (base price, or the upgraded price once upgraded).
func current_price(item: DefenseCatalog.Item) -> int:
	return config.upgraded_price(item) if is_item_upgraded(item) else config.price(item)

## Shop "升级" button: switches [param item] to its upgraded version (pays the one-time cost).
func upgrade_item(item: DefenseCatalog.Item) -> bool:
	if is_item_upgraded(item):
		return false
	var cost: int = config.upgrade_cost(item)
	if budget < cost:
		notice.emit("余额不足，升级%s需要 %d" % [config.display_name(item), cost])
		Audio.play(&"hurt")
		return false
	_upgraded_items[item] = true
	if cost > 0:
		add_budget(-cost)
	Audio.play(&"upgrade")
	notice.emit("%s已升级：%s · 之后放置每个 %d" % [config.display_name(item), config.upgrade_summary(item), config.upgraded_price(item)])
	upgrades_changed.emit()
	return true

## Removes every defense unit and projectile (no refund). Returns the number removed.
func clear_all() -> int:
	_prune()
	var n: int = _turrets.size() + _caltrops.size()
	for t: Turret in _turrets:
		_debris(t.center_global(), Color("#8b98b6"), 8)
		t.queue_free()
	for k: Caltrop in _caltrops:
		_debris(k.global_position + DefenseCatalog.CALTROP_SIZE * 0.5, Color("#9fb0cf"), 8)
		k.queue_free()
	_turrets.clear()
	_caltrops.clear()
	clear_bullets()
	return n

## Destroys units and projectiles within [param radius] of [param center]. Returns units destroyed.
func destroy_in_radius(center: Vector2, radius: float) -> int:
	_prune()
	var r2: float = radius * radius
	var n: int = 0
	for i: int in range(_turrets.size() - 1, -1, -1):
		var t: Turret = _turrets[i]
		if t.center_global().distance_squared_to(center) <= r2:
			_debris(t.center_global(), Color("#8b98b6"), 12)
			t.queue_free()
			_turrets.remove_at(i)
			n += 1
	for i: int in range(_caltrops.size() - 1, -1, -1):
		var k: Caltrop = _caltrops[i]
		var kc: Vector2 = k.global_position + DefenseCatalog.CALTROP_SIZE * 0.5
		if kc.distance_squared_to(center) <= r2:
			_debris(kc, Color("#9aa6c2"), 10)
			k.queue_free()
			_caltrops.remove_at(i)
			n += 1
	for i: int in range(_bullets.size() - 1, -1, -1):
		if not is_instance_valid(_bullets[i]):
			_bullets.remove_at(i)
			continue
		var b: Bullet = _bullets[i]
		if b.global_position.distance_squared_to(center) <= r2:
			b.queue_free()
			_bullets.remove_at(i)
	return n

## Live units/projectiles for the runner's abilities and the level-clear sweep.
func targets(include_turrets: bool, include_caltrops: bool, include_bullets: bool) -> Array[Node2D]:
	_prune()
	var out: Array[Node2D] = []
	if include_turrets:
		out.append_array(_turrets)
	if include_caltrops:
		out.append_array(_caltrops)
	if include_bullets:
		for b: Variant in _bullets:
			if is_instance_valid(b) and not (b as Bullet).is_queued_for_deletion():
				out.append(b as Bullet)
	return out

## Live projectiles only.
func live_bullets() -> Array[Bullet]:
	var out: Array[Bullet] = []
	for b: Variant in _bullets:
		if is_instance_valid(b) and not (b as Bullet).is_queued_for_deletion():
			out.append(b as Bullet)
	return out

## Centre of a unit / projectile / spike row in world space.
static func target_center(n: Node2D) -> Vector2:
	if n is Spike:
		return n.global_position + (n as Spike).size * 0.5
	if n is Turret:
		return (n as Turret).center_global()
	if n is Caltrop:
		return n.global_position + DefenseCatalog.CALTROP_SIZE * 0.5
	return n.global_position

## Destroys one unit or projectile (no refund, no debris - the caller plays its own effect).
func destroy_node(n: Node2D) -> void:
	if not is_instance_valid(n) or n.is_queued_for_deletion():
		return
	if n is Turret:
		_turrets.erase(n)
	elif n is Caltrop:
		_caltrops.erase(n)
	elif n is Bullet:
		_bullets.erase(n)
	n.queue_free()

func clear_bullets() -> void:
	for b: Variant in _bullets:
		if is_instance_valid(b):
			(b as Bullet).queue_free()
	_bullets.clear()

func _register_turret(t: Turret) -> void:
	if not t.fire_requested.is_connected(_on_fire_requested):
		t.fire_requested.connect(_on_fire_requested)
	_turrets.append(t)

func _on_fire_requested(turret: Turret, muzzle: Vector2, direction: Vector2) -> void:
	if not active:
		return
	var b := Bullet.new()
	var stats: TurretStats = turret.stats if turret.stats else config.turret_stats(turret.kind)
	var homing: bool = stats.homing
	b.setup(direction, stats, runner, _bullet_bounds(), turret.upgraded)
	b.position = muzzle
	b.expired.connect(_on_bullet_expired)
	if b.burst_on_death:
		b.burst_requested.connect(_on_burst_requested)
	add_child(b)
	_bullets.append(b)
	if fx:
		if homing:
			fx.burst(muzzle, 8, Color("#ff8c42"), Vector2(-70, 70), Vector2(-70, 70), 30.0, 0.4, 3.0)
		else:
			fx.burst(muzzle, 6, Color("#ffb15c"), Vector2(-60, 60), Vector2(-60, 60), 40.0, 0.35, 3.0)
	Audio.play(&"shot")

func _on_bullet_expired(at: Vector2, hit_runner: bool, _homing: bool) -> void:
	var alive: Array[Bullet] = []
	for b: Variant in _bullets:
		if is_instance_valid(b) and not (b as Bullet).is_queued_for_deletion():
			alive.append(b as Bullet)
	_bullets = alive
	if hit_runner and fx:
		fx.burst(at, 14, Color("#ff9f43"), Vector2(-120, 120), Vector2(-120, 40), 420.0, 0.55)

func _bullet_bounds() -> Rect2:
	return Rect2(Vector2(-40, -40), world_size + Vector2(80, 200))

## Death burst (upgrade): a radial ring of split_count_min..max straight fragments.
func _on_burst_requested(at: Vector2, stats: TurretStats) -> void:
	if not active:
		return
	var lo: int = mini(stats.split_count_min, stats.split_count_max)
	var hi: int = maxi(stats.split_count_min, stats.split_count_max)
	var n: int = randi_range(lo, hi)
	var phase: float = randf() * TAU
	for i: int in n:
		var f := Bullet.new()
		f.setup_fragment(Vector2.from_angle(phase + float(i) / float(n) * TAU), stats.split_speed, stats.split_lifetime, _bullet_bounds())
		f.position = at
		f.expired.connect(_on_bullet_expired)
		# Spawned from a physics callback: defer the tree change.
		_add_fragment.call_deferred(f)
		_bullets.append(f)
	if fx:
		fx.ring(at, 16, 220.0, Color("#ff7a5c"))
		fx.burst(at, 14, Color("#ffd76a"), Vector2(-160, 160), Vector2(-160, 80), 200.0, 0.5, 5.0)
	Audio.play(&"boom")

func _add_fragment(f: Bullet) -> void:
	if is_instance_valid(f) and not f.is_queued_for_deletion():
		add_child(f)

func _on_caltrop_lost(caltrop: Caltrop) -> void:
	_caltrops.erase(caltrop)

## Drops references to units that were freed (e.g. by the bomb or by falling out of the world).
func _prune() -> void:
	var turrets: Array[Turret] = []
	for t: Variant in _turrets:
		if is_instance_valid(t) and not (t as Turret).is_queued_for_deletion():
			turrets.append(t as Turret)
	_turrets = turrets
	var caltrops: Array[Caltrop] = []
	for k: Variant in _caltrops:
		if is_instance_valid(k) and not (k as Caltrop).is_queued_for_deletion():
			caltrops.append(k as Caltrop)
	_caltrops = caltrops

static func _fmt_s(seconds: float) -> String:
	return str(snappedf(seconds, 0.1)).trim_suffix(".0")

func _clamp_to_world(top_left: Vector2, size: Vector2) -> Vector2:
	return Vector2(
		clampf(roundf(top_left.x), 0.0, maxf(0.0, world_size.x - size.x)),
		clampf(roundf(top_left.y), 0.0, maxf(0.0, world_size.y - size.y)))

func _place_fx(at: Vector2, color: Color, n: int) -> void:
	if fx:
		fx.burst(at, n, color, Vector2(-80, 80), Vector2(-130, -20), 400.0, 0.5, 4.0)

func _debris(at: Vector2, color: Color, n: int) -> void:
	if fx:
		fx.burst(at, n, color, Vector2(-90, 90), Vector2(-140, -20), 420.0, 0.55)
