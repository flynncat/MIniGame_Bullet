## Main controller: state machine, level loading, lives/class rotation, scoring,
## and wiring between the runner, the defender economy and the UI.
## Levels are plain scenes listed in [member level_scenes] - reorder or add them in the Inspector.
class_name Game
extends Control

## FINISH = flag reached, level-clear sweep playing (world runs, input off) before CLEAR / WIN.
enum State { TITLE, PLAY, PAUSE, CLEAR, OVER, WIN, FINISH }

## Emitted after every state change (used by automated tests).
signal state_changed(state: State)

@export var level_scenes: Array[PackedScene] = []
## Player-2 economy + turret / rocket / caltrop stats. Double-click the .tres to tune in the Inspector.
@export var defense_config: DefenseConfig
## Runner movement / jump / dash / lives / classes. Double-click the .tres to tune in the Inspector.
@export var player_config: PlayerConfig

const DEFAULT_DEFENSE_CONFIG: String = "res://config/defense_config.tres"
const DEFAULT_PLAYER_CONFIG: String = "res://config/player_config.tres"

@onready var level_slot: Node2D = %LevelSlot
@onready var player: Player = %Player
@onready var camera: GameCamera = %Camera
@onready var defense: DefenseController = %Defense
@onready var placer: DefensePlacer = %Placer
@onready var fx: FxLayer = %Fx
@onready var sky: SkyBackdrop = %Sky
@onready var hud: Hud = %Hud
@onready var shop: ShopPanel = %Shop
@onready var overlay: Overlay = %Overlay
@onready var settings_button: SettingsButton = %SettingsButton
@onready var settings: SettingsDialog = %Settings

const SETTINGS_SECTION: String = "gameplay"
const SETTINGS_KEY_CONTINUE: String = "continue_from_death"

## Persistent settings file (IndexedDB on the web build). Tests may override before _ready.
var settings_path: String = "user://settings.cfg"
## Persistent coin leaderboard file. Tests may override before _ready.
var leaderboard_path: String = "user://leaderboard.cfg"
var leaderboard: Leaderboard
## Runner coin abilities + level-clear sweep (created at runtime inside the game world).
var abilities: RunnerAbilities
## Rank of the most recent level clear / full run (1-based, 0 = none yet).
var last_level_rank: int = 0
var last_run_rank: int = 0
## When true, Game Over restarts at the level where the runner fell instead of level 1.
var continue_from_death: bool = false

var state: State = State.TITLE
var run: RunState = RunState.new()
var level: Level = null

var _world_size: Vector2 = Vector2(960, 540)
## True if opening the settings dialog paused a running game (resume on close).
var _paused_by_settings: bool = false
## Incremented on every level load so a pending sweep timer from an old level is ignored.
var _finish_token: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Run after the player so the camera follows this frame's position.
	process_physics_priority = 100
	leaderboard = Leaderboard.new(leaderboard_path)
	abilities = RunnerAbilities.new()
	abilities.name = "Abilities"
	abilities.defense = defense
	abilities.fx = fx
	abilities.camera = camera
	player.get_parent().add_child(abilities)
	abilities.notice.connect(hud.toast)
	placer.defense = defense
	_inject_configs()
	player.damaged.connect(_on_player_damaged)
	defense.budget_changed.connect(shop.update_budget)
	defense.notice.connect(shop.flash)
	placer.selection_changed.connect(shop.update_selection)
	placer.place_requested.connect(_on_place_requested)
	shop.item_pressed.connect(_on_shop_item_pressed)
	shop.clear_pressed.connect(_on_shop_clear_pressed)
	shop.upgrade_pressed.connect(_on_shop_upgrade_pressed)
	defense.upgrades_changed.connect(func() -> void: shop.update_upgrades(defense))
	overlay.confirmed.connect(_on_overlay_confirmed)
	settings_button.pressed.connect(open_settings)
	settings.closed.connect(_on_settings_closed)
	settings.level_chosen.connect(start_at_level)
	settings.continue_mode_toggled.connect(_on_continue_mode_toggled)
	_load_settings()
	hud.run = run
	hud.player = player
	hud.defense = defense
	hud.placer = placer
	if level_scenes.is_empty():
		push_error("Game: level_scenes is empty - assign level scenes on the Main node.")
		return
	load_level(0, false)
	set_state(State.TITLE)

