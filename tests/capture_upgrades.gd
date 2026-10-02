## Visual capture of the item upgrades (needs a real renderer, not --headless):
##   godot --path . --fixed-fps 60 --script res://tests/capture_upgrades.gd
## Saves build/up_01_sine.png, up_02_burst.png, up_03_caltrop_pulse.png.
extends SceneTree

var game: Game

func _initialize() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Game
	game.settings_path = "user://capture_settings.cfg"
	game.leaderboard_path = "user://capture_leaderboard.cfg"
	root.add_child(game)
	_run.call_deferred()

func frames(n: int) -> void:
	for i: int in n:
		await process_frame

func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/" + file))
	print("saved ", file)

func _run() -> void:
	await frames(10)
	# In-memory tweaks for the capture only (the .tres files are not saved).
	var cfg: DefenseConfig = game.defense_config
	cfg.turret.arm_time = 0.0
	cfg.turret.first_shot_delay = 0.0
	cfg.turret.fire_interval = 0.35
	cfg.rocket.arm_time = 0.0
	cfg.rocket.first_shot_delay = 0.2
	cfg.rocket.fire_interval = 1.2
	cfg.rocket.projectile_lifetime = 1.1
	cfg.caltrop.arm_time = 0.0
	cfg.caltrop.pulse_interval = 1.0
	game.start_at_level(1)
	await frames(20)
	var p: Player = game.player
	p.invuln = 1.0e6
	var sp: Vector2 = game.level.spawn.global_position
	game.defense.budget = 99999

	# 1) Base turret first, then upgrade via the shop button: later placements are upgraded.
	var plain_at := sp + Vector2(40, -150)
	game.defense.try_place(DefenseCatalog.Item.TURRET, plain_at, 0)
	game.shop._up_buttons[DefenseCatalog.Item.TURRET].pressed.emit()
	var gun_at := sp + Vector2(40, -260)
	game.defense.try_place(DefenseCatalog.Item.TURRET, gun_at, 0)
	await frames(100)
	await shot("up_01_sine.png")

	# 2) Upgraded rocket launcher: missile bursts into fragments when it dies.
	game.defense.clear_all()
	game.shop._up_buttons[DefenseCatalog.Item.ROCKET].pressed.emit()
	var rk_at := sp + Vector2(380, -250)
	game.defense.try_place(DefenseCatalog.Item.ROCKET, rk_at, 0)
	# Keep the missile in the open sky: park the runner high up so it homes upward.
	p.global_position = sp + Vector2(380, -420)
	for i: int in 240:
		await frames(1)
		p.global_position = sp + Vector2(380, -420)
		p.velocity = Vector2.ZERO
		var burst: bool = false
		for b: Bullet in game.defense.live_bullets():
			burst = burst or b.style == Bullet.Style.FRAGMENT
		if burst:
			break
	await frames(9)
	await shot("up_02_burst.png")
	p.global_position = sp

	# 3) Upgraded caltrops: spikes burst larger.
	game.defense.clear_all()
	game.shop._up_buttons[DefenseCatalog.Item.CALTROP].pressed.emit()
	for i: int in 3:
		game.defense.try_place(DefenseCatalog.Item.CALTROP, sp + Vector2(120 + i * 70, -60), 0)
	await frames(50)
	for k: Node2D in game.defense.targets(false, true, false):
		(k as Caltrop).upgraded = true  # sync the pulse cycles for the screenshot
	# Burst starts 1.0 s after the cycle restart; capture mid-burst.
	await frames(66)
	await shot("up_03_caltrop_pulse.png")
	quit()
