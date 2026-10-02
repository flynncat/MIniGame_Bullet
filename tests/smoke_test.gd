## Headless gameplay regression test. Run from the project folder:
##   godot --headless --path . --fixed-fps 120 --script res://tests/smoke_test.gd
## Exit code = number of failed checks (0 = all passed).
extends SceneTree

var game: Game
var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate() as Game
	# Isolated settings file so the test never touches the player's real settings.
	game.settings_path = "user://test_settings.cfg"
	# Use pristine fixture copies of the original levels (real level scenes may be edited by designers).
	var fixtures: Array[PackedScene] = []
	for i: int in 4:
		fixtures.append(load("res://tests/fixtures/fixture_level_%02d.tscn" % (i + 1)) as PackedScene)
	game.level_scenes = fixtures
	# Pristine default tables too, so tuning the real config does not break assertions.
	game.defense_config = _default_defense_config()
	game.player_config = _default_player_config()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path))
	game.leaderboard_path = "user://test_leaderboard.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.leaderboard_path))
	root.add_child(game)
	create_timer(240.0, true).timeout.connect(func() -> void:
		print("TIMEOUT - test aborted")
		quit(99))
	_run.call_deferred()

static func _default_defense_config() -> DefenseConfig:
	var c := DefenseConfig.new()
	c.turret = TurretStats.new()
	c.turret.display_name = "炮塔"
	c.turret.upgrade_effects = TurretStats.UpgradeEffect.SINE_PATH
	var r := TurretStats.new()
	r.display_name = "火箭炮"
	r.price = 300
	r.fire_interval = 2.6
	r.projectile_speed = 220.0
	r.projectile_lifetime = 6.0
	r.homing = true
	r.upgraded_price = 450
	r.upgrade_effects = TurretStats.UpgradeEffect.SPLIT_BURST
	c.rocket = r
	c.caltrop = CaltropStats.new()
	return c

static func _runner_class(n: String, col: Color, jumps: int, ability: RunnerClassConfig.Ability) -> RunnerClassConfig:
	var rc := RunnerClassConfig.new()
	rc.display_name = n
	rc.color = col
	rc.max_jumps = jumps
	rc.death_ability = ability
	return rc

static func _default_player_config() -> PlayerConfig:
	var pc := PlayerConfig.new()
	pc.classes = [
		_runner_class("炸弹小队", Color("#ff8c42"), 2, RunnerClassConfig.Ability.BOMB),
		_runner_class("工程师", Color("#6cf0a0"), 2, RunnerClassConfig.Ability.ENGINEER),
		_runner_class("火箭兵", Color("#7fd4ff"), 3, RunnerClassConfig.Ability.NONE),
	]
	return pc

func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)

func frames(n: int) -> void:
	for i: int in n:
		await physics_frame

func settle_player(at: Vector2) -> void:
	game.player.global_position = at
	game.player.velocity = Vector2.ZERO
	await frames(30)

func pad_button(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)

func pad_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)

func count_bullets() -> int:
	var n: int = 0
	for c: Node in game.defense.get_children():
		if c is Bullet and not c.is_queued_for_deletion():
			n += 1
	return n