# ------------------------------------------------------------------ config

## Hands the config tables to every consumer (falls back to the default .tres files).
func _inject_configs() -> void:
	if defense_config == null and ResourceLoader.exists(DEFAULT_DEFENSE_CONFIG):
		defense_config = load(DEFAULT_DEFENSE_CONFIG) as DefenseConfig
	if player_config == null and ResourceLoader.exists(DEFAULT_PLAYER_CONFIG):
		player_config = load(DEFAULT_PLAYER_CONFIG) as PlayerConfig
	if defense_config == null:
		defense_config = DefenseConfig.new()
	if player_config == null:
		player_config = PlayerConfig.new()
	defense.config = defense_config
	player.config = player_config
	abilities.config = player_config
	run.config = player_config
	run.lives = player_config.max_lives()
	shop.set_config(defense_config)

# ------------------------------------------------------------------ levels

func load_level(index: int, keep_score: bool) -> void:
	run.level_index = clampi(index, 0, level_scenes.size() - 1)
	if level:
		level_slot.remove_child(level)
		level.queue_free()
	level = level_scenes[run.level_index].instantiate() as Level
	assert(level != null, "Level scene root must use level.gd")
	level_slot.add_child(level)
	_world_size = Vector2(level.world_size)
	if not keep_score:
		run.reset_run()
	_finish_token += 1
	abilities.reset()
	hud.hide_banner()
	run.level_coins = 0
	run.level_spent = 0
	run.level_time = 0.0
	run.level_name = level.level_name
	var coins: Array[Coin] = level.get_coins()
	run.coin_total = coins.size()
	for c: Coin in coins:
		c.collected.connect(_on_coin_collected)
	level.goal.reached.connect(_on_goal_reached)
	defense.reset_for_level(_world_size, not keep_score)
	defense.adopt_level_turrets(level.get_turrets())
	player.world_width = _world_size.x
	camera.world_size = _world_size
	hud.world_height = _world_size.y
	sky.configure(level.theme, _world_size)
	fx.clear()
	placer.cancel()
	respawn_at_spawn()

func respawn_at_spawn() -> void:
	var c: Vector2 = level.spawn.global_position
	player.safe_position = c
	_respawn(c)

func _respawn(center: Vector2) -> void:
	player.respawn_at(center, run.current_class())
	defense.clear_bullets()
	camera.snap_to(center)

# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if level == null:
		return
	if state == State.FINISH:
		camera.follow(player.global_position, delta)
		return
	if state != State.PLAY:
		return
	run.level_time += delta
	run.total_time += delta
	if player.shake_request > 0.0:
		camera.add_shake(player.shake_request)
		player.shake_request = 0.0
	camera.follow(player.global_position, delta)
	if player.dead:
		return
	var top: float = player.global_position.y - Player.BODY.y * 0.5
	var fall_limit: float = minf(_world_size.y + 80.0, camera.top_left().y + Palette.VIEW_SIZE.y + 260.0)
	if top > fall_limit:
		_on_player_fell()

# ------------------------------------------------------------------ damage & lives

func _on_player_damaged(at: Vector2) -> void:
	run.lives -= 1
	camera.add_shake(12.0)
	fx.burst(at, 14, Color("#ff6b6b"))
	Audio.play(&"hurt")
	_on_life_lost(at)
	if run.lives <= 0:
		player.dead = true
		get_tree().create_timer(0.5, false).timeout.connect(func() -> void:
			if state == State.PLAY:
				set_state(State.OVER))
	else:
		_respawn.call_deferred(player.safe_position)

func _on_player_fell() -> void:
	run.lives -= 1
	camera.add_shake(14.0)
	Audio.play(&"hurt")
	_on_life_lost(player.safe_position)
	if run.lives <= 0:
		set_state(State.OVER)
		return
	_respawn(player.safe_position)

