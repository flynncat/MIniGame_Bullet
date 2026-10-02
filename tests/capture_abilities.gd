## Visual capture (needs a real renderer, not --headless):
##   godot --path . --script res://tests/capture_abilities.gd
## Saves screenshots of the shield, the screen clear and the level-clear sweep to build/.
extends SceneTree

var game: Game

func _initialize() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Game
	game.settings_path = "user://capture_settings.cfg"
	game.leaderboard_path = "user://capture_leaderboard.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.leaderboard_path))
	var lb := Leaderboard.new(game.leaderboard_path)
	var board: String = (game.level_scenes[1] as PackedScene).resource_path
	lb.submit(board, 11, 41.2)
	lb.submit(board, 7, 33.8)
	lb.submit(board, 3, 25.0)
	root.add_child(game)
	_run.call_deferred()

func frames(n: int) -> void:
	for i: int in n:
		await process_frame

func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://build/" + file))
	print("saved ", file)

func _run() -> void:
	await frames(10)
	game.defense_config.turret.arm_time = 0.0
	game.defense_config.rocket.arm_time = 0.0
	game.defense_config.turret.fire_interval = 0.5
	game.start_at_level(1)
	await frames(30)
	var p: Player = game.player
	var spawn: Vector2 = game.level.spawn.global_position
	game.defense.budget = 99999
	game.defense.try_place(DefenseCatalog.Item.TURRET, spawn + Vector2(330, -10), 4)
	game.defense.try_place(DefenseCatalog.Item.TURRET, spawn + Vector2(260, -220), 3)
	game.defense.try_place(DefenseCatalog.Item.ROCKET, spawn + Vector2(520, -160), 0)
	game.defense.try_place(DefenseCatalog.Item.CALTROP, spawn + Vector2(180, -200), 0)
	game.run.wallet = 40
	await frames(40)
	game.use_shield()
	await frames(50)
	await shot("ab_01_shield.png")
	await frames(40)
	game.use_screen_clear()
	await frames(9)
	await shot("ab_02_screen_clear.png")
	await frames(60)

	# Level-clear sweep: fill the level with defenses, then touch the flag.
	var goal: Vector2 = game.level.goal.global_position
	for i: int in 6:
		game.defense.try_place(DefenseCatalog.Item.TURRET if i % 2 == 0 else DefenseCatalog.Item.ROCKET, goal + Vector2(-620 + i * 150, -120 - (i % 3) * 70), i % 8)
	for i: int in 4:
		game.defense.try_place(DefenseCatalog.Item.CALTROP, goal + Vector2(-500 + i * 140, -260), 0)
	p.invuln = 999.0
	p.global_position = goal + Vector2(-260, 0)
	await frames(60)
	p.global_position = goal + Vector2(23, 43)
	await frames(24)
	await shot("ab_03_sweep_early.png")
	await frames(36)
	await shot("ab_04_sweep_mid.png")
	await frames(110)
	await shot("ab_05_clear_leaderboard.png")
	quit()