func _run() -> void:
	await frames(5)
	var p: Player = game.player
	print("[1] boot")
	check(game.state == Game.State.TITLE, "starts on title screen")
	check(game.level != null and game.level.level_name == "垂直塔 · 云端登顶", "level 1 (tower) instanced")
	check(game.run.coin_total == 35, "tower has 35 coins (got %d)" % game.run.coin_total)
	check(paused, "tree paused on title")

	print("[2] start with gamepad A + movement")
	pad_button(JOY_BUTTON_A, true)
	await frames(20)
	check(game.state == Game.State.PLAY, "gamepad A confirms title screen")
	check(p.velocity.y >= 0.0 and p._jumps == 0, "confirm press does not make the runner jump")
	pad_button(JOY_BUTTON_A, false)
	await frames(40)
	check(game.state == Game.State.PLAY and not paused, "PLAY after confirm, tree running")
	check(p.is_on_floor(), "runner lands on ground")
	check(absf(p.global_position.y - 922.0) < 2.0, "rests on ground top (y=%.1f, expect 922)" % p.global_position.y)
	var x0: float = p.global_position.x
	Input.action_press(&"move_right")
	await frames(40)
	Input.action_release(&"move_right")
	check(p.global_position.x - x0 > 60.0, "moves right (dx=%.1f)" % (p.global_position.x - x0))
	await frames(40)

	print("[3] jump / multi-jump / dash")
	var y0: float = p.global_position.y
	Input.action_press(&"jump")
	await frames(12)
	var y1: float = p.global_position.y
	check(y0 - y1 > 40.0, "single jump rises (dy=%.1f)" % (y0 - y1))
	Input.action_release(&"jump")
	await frames(2)
	Input.action_press(&"jump")
	await frames(10)
	check(p._jumps == 2, "air jump counted (jumps=%d)" % p._jumps)
	Input.action_release(&"jump")
	await frames(120)
	var dx0: float = p.global_position.x
	Input.action_press(&"dash")
	await frames(10)
	Input.action_release(&"dash")
	check(absf(p.global_position.x - dx0) > 40.0, "dash moves fast (dx=%.1f)" % absf(p.global_position.x - dx0))
	check(p.dash_cooldown > 0.0, "dash cooldown started")
	await frames(80)

	print("[3b] gamepad controls runner")
	await settle_player(Vector2(100, 922))
	var gx0: float = p.global_position.x
	pad_axis(JOY_AXIS_LEFT_X, 0.2)
	await frames(20)
	check(absf(p.global_position.x - gx0) < 1.0, "stick inside deadzone (0.2) does not move")
	pad_axis(JOY_AXIS_LEFT_X, 0.9)
	await frames(40)
	check(p.global_position.x - gx0 > 60.0 and p.facing > 0.0, "left stick right moves runner (dx=%.1f)" % (p.global_position.x - gx0))
	pad_axis(JOY_AXIS_LEFT_X, 0.0)
	await frames(40)
	var gx1: float = p.global_position.x
	pad_button(JOY_BUTTON_DPAD_LEFT, true)
	await frames(40)
	pad_button(JOY_BUTTON_DPAD_LEFT, false)
	check(gx1 - p.global_position.x > 60.0 and p.facing < 0.0, "d-pad left moves runner (dx=%.1f)" % (gx1 - p.global_position.x))
	await frames(40)
	var gy0: float = p.global_position.y
	pad_button(JOY_BUTTON_A, true)
	await frames(12)
	check(gy0 - p.global_position.y > 40.0, "button A jumps (dy=%.1f)" % (gy0 - p.global_position.y))
	pad_button(JOY_BUTTON_A, false)
	await frames(2)
	pad_button(JOY_BUTTON_A, true)
	await frames(6)
	check(p._jumps == 2, "button A air-jump (jumps=%d)" % p._jumps)
	pad_button(JOY_BUTTON_A, false)
	await frames(120)
	var gx2: float = p.global_position.x
	pad_button(JOY_BUTTON_X, true)
	await frames(10)
	pad_button(JOY_BUTTON_X, false)
	check(absf(p.global_position.x - gx2) > 40.0 and p.dash_cooldown > 0.0, "button X dashes (dx=%.1f)" % absf(p.global_position.x - gx2))
	await frames(90)
	await settle_player(Vector2(480, 922))
	var gx3: float = p.global_position.x
	pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(10)
	pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(absf(p.global_position.x - gx3) > 40.0, "right trigger dashes (dx=%.1f)" % absf(p.global_position.x - gx3))
	await frames(90)
	pad_button(JOY_BUTTON_START, true)
	await frames(3)
	pad_button(JOY_BUTTON_START, false)
	await frames(3)
	check(game.state == Game.State.PAUSE, "Start pauses")
	pad_button(JOY_BUTTON_START, true)
	await frames(3)
	pad_button(JOY_BUTTON_START, false)
	await frames(3)
	check(game.state == Game.State.PLAY, "Start resumes")
	pad_button(JOY_BUTTON_START, true)
	await frames(3)
	pad_button(JOY_BUTTON_START, false)
	pad_button(JOY_BUTTON_A, true)
	await frames(3)
	check(game.state == Game.State.PLAY and p._jumps == 0, "A resumes from pause without jumping")
	pad_button(JOY_BUTTON_A, false)
	await settle_player(Vector2(300, 922))
	pad_button(JOY_BUTTON_BACK, true)
	await frames(3)
	pad_button(JOY_BUTTON_BACK, false)
	check(p.global_position.distance_to(game.level.spawn.global_position) < 2.0, "Back returns runner to spawn")
	await frames(20)

	print("[4] coin pickup")
	var coins: Array[Coin] = game.level.get_coins()
	var coin: Coin = coins[0]
	var budget_before: int = int(game.defense.budget)
	var score_before: int = game.run.score
	p.global_position = coin.global_position + Vector2(8, 8)
	await frames(4)
	check(game.run.coin_count >= 1, "coin counted (%d)" % game.run.coin_count)
	check(game.run.score == score_before + 100 * game.run.coin_count, "score +100 per coin")
	check(int(game.defense.budget) >= budget_before + 100, "defender budget +100 on coin")
	check(game.run.wallet == game.run.coin_count and game.run.level_coins == game.run.coin_count, "coins go to the runner wallet (%d)" % game.run.wallet)

	print("[5] spike damage -> bomb class explodes, class rotates")
	await settle_player(Vector2(100, 922))
	var turret_ok: bool = game.defense.try_place(DefenseCatalog.Item.TURRET, Vector2(740, 690), 4)
	check(turret_ok, "turret placed next to spike")
	p.invuln = 0.0
	var spike_center := Vector2(713 + 30, 703 + 6)
	p.global_position = spike_center + Vector2(0, -10)
	p.velocity = Vector2.ZERO
	await frames(3)
	check(game.run.lives == 2, "lost a life on spike (lives=%d)" % game.run.lives)
	check(game.run.current_class().death_ability == RunnerClassConfig.Ability.ENGINEER, "class rotated to engineer")
	check(game.defense.unit_count() == 0, "bomb destroyed turret within radius")
	check(p.max_jumps == 2, "engineer has 2 jumps")
	check(p.global_position.distance_to(Vector2(100, 922)) < 4.0, "respawned at last safe point (%s)" % p.global_position)

	print("[6] turret arming + firing, rocket, caltrop")
	await frames(10)
	p.invuln = 999.0  # keep the runner safe while testing defenses
	var homing_spawned: Array[int] = [0]
	game.defense.child_entered_tree.connect(func(n: Node) -> void:
		if n is Bullet and (n as Bullet).homing:
			homing_spawned[0] += 1)
	game.defense.add_budget(2000)
	check(game.defense.try_place(DefenseCatalog.Item.TURRET, Vector2(300, 700), 0), "turret placed")
	var turret: Turret = null
	for c: Node in game.defense.get_children():
		if c is Turret:
			turret = c
	check(turret != null and absf(turret.arm_time - 3.0) < 0.05, "turret arming 3s")
	await frames(300)
	check(count_bullets() == 0, "no shots while arming (2.5s)")
	await frames(120)
	check(count_bullets() >= 1, "fires after arming (bullets=%d)" % count_bullets())
	check(game.defense.try_place(DefenseCatalog.Item.ROCKET, Vector2(120, 560), 7), "rocket placed")
	check(game.defense.try_place(DefenseCatalog.Item.CALTROP, Vector2(600, 700), 0), "caltrop dropped")
	var caltrop: Caltrop = null
	for c: Node in game.defense.get_children():
		if c is Caltrop:
			caltrop = c
	await frames(90)
	check(caltrop != null and caltrop.landed, "caltrop landed")
	if caltrop:
		var bottom: float = caltrop.global_position.y + DefenseCatalog.CALTROP_SIZE.y
		check(absf(bottom - 715.0) < 1.5, "caltrop snapped onto platform top y=715 (bottom=%.1f)" % bottom)
	await frames(420)
	check(homing_spawned[0] >= 1, "rocket launched homing missile (%d)" % homing_spawned[0])
	var placed: Array[int] = []
	game.placer.place_requested.connect(func(_it: DefenseCatalog.Item, _pos: Vector2, d: int) -> void: placed.append(d), CONNECT_ONE_SHOT)
	game.placer.select(DefenseCatalog.Item.TURRET)
	game.placer.begin_drag(Vector2(500, 600))
	game.placer.end_drag(Vector2(420, 600))
	check(placed.size() == 1 and placed[0] == 4, "drag-left placement faces LEFT (dir=%s)" % str(placed))
	game.placer.begin_drag(Vector2(500, 600))
	game.placer.end_drag(Vector2(505, 603))
	var last_turret: Turret = null
	for c: Node in game.defense.get_children():
		if c is Turret and not c.is_queued_for_deletion():
			last_turret = c
	check(last_turret != null and last_turret.direction == Turret.Dir8.LEFT, "short click reuses last direction")
	game.placer.cancel()
	var low_budget: float = game.defense.budget
	game.defense.budget = 50
	check(not game.defense.try_place(DefenseCatalog.Item.TURRET, Vector2(300, 300), 0), "cannot buy without budget")
	game.defense.budget = low_budget
	var cleared: int = game.defense.clear_all()
	check(cleared == 5, "clear_all removed 5 units (got %d)" % cleared)
	check(count_bullets() == 0, "clear_all removed projectiles")
	await settle_player(Vector2(100, 922))
	p.invuln = 0.0
	check(game.run.lives == 2, "runner unharmed during defense test (lives=%d)" % game.run.lives)
	check(p.safe_position.distance_to(Vector2(743, 697)) > 50.0, "safe point never recorded on spikes (%s)" % p.safe_position)

	print("[7] one-way plank: stand, drop through, jump up through")
	await settle_player(Vector2(841, 279 - 18 - 2))
	check(p.is_on_floor() and absf(p.global_position.y - 261.0) < 2.0, "stands on one-way plank (y=%.1f)" % p.global_position.y)
	Input.action_press(&"move_down")
	await frames(20)
	Input.action_release(&"move_down")
	check(p.global_position.y > 285.0, "drops through with Down (y=%.1f)" % p.global_position.y)
	await settle_player(Vector2(841, 279 - 18 - 2))
	pad_axis(JOY_AXIS_LEFT_Y, 0.4)
	await frames(20)
	check(p.global_position.y < 262.0, "stick half-down (0.4) keeps runner on plank")
	pad_axis(JOY_AXIS_LEFT_Y, 1.0)
	await frames(20)
	pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	check(p.global_position.y > 285.0, "stick full-down drops through plank (y=%.1f)" % p.global_position.y)
	p.global_position = Vector2(841, 330)
	p.velocity = Vector2.ZERO
	Input.action_press(&"jump")
	await frames(30)
	Input.action_release(&"jump")
	check(p.global_position.y < 279.0, "passes up through plank from below (y=%.1f)" % p.global_position.y)
	await frames(60)

	print("[8] engineer death spawns patrol platform")
	await settle_player(Vector2(100, 922))
	var platforms_before: int = game.level.platforms_root.get_child_count()
	p.invuln = 0.0
	p.take_hit(0.0)
	await frames(3)
	check(game.run.lives == 1, "lives=1")
	check(game.level.platforms_root.get_child_count() == platforms_before + 1, "engineer left a moving platform")
	check(p.max_jumps == 3, "rocket class has 3 jumps")

	print("[9] goal -> sweep -> CLEAR -> next level keeps score")
	var score_mid: int = game.run.score
	# Spend coins before the flag: settlement must rank the REMAINING coins.
	game.run.wallet = 20
	check(game.use_shield(), "shield bought before the flag")
	var remaining_at_clear: int = game.run.wallet
	game.defense.budget = 5000
	check(game.defense.try_place(DefenseCatalog.Item.TURRET, Vector2(200, 300), 0), "turret placed before goal")
	check(game.defense.try_place(DefenseCatalog.Item.CALTROP, Vector2(600, 200), 0), "caltrop placed before goal")
	check(not game.level.get_spikes().is_empty(), "level has spikes before goal")
	p.global_position = game.level.goal.global_position + Vector2(23, 43)
	await frames(4)
	check(game.state == Game.State.FINISH, "goal starts the level-clear sweep")
	check(game.hud.banner_visible() and not game.overlay.visible, "banner shown, success prompt not yet")
	check(game.last_level_rank == 1, "clear recorded on the leaderboard (rank %d)" % game.last_level_rank)
	check(game.run.score > score_mid, "clear bonus added")
	await frames(120)
	check(game.state == Game.State.FINISH, "prompt still waiting at 1s")
	check(game.defense.unit_count() == 0 and count_bullets() == 0, "sweep destroyed every turret / caltrop / projectile")
	check(game.level.get_spikes().is_empty(), "sweep destroyed the spikes")
	await frames(130)
	check(game.state == Game.State.CLEAR and not game.hud.banner_visible(), "success prompt after the 2s sweep")
	check(game.overlay._body.text.contains("剩余金币排行") and game.overlay._body.text.contains("本关消费"), "clear screen shows spent coins and the remaining-coin leaderboard")
	var lb_top: Array[Leaderboard.Entry] = game.leaderboard.top(game.level_scenes[0].resource_path, 5)
	check(game.run.level_spent == 5, "level spending tracked (%d)" % game.run.level_spent)
	check(lb_top.size() == 1 and lb_top[0].coins == game.run.wallet and game.run.wallet >= remaining_at_clear and game.run.wallet != 20 + game.run.level_coins, "leaderboard stores remaining coins, not collected (%d entries, top=%d, wallet=%d, collected=%d)" % [lb_top.size(), lb_top[0].coins if lb_top.size() > 0 else -1, game.run.wallet, game.run.level_coins])
	game._on_overlay_confirmed()
	await frames(40)
	check(game.run.level_index == 1 and game.level.level_name == "第1关 · 云端起步", "advanced to level 2")
	check(game.run.lives == 1, "lives carried over")
	check(game.state == Game.State.PLAY, "playing level 2")
	check(p.is_on_floor(), "runner grounded in level 2")

	print("[10] moving platform carries runner")
	var mp: MovingPlatform = game.level.platforms_root.get_node("Moving6") as MovingPlatform
	await settle_player(mp.global_position + Vector2(55, -18 - 1))
	var px: float = p.global_position.x
	var mx: float = mp.global_position.x
	await frames(60)
	check(p.is_on_floor(), "still on moving platform")
	check(absf((p.global_position.x - px) - (mp.global_position.x - mx)) < 3.0 and absf(mp.global_position.x - mx) > 10.0, "moved with platform (p %.1f / mp %.1f)" % [p.global_position.x - px, mp.global_position.x - mx])

	print("[11] pause / fall out of world -> game over")
	game.set_state(Game.State.PAUSE)
	await frames(2)
	check(paused and game.overlay.visible, "paused with overlay")
	game.set_state(Game.State.PLAY)
	p.global_position = Vector2(560, 700)
	await frames(10)
	check(game.state == Game.State.OVER, "falling with last life -> OVER")
	game._on_overlay_confirmed()
	await frames(10)
	check(game.run.lives == 3 and game.run.level_index == 0 and game.state == Game.State.PLAY, "restart resets run")

	print("[12] settings: open/close pauses & resumes, level select")
	await frames(10)
	check(game.state == Game.State.PLAY and not game.continue_from_death, "default: continue-from-death off")
	game.settings_button.pressed.emit()
	await frames(2)
	check(game.settings.visible and game.state == Game.State.PAUSE and paused, "gear opens dialog and pauses play")
	var names: PackedStringArray = game.level_names()
	check(names.size() == 4 and names[2] == "第2关 · 暮色回廊", "dialog lists 4 level names from scenes")
	check(game.settings._level_list.get_child_count() == 4, "4 level buttons built")
	var close_btn := game.settings.find_child("CloseButton", true, false) as Button
	close_btn.pressed.emit()
	await frames(2)
	check(not game.settings.visible and game.state == Game.State.PLAY and not paused, "× closes dialog and resumes")
	game.open_settings()
	await frames(1)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await frames(2)
	check(not game.settings.visible and game.state == Game.State.PLAY, "Esc closes dialog")
	game.run.score = 1234
	game.open_settings()
	await frames(1)
	var lv3 := game.settings._level_list.get_child(2) as Button
	lv3.pressed.emit()
	await frames(10)
	check(game.run.level_index == 2 and game.level.level_name == "第2关 · 暮色回廊", "level select jumps to chosen level")
	check(not game.settings.visible and game.state == Game.State.PLAY, "dialog closed, playing chosen level")
	check(game.run.lives == 3 and game.run.score == 0, "level select starts a fresh run")

	print("[13] continue from death level")
	game.set_state(Game.State.OVER)
	game._on_overlay_confirmed()
	await frames(5)
	check(game.run.level_index == 0, "option off: game over restarts at level 1")
	game.start_at_level(2)
	await frames(5)
	game.open_settings()
	await frames(1)
	var chk := game.settings.find_child("ContinueCheck", true, false) as CheckButton
	chk.button_pressed = true
	await frames(1)
	check(game.continue_from_death, "toggle enables continue mode")
	var cfg := ConfigFile.new()
	check(cfg.load(game.settings_path) == OK and cfg.get_value("gameplay", "continue_from_death", false) == true, "setting persisted to disk")
	game.settings.close_dialog()
	await frames(2)
	game.player.invuln = 0.0
	for i: int in 3:
		game.player.invuln = 0.0
		game.player.take_hit(0.0)
		await frames(3)
	await frames(80)
	check(game.state == Game.State.OVER, "three hits -> game over on level 3")
	game._on_overlay_confirmed()
	await frames(10)
	check(game.run.level_index == 2 and game.run.lives == 3 and game.state == Game.State.PLAY, "option on: continues at the death level with 3 lives")
	var game2 := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Game
	game2.settings_path = game.settings_path
	game2.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game2)
	await frames(1)
	check(game2.continue_from_death, "setting reloaded by a new session")
	game2.queue_free()
	await frames(1)
	chk.button_pressed = false
	check(not game.continue_from_death, "toggle disables continue mode")

	print("[14] final level -> WIN")
	game.load_level(3, true)
	await frames(10)
	game.level.goal.reached.emit()
	await frames(3)
	check(game.state == Game.State.FINISH, "last level: sweep first")
	await frames(250)
	check(game.state == Game.State.WIN, "last level clear -> WIN")
	var run_top: Array[Leaderboard.Entry] = game.leaderboard.top(Leaderboard.RUN_BOARD, 5)
	check(game.last_run_rank == 1 and run_top.size() == 1 and run_top[0].coins == game.run.wallet, "full run records final remaining coins (%d)" % game.run.wallet)

	print("[15] config tables drive gameplay")
	var shipped_def := load("res://config/defense_config.tres") as DefenseConfig
	var shipped_pl := load("res://config/player_config.tres") as PlayerConfig
	check(shipped_def != null and shipped_def.turret != null and shipped_def.rocket != null and shipped_def.caltrop != null, "defense_config.tres loads with 3 item tables")
	check(shipped_pl != null and shipped_pl.classes.size() >= 1, "player_config.tres loads with runner classes (%d)" % (shipped_pl.classes.size() if shipped_pl else 0))
	check(shipped_def.rocket.homing and not shipped_def.turret.homing, "shipped rocket homes, turret does not")
	game.load_level(0, false)
	game.set_state(Game.State.PLAY)
	await frames(30)
	p.invuln = 999.0
	var cfg_t: TurretStats = game.defense_config.turret
	cfg_t.arm_time = 0.0
	cfg_t.first_shot_delay = 0.0
	cfg_t.fire_interval = 0.25
	cfg_t.projectile_speed = 90.0
	cfg_t.price = 50
	var shots: Array[int] = [0]
	var speeds: Array[float] = []
	game.defense.child_entered_tree.connect(func(n: Node) -> void:
		if n is Bullet:
			shots[0] += 1
			speeds.append((n as Bullet).velocity.length()))
	game.defense.budget = 60
	check(game.defense.try_place(DefenseCatalog.Item.TURRET, Vector2(300, 600), 0), "price from table (50) is charged")
	check(int(game.defense.budget) < 20, "budget dropped by table price (%d left)" % int(game.defense.budget))
	await frames(121)
	check(shots[0] >= 4 and shots[0] <= 5, "fire_interval 0.25s -> 4-5 shots in 1s (got %d)" % shots[0])
	check(speeds.size() > 0 and absf(speeds[0] - 90.0) < 0.5, "projectile_speed from table (%.1f)" % (speeds[0] if speeds.size() > 0 else -1.0))
	game.defense.clear_all()
	game.player_config.run_speed = 100.0
	await settle_player(Vector2(200, 922))
	var sx: float = p.global_position.x
	Input.action_press(&"move_right")
	await frames(120)
	Input.action_release(&"move_right")
	var moved: float = p.global_position.x - sx
	check(moved > 80.0 and moved < 105.0, "run_speed 100 -> ~100px in 1s (got %.1f)" % moved)
	game.player_config.run_speed = 310.0
	game.player_config.classes.append(_runner_class("测试兵", Color.WHITE, 5, RunnerClassConfig.Ability.NONE))
	game.load_level(0, false)
	await frames(5)
	check(game.run.lives == 4 and game.run.max_lives() == 4, "adding a class adds a life (lives=%d)" % game.run.lives)
	check(p.max_jumps == 2, "first class still applies at full lives")

	print("[16] coin abilities: shield")
	var pc: PlayerConfig = game.player_config
	pc.shield_duration = 1.0
	pc.shield_radius = 90.0
	var tcfg: TurretStats = game.defense_config.turret
	tcfg.projectile_speed = 400.0
	tcfg.fire_interval = 0.2
	game.load_level(1, false)
	await frames(30)
	p.invuln = 0.0
	var spawn: Vector2 = game.level.spawn.global_position
	game.run.wallet = 3
	check(not game.use_shield(), "shield refused with 3 coins (cost 5)")
	check(game.run.wallet == 3 and game.abilities.active_shields().is_empty(), "nothing spent when short")
	game.run.wallet = 12
	pad_button(JOY_BUTTON_Y, true)
	await frames(2)
	pad_button(JOY_BUTTON_Y, false)
	var shields: Array[ShieldBubble] = game.abilities.active_shields()
	check(game.run.wallet == 7 and shields.size() == 1, "gamepad Y creates a shield for 5 coins (wallet %d)" % game.run.wallet)
	pad_button(JOY_BUTTON_Y, true)
	await frames(2)
	pad_button(JOY_BUTTON_Y, false)
	check(game.run.wallet == 7 and game.abilities.active_shields().size() == 1, "cooldown prevents a double spend")
	var sh: ShieldBubble = shields[0]
	check(is_equal_approx(sh.radius, 90.0) and sh.global_position.distance_to(p.global_position) < 2.0, "shield at runner position with table radius")
	var blocked: Array[int] = [0]
	sh.blocked.connect(func(_at: Vector2) -> void: blocked[0] += 1)
	var lives_before: int = game.run.lives
	game.defense.budget = 5000
	check(game.defense.try_place(DefenseCatalog.Item.TURRET, spawn + Vector2(360, 0), 4), "turret aimed at the runner")
	await frames(108)
	check(blocked[0] >= 1, "shield destroyed incoming shells (%d)" % blocked[0])
	check(game.run.lives == lives_before, "runner inside the shield unharmed")
	await frames(30)
	check(game.abilities.active_shields().is_empty(), "shield expires after table duration (1s)")
	p.invuln = 999.0

	print("[17] coin abilities: screen clear")
	game.defense.clear_all()
	var cam_view := Rect2(game.camera.top_left(), Palette.VIEW_SIZE)
	game.defense.try_place(DefenseCatalog.Item.TURRET, spawn + Vector2(300, -150), 0)
	game.defense.try_place(DefenseCatalog.Item.ROCKET, spawn + Vector2(500, -100), 0)
	game.defense.try_place(DefenseCatalog.Item.CALTROP, spawn + Vector2(250, -200), 0)
	game.defense.try_place(DefenseCatalog.Item.TURRET, Vector2(2200, 250), 0)
	var placed_units: Array[Node2D] = game.defense.targets(true, true, false)
	var far_turret: Node2D = null
	var near_turrets: Array[Node2D] = []
	var caltrop_node: Node2D = null
	for n: Node2D in placed_units:
		if n is Caltrop:
			caltrop_node = n
		elif cam_view.has_point(DefenseController.target_center(n)):
			near_turrets.append(n)
		elif DefenseController.target_center(n).x > 2000.0:
			far_turret = n
	check(near_turrets.size() >= 2 and far_turret != null and caltrop_node != null, "setup: on-screen turrets, off-screen turret, caltrop")
	await frames(30)
	game.run.wallet = 14
	check(not game.use_screen_clear(), "screen clear refused with 14 coins (cost 15)")
	game.run.wallet = 20
	pad_button(JOY_BUTTON_B, true)
	await frames(2)
	pad_button(JOY_BUTTON_B, false)
	check(game.run.wallet == 5, "gamepad B spends 15 coins (wallet %d)" % game.run.wallet)
	await frames(90)
	var survivors: int = 0
	for n: Node2D in near_turrets:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			survivors += 1
	check(survivors == 0, "all on-screen turrets / rocket launchers destroyed")
	var bullets_in_view: int = 0
	for b: Bullet in game.defense.live_bullets():
		if cam_view.has_point(b.global_position):
			bullets_in_view += 1
	check(bullets_in_view == 0, "no projectiles left on screen")
	check(is_instance_valid(far_turret) and not far_turret.is_queued_for_deletion(), "off-screen turret untouched")
	check(is_instance_valid(caltrop_node) and not caltrop_node.is_queued_for_deletion(), "caltrops kept (table option off)")

	print("[18] leaderboard ranking")
	var lb_path: String = "user://test_leaderboard_unit.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lb_path))
	var lb := Leaderboard.new(lb_path)
	check(lb.submit("x", 5, 30.0) == 1, "first entry rank 1")
	check(lb.submit("x", 9, 50.0) == 1, "more coins ranks first")
	check(lb.submit("x", 5, 20.0) == 2, "equal coins: faster time ranks higher")
	check(lb.submit("x", 1, 10.0) == 4, "fewest coins ranks last")
	var lb2 := Leaderboard.new(lb_path)
	var tops: Array[Leaderboard.Entry] = lb2.top("x", 3)
	check(tops.size() == 3 and tops[0].coins == 9 and tops[1].coins == 5 and is_equal_approx(tops[1].time, 20.0), "persisted and sorted (reloaded)")
	check(lb2.format_board("x", 5, 2).contains("▶"), "current entry highlighted")

	print("[19] upgrades: shop upgrade button + sine path")
	game.defense.clear_all()
	p.invuln = 999.0
	var sp: Vector2 = game.level.spawn.global_position
	var gun: TurretStats = game.defense_config.turret
	gun.projectile_speed = 300.0
	gun.sine_amplitude = 30.0
	gun.sine_wavelength = 120.0
	gun.fire_interval = 10.0
	gun.first_shot_delay = 0.5
	gun.projectile_lifetime = 3.0
	gun.price = 200
	gun.upgrade_cost = 50
	gun.upgraded_price = 300
	game.shop.set_config(game.defense_config)
	game.shop.update_upgrades(game.defense)
	var fired: Array[Bullet] = []
	game.defense.child_entered_tree.connect(func(n: Node) -> void:
		if n is Bullet:
			fired.append(n as Bullet))
	var T_ITEM: DefenseCatalog.Item = DefenseCatalog.Item.TURRET
	var up_btn: Button = game.shop._up_buttons[T_ITEM]
	check(up_btn != null and up_btn.text == "升级 50" and not game.defense.is_item_upgraded(T_ITEM), "upgrade button under the turret icon (cost 50)")
	game.defense.budget = 1000
	var old_at := Vector2(sp.x + 100, 60)
	game.defense.try_place(T_ITEM, old_at, 0)
	check(int(game.defense.budget) == 800, "base price 200 before upgrading")
	var old_t: Turret = null
	for n: Node2D in game.defense.targets(true, false, false):
		old_t = n as Turret
	game.defense.budget = 30
	up_btn.pressed.emit()
	check(not game.defense.is_item_upgraded(T_ITEM), "upgrade refused when funds < upgrade cost")
	game.defense.budget = 1000
	up_btn.pressed.emit()
	check(game.defense.is_item_upgraded(T_ITEM) and int(game.defense.budget) == 950, "upgrade button charges the one-time cost (budget %d)" % int(game.defense.budget))
	check(up_btn.disabled and up_btn.text == "已升级", "button shows 已升级 and is disabled")
	var name_text: String = game.shop._names[T_ITEM].text
	check(name_text.contains("（升级）") and name_text.contains("300"), "card shows the upgraded price (%s)" % name_text)
	check(game.shop._descs[T_ITEM].text.contains("升级效果"), "card lists the upgrade effect")
	up_btn.pressed.emit()
	check(int(game.defense.budget) == 950, "pressing again does nothing")
	check(old_t != null and not old_t.upgraded, "already-placed turret stays at base level")
	var gun_at := Vector2(sp.x + 100, 110)
	check(game.defense.try_place(T_ITEM, gun_at, 0), "upgraded turret placed")
	check(int(game.defense.budget) == 650, "charged upgraded price 300 (budget %d)" % int(game.defense.budget))
	var gun_t: Turret = null
	for n: Node2D in game.defense.targets(true, false, false):
		if n != old_t:
			gun_t = n as Turret
	check(gun_t != null and gun_t.upgraded, "new placements are the upgraded version")
	old_t.queue_free()
	var n_before: int = fired.size()
	await frames(64)
	check(fired.size() == n_before + 1, "upgraded turret fired one shell")
	if fired.size() > n_before:
		var shell: Bullet = fired[fired.size() - 1]
		var line_y: float = gun_t.center_global().y
		var dev: float = 0.0
		var crossings: int = 0
		var prev_side: float = 0.0
		var prev_x: float = shell.global_position.x
		var x_monotonic: bool = true
		for i: int in 96:
			await frames(1)
			if not is_instance_valid(shell):
				break
			var dy: float = shell.global_position.y - line_y
			dev = maxf(dev, absf(dy))
			var side: float = signf(dy)
			if side != 0.0 and prev_side != 0.0 and side != prev_side:
				crossings += 1
			if side != 0.0:
				prev_side = side
			if shell.global_position.x < prev_x:
				x_monotonic = false
			prev_x = shell.global_position.x
		check(dev > 27.0 and dev < 31.0, "sine amplitude from table (max offset %.1f, want 30)" % dev)
		check(crossings >= 3, "shell snakes along a sine curve (%d centre crossings in 240px)" % crossings)
		check(x_monotonic, "shell still advances along its fire direction")

	print("[20] upgrades: rocket death burst")
	game.defense.clear_all()
	var rk: TurretStats = game.defense_config.rocket
	rk.arm_time = 0.0
	rk.first_shot_delay = 0.1
	rk.fire_interval = 10.0
	rk.projectile_lifetime = 0.4
	rk.split_count_min = 8
	rk.split_count_max = 10
	rk.split_speed = 200.0
	rk.split_lifetime = 1.0
	game.defense.budget = 1000
	game.shop._up_buttons[DefenseCatalog.Item.ROCKET].pressed.emit()
	check(game.defense.is_item_upgraded(DefenseCatalog.Item.ROCKET) and int(game.defense.budget) == 1000, "rocket upgraded (free by default)")
	var rk_at := Vector2(sp.x + 420, 110)
	game.defense.try_place(DefenseCatalog.Item.ROCKET, rk_at, 0)
	check(int(game.defense.budget) == 550, "upgraded rocket costs its upgraded price 450")
	var frag_mark: int = fired.size()
	await frames(80)
	var frags: Array[Bullet] = []
	for i: int in range(frag_mark, fired.size()):
		if is_instance_valid(fired[i]) and fired[i].style == Bullet.Style.FRAGMENT:
			frags.append(fired[i])
	check(frags.size() >= 8 and frags.size() <= 10, "missile burst into 8-10 fragments (%d)" % frags.size())
	var dir_sum := Vector2.ZERO
	var speed_ok: bool = frags.size() > 0
	for f: Bullet in frags:
		dir_sum += f.velocity.normalized()
		speed_ok = speed_ok and absf(f.velocity.length() - 200.0) < 0.5
	check(frags.size() > 0 and dir_sum.length() < 0.05, "fragments evenly spread in a circle (|sum|=%.3f)" % dir_sum.length())
	check(speed_ok, "fragment speed from table (200)")
	check(not frags.is_empty() and not frags[0].burst_on_death, "fragments never burst again")
	# Removal by shield / screen clear / sweep must not trigger the burst.
	rk.projectile_lifetime = 5.0
	game.defense.clear_all()
	game.defense.budget = 1000
	game.defense.try_place(DefenseCatalog.Item.ROCKET, rk_at, 0)
	await frames(20)
	var missile: Bullet = null
	for b: Bullet in game.defense.live_bullets():
		if b.style == Bullet.Style.ROCKET:
			missile = b
	check(missile != null and missile.burst_on_death, "upgraded missile in flight")
	var mark2: int = fired.size()
	if missile:
		game.defense.destroy_node(missile)
	await frames(10)
	check(fired.size() == mark2, "destroyed missile (shield / clear) does not burst")

	print("[21] upgrades: caltrop spike pulse")
	game.defense.clear_all()
	var ks: CaltropStats = game.defense_config.caltrop
	ks.arm_time = 0.0
	ks.pulse_interval = 0.6
	ks.pulse_duration = 0.5
	ks.pulse_scale = 2.0
	ks.pulse_warning = 0.2
	# The runner is meant to be hit here; keep the bomb-squad death blast from destroying the caltrop.
	game.player_config.bomb_radius = 0.0
	await settle_player(sp)
	game.defense.budget = 1000
	game.shop._up_buttons[DefenseCatalog.Item.CALTROP].pressed.emit()
	game.defense.try_place(DefenseCatalog.Item.CALTROP, sp + Vector2(160, -80), 0)
	check(int(game.defense.budget) == 820, "upgraded caltrop costs its upgraded price 180")
	await frames(90)
	var kt := game.defense.targets(false, true, false)[0] as Caltrop
	check(kt.landed and kt.upgraded, "caltrop placed after the upgrade is upgraded")
	kt.upgraded = true  # restart the pulse cycle so the timing below is deterministic
	var kc: Vector2 = DefenseController.target_center(kt)
	var base_rect: Rect2 = kt.hit_rect()
	# Runner stands just outside the normal hitbox but inside the enlarged one.
	p.global_position = Vector2(kc.x + 13.0 + 14.0 + 6.0, kt.global_position.y + DefenseCatalog.CALTROP_SIZE.y - Player.BODY.y * 0.5 - 1.0)
	p.velocity = Vector2.ZERO
	p.invuln = 0.0
	var lives0: int = game.run.lives
	var max_scale: float = 1.0
	var warned: bool = false
	var hit_frame: int = -1
	for i: int in 170:
		await frames(1)
		max_scale = maxf(max_scale, kt.current_scale())
		warned = warned or kt.is_warning()
		if hit_frame < 0 and game.run.lives < lives0:
			hit_frame = i
			p.invuln = 999.0
		if i == 60:
			check(game.run.lives == lives0, "runner beside a normal-size caltrop is safe")
	check(warned, "warning shake before the burst")
	check(is_equal_approx(max_scale, 2.0), "spikes burst to table scale (max %.2f)" % max_scale)
	check(hit_frame >= 70 and hit_frame <= 80, "enlarged spikes hit the runner at the burst (frame %d, burst at 72)" % hit_frame)
	check(kt.current_scale() < 1.05, "spikes back to normal after 0.5s")
	check(kt.hit_rect().size.is_equal_approx(base_rect.size), "hitbox restored")
	var sizes := PackedFloat32Array()
	for i: int in 180:
		await frames(1)
		sizes.append(kt.current_scale())
	var pulses: int = 0
	for i: int in range(1, sizes.size()):
		if sizes[i] > 1.5 and sizes[i - 1] <= 1.5:
			pulses += 1
	check(pulses >= 1 and pulses <= 2, "pulses repeat every interval+duration (%d in 1.5s)" % pulses)

	print("[22] upgrades reset with a new run")
	game.load_level(1, false)
	await frames(5)
	var any_up: bool = false
	for it: DefenseCatalog.Item in DefenseCatalog.shop_items():
		any_up = any_up or game.defense.is_item_upgraded(it)
	check(not any_up, "new run: every item back to base level")
	check(not game.shop._up_buttons[T_ITEM].disabled and game.shop._up_buttons[T_ITEM].text.begins_with("升级"), "shop upgrade buttons re-enabled")
	check(not game.shop._names[T_ITEM].text.contains("（升级）"), "card back to base price")

	print("RESULT: %d/%d passed" % [_checks - _failures, _checks])
	quit(_failures)