## Resolves the ability of the class that just died (call after lives--).
func _on_life_lost(at: Vector2) -> void:
	var died: RunnerClassConfig = run.class_just_lost()
	if died.death_ability == RunnerClassConfig.Ability.BOMB:
		fx.burst(at, 30, Color("#ff8c42"), Vector2(-280, 280), Vector2(-280, 80), 300.0, 0.9, 6.0)
		fx.burst(at, 18, Color("#ffe08a"), Vector2(-160, 160), Vector2(-160, 40), 200.0, 0.6, 4.0)
		camera.add_shake(20.0)
		Audio.play(&"boom")
		var n: int = defense.destroy_in_radius(at, player_config.bomb_radius)
		if n > 0:
			shop.flash("%s阵亡引爆，摧毁 %d 个防御单位" % [died.display_name, n])
	elif died.death_ability == RunnerClassConfig.Ability.ENGINEER:
		var w: float = player_config.engineer_platform_width
		var mp := MovingPlatform.new()
		mp.size = Vector2(w, 14)
		mp.axis = MovingPlatform.Axis.HORIZONTAL
		mp.distance = player_config.engineer_platform_distance
		mp.speed = player_config.engineer_platform_speed
		mp.position = Vector2(
			clampf(roundf(at.x - w * 0.5), 0.0, maxf(0.0, _world_size.x - w)),
			clampf(roundf(at.y - 84.0 - 14.0), 0.0, maxf(0.0, _world_size.y - 16.0)))
		level.platforms_root.add_child.call_deferred(mp)
		fx.burst(mp.position + Vector2(w * 0.5, 7), 16, Color("#6cf0a0"), Vector2(-140, 140), Vector2(-160, 20), 350.0, 0.6, 4.0)
		Audio.play(&"place")
		shop.flash("%s阵亡，留下一座左右巡逻平台" % died.display_name)

# ------------------------------------------------------------------ pickups & goal

func _on_coin_collected(coin: Coin) -> void:
	run.coin_count += 1
	run.level_coins += 1
	run.wallet += 1
	run.score += 100
	defense.add_budget(defense_config.coin_bonus)
	fx.burst(coin.global_position + Vector2(8, 8), 10, Color("#ffd76a"), Vector2(-80, 80), Vector2(-160, -40), 500.0, 0.5, 4.0)
	Audio.play(&"coin")

func _on_goal_reached() -> void:
	if state != State.PLAY:
		return
	run.score += 500 + maxi(0, roundi((90.0 - run.level_time) * 10.0))
	Audio.play(&"clear")
	_begin_finish.call_deferred()

## Flag reached: record the leaderboard, play the sweep, then show CLEAR / WIN.
func _begin_finish() -> void:
	if state != State.PLAY:
		return
	# Settlement ranks the coins left after spending, not the coins picked up.
	last_level_rank = leaderboard.submit(_level_board_id(), run.wallet, run.level_time)
	set_state(State.FINISH)
	hud.show_banner("关卡完成！", "剩余金币 %d · 排名第 %d" % [run.wallet, last_level_rank])
	abilities.goal_sweep(level.goal.global_position + Goal.SIZE * 0.5, level)
	var token: int = _finish_token
	get_tree().create_timer(player_config.goal_sweep_time, false, true).timeout.connect(func() -> void:
		if token == _finish_token and state == State.FINISH:
			_end_finish())

func _end_finish() -> void:
	hud.hide_banner()
	if run.level_index < level_scenes.size() - 1:
		set_state(State.CLEAR)
	else:
		last_run_rank = leaderboard.submit(Leaderboard.RUN_BOARD, run.wallet, run.total_time)
		set_state(State.WIN)

func _level_board_id() -> String:
	var path: String = level_scenes[run.level_index].resource_path
	return path if not path.is_empty() else run.level_name

# ------------------------------------------------------------------ runner abilities

## Shield at the runner's position (costs coins). Returns true on success.
func use_shield() -> bool:
	if state != State.PLAY or player.dead:
		return false
	return abilities.try_shield(player.global_position, run)

## Wave that clears turrets / rocket launchers / projectiles on screen (costs coins).
func use_screen_clear() -> bool:
	if state != State.PLAY or player.dead:
		return false
	var view := Rect2(camera.top_left(), Palette.VIEW_SIZE)
	return abilities.try_screen_clear(player.global_position, view, run) != null

# ------------------------------------------------------------------ defender

func _on_shop_item_pressed(item: DefenseCatalog.Item) -> void:
	if state == State.PLAY:
		placer.select(item)
	else:
		shop.update_selection(DefenseCatalog.Item.NONE)

func _on_place_requested(item: DefenseCatalog.Item, world_pos: Vector2, dir_index: int) -> void:
	if state == State.PLAY:
		defense.try_place(item, world_pos, dir_index)

func _on_shop_upgrade_pressed(item: DefenseCatalog.Item) -> void:
	if state == State.PLAY:
		defense.upgrade_item(item)

func _on_shop_clear_pressed() -> void:
	var n: int = defense.clear_all()
	shop.flash("已移除 %d 个防御道具（不返还资金）" % n if n > 0 else "当前没有已放置的防御道具")

# ------------------------------------------------------------------ state machine

func set_state(s: State) -> void:
	state = s
	var playing: bool = s == State.PLAY
	# The world keeps running during the level-clear sweep so the animation plays.
	get_tree().paused = not (playing or s == State.FINISH)
	defense.active = playing
	placer.enabled = playing
	player.input_enabled = playing
	if s == State.FINISH:
		placer.cancel()
	if playing or s == State.FINISH:
		overlay.hide_screen()
	else:
		_show_overlay(s)
	state_changed.emit(s)

func _show_overlay(s: State) -> void:
	match s:
		State.TITLE:
			overlay.show_screen("云端跳跃 · 双人对抗",
				"[b]双人对抗[/b]：玩家 1（手柄 / 键盘）操控小人抵达旗帜，玩家 2（鼠标）布防拦截\n" +
				"[b]玩家 1[/b] %s\n" % _classes_summary() +
				"手柄：[b]左摇杆[/b] 移动　[b]A[/b] 跳　[b]X / RB[/b] 冲刺　[b]下[/b] 穿过木板　[b]Back[/b] 回出生点　[b]Start[/b] 暂停\n" +
				"键盘：[b]← →[/b] 移动　[b]空格[/b] 跳　[b]Shift[/b] 冲刺　[b]↓[/b] 穿过木板　[b]R[/b] 回出生点　·　每次阵亡回到最近落脚点并换兵种\n" +
				"金币技能：[b]Y / Q[/b] 原地护盾（%d 金币）　[b]B / E[/b] 清屏炮塔与弹幕（%d 金币）　·　通关按结算剩余金币排名\n" % [player_config.shield_cost, player_config.screen_clear_cost] +
				"[b]玩家 2[/b]：在右侧面板选道具（%s / %s 拖拽定向，%s 点哪投哪）→ 在游戏画面里松手安放\n" % [defense_config.display_name(DefenseCatalog.Item.TURRET), defense_config.display_name(DefenseCatalog.Item.ROCKET), defense_config.display_name(DefenseCatalog.Item.CALTROP)] +
				"物品放置后需充能（最长 %s 秒）才生效 · 每秒 +%d 资金，跑者吃金币也会给你 +%d" % [DefenseController._fmt_s(defense_config.max_arm_time()), int(defense_config.income_per_sec), defense_config.coin_bonus],
				"开始游戏（A / Enter）")
		State.PAUSE:
			overlay.show_screen("已暂停", "按 [b]P[/b] / 手柄 [b]Start[/b] 或点击按钮继续", "继续")
		State.CLEAR:
			overlay.show_screen("过关！玩家 1 抢先登顶",
				"本关用时 [b]%.1fs[/b]　本关拾取 [b]%d/%d[/b]　本关消费 [b]%d[/b]　结算剩余金币 [b]%d[/b]\n当前总分 [b]%d[/b]　剩余生命 [b]%d[/b]\n\n[b]%s · 剩余金币排行[/b]（本次第 %d 名）\n%s" % [run.level_time, run.level_coins, run.coin_total, run.level_spent, run.wallet, run.score, run.lives, run.level_name, last_level_rank, leaderboard.format_board(_level_board_id(), player_config.leaderboard_show, last_level_rank)],
				"下一关 →")
		State.WIN:
			overlay.show_screen("全部通关！",
				"[b]玩家 1[/b] 挡住了防御方所有拦截，独自通关全部 %d 关\n总用时 [b]%s[/b]　累计拾取 [b]%d[/b]　累计消费 [b]%d[/b]　最终剩余金币 [b]%d[/b]　剩余生命 [b]%d[/b]　最终得分 [b]%d[/b]\n\n[b]本关剩余金币排行[/b]（本次第 %d 名）\n%s\n\n[b]全程剩余金币排行[/b]（本次第 %d 名）\n%s" % [level_scenes.size(), RunState.format_time(run.total_time), run.coin_count, run.run_spent, run.wallet, run.lives, run.score, last_level_rank, leaderboard.format_board(_level_board_id(), 3, last_level_rank), last_run_rank, leaderboard.format_board(Leaderboard.RUN_BOARD, player_config.leaderboard_show, last_run_rank)],
				"再玩一次")
			Audio.play(&"clear")
		State.OVER:
			var retry_hint: String = "将在 [b]%s[/b] 重新开始（生命重置为 %d）" % [run.level_name, run.max_lives()] if continue_from_death else "将回到第 1 关 · 右上角设置可开启「从死亡关卡继续」"
			overlay.show_screen("游戏结束 · 玩家 2 获胜！",
				"[b]玩家 1[/b] 倒在了 [b]%s[/b]，防御系统成功拦截\n得分 [b]%d[/b]　收集金币 [b]%d[/b]　场上防御道具 [b]%d[/b] 个\n%s" % [run.level_name, run.score, run.coin_count, defense.unit_count(), retry_hint],
				"从本关继续" if continue_from_death else "重新开始")
			Audio.play(&"over")

func _classes_summary() -> String:
	var parts := PackedStringArray()
	for c: RunnerClassConfig in player_config.classes:
		parts.append("[b]%s[/b]（%s）" % [c.display_name, c.description])
	return "%d 条命 %d 种兵种：%s" % [run.max_lives(), parts.size(), " → ".join(parts)]

func _on_overlay_confirmed() -> void:
	match state:
		State.OVER:
			load_level(run.level_index if continue_from_death else 0, false)
			set_state(State.PLAY)
		State.TITLE, State.WIN:
			load_level(0, false)
			set_state(State.PLAY)
		State.PAUSE:
			set_state(State.PLAY)
		State.CLEAR:
			load_level(run.level_index + 1, true)
			set_state(State.PLAY)

# ------------------------------------------------------------------ settings

func level_names() -> PackedStringArray:
	var names := PackedStringArray()
	for i: int in level_scenes.size():
		names.append(_scene_level_name(level_scenes[i], i))
	return names

## Reads Level.level_name from the packed scene without instancing it.
static func _scene_level_name(scene: PackedScene, index: int) -> String:
	var st: SceneState = scene.get_state()
	for i: int in st.get_node_property_count(0):
		if st.get_node_property_name(0, i) == &"level_name":
			return String(st.get_node_property_value(0, i))
	return "关卡 %d" % (index + 1)

func open_settings() -> void:
	if settings.visible:
		return
	if state == State.PLAY:
		set_state(State.PAUSE)
		_paused_by_settings = true
	settings.open(level_names(), run.level_index, continue_from_death)

func _on_settings_closed() -> void:
	if _paused_by_settings and state == State.PAUSE:
		set_state(State.PLAY)
	_paused_by_settings = false

## Starts a fresh run at [param index] (lives / score / defender budget reset).
func start_at_level(index: int) -> void:
	_paused_by_settings = false
	settings.close_dialog()
	load_level(index, false)
	set_state(State.PLAY)

func _on_continue_mode_toggled(enabled: bool) -> void:
	continue_from_death = enabled
	_save_settings()
	if state == State.OVER:
		_show_overlay(State.OVER)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		continue_from_death = bool(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_CONTINUE, false))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_CONTINUE, continue_from_death)
	var err: Error = cfg.save(settings_path)
	if err != OK:
		push_warning("Game: could not save settings (%s)" % error_string(err))

# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or settings.visible:
		return
	match state:
		State.PLAY:
			if event.is_action_pressed(&"pause"):
				set_state(State.PAUSE)
			elif event.is_action_pressed(&"restart"):
				respawn_at_spawn()
			elif event.is_action_pressed(&"cancel_place"):
				placer.cancel()
			elif event.is_action_pressed(&"shield"):
				use_shield()
			elif event.is_action_pressed(&"screen_clear"):
				use_screen_clear()
		State.FINISH:
			pass
		State.PAUSE:
			# Start toggles back; A / Enter also resume.
			if event.is_action_pressed(&"pause") or event.is_action_pressed(&"confirm"):
				set_state(State.PLAY)
		_:
			# Title / clear / over / win: A, Start or Enter advance.
			if event.is_action_pressed(&"confirm"):
				_on_overlay_confirmed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAY:
		set_state(State.PAUSE)
