## One-shot project bootstrap, run headless from the project folder:
##   godot --headless --path . --script res://tools/bootstrap.gd -- settings
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/bootstrap.gd -- scenes [--force]
## "settings" writes project.godot (renderer, window, input map, layers, font, autoload).
## "configs" writes the tunable tables under res://config/ (skips existing files unless --force).
## "scenes" converts data/default_levels.json (the web version's levels) into editable
## level scenes and builds scenes/main.tscn. Existing level scenes are NOT overwritten
## unless --force is given, so edits made in the Godot editor are safe.
extends SceneTree

const VIEW_SIZE: Vector2 = Vector2(960, 1350)
const CONFIG_DEFENSE: String = "res://config/defense_config.tres"
const CONFIG_PLAYER: String = "res://config/player_config.tres"
const CONFIG_TURRET: String = "res://config/defense/turret.tres"
const CONFIG_ROCKET: String = "res://config/defense/rocket.tres"
const CONFIG_CALTROP: String = "res://config/defense/caltrop.tres"
const CONFIG_CLASSES: PackedStringArray = [
	"res://config/runner_classes/class_1_bomb.tres",
	"res://config/runner_classes/class_2_engineer.tres",
	"res://config/runner_classes/class_3_rocket.tres",
]

const LEVEL_FILES: PackedStringArray = [
	"res://scenes/levels/level_01_tower.tscn",
	"res://scenes/levels/level_02_sky_start.tscn",
	"res://scenes/levels/level_03_dusk.tscn",
	"res://scenes/levels/level_04_star_tower.tscn",
]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ok: bool = true
	if args.has("settings"):
		ok = _write_settings()
	elif args.has("configs"):
		ok = _build_configs(args.has("--force"))
	elif args.has("scenes"):
		ok = _build_scenes(args.has("--force"))
	else:
		push_error("bootstrap: pass 'settings' or 'scenes' after --")
		ok = false
	quit(0 if ok else 1)

# ---------------------------------------------------------------- settings

## Builds an input action. Keyboard = player 1 fallback; gamepad (any device) = player 1 primary.
## [param axes] entries are Vector2(axis, direction) with direction -1 or +1.
func _action(keys: Array[Key], buttons: Array[JoyButton] = [], axes: Array[Vector2] = [], deadzone: float = 0.2) -> Dictionary:
	var events: Array[InputEvent] = []
	for k: Key in keys:
		var ev := InputEventKey.new()
		ev.device = -1
		ev.physical_keycode = k
		events.append(ev)
	for b: JoyButton in buttons:
		var jb := InputEventJoypadButton.new()
		jb.device = -1
		jb.button_index = b
		events.append(jb)
	for a: Vector2 in axes:
		var jm := InputEventJoypadMotion.new()
		jm.device = -1
		jm.axis = int(a.x) as JoyAxis
		jm.axis_value = a.y
		events.append(jm)
	return {"deadzone": deadzone, "events": events}

func _write_settings() -> bool:
	var s: Dictionary[String, Variant] = {
		"application/config/name": "云端跳跃 · 双人对抗",
		"application/config/description": "Godot 4 port of the web platformer (runner vs defender).",
		"application/config/features": PackedStringArray(["4.7", "GL Compatibility"]),
		"application/run/main_scene": "res://scenes/main.tscn",
		"display/window/size/viewport_width": 1300,
		"display/window/size/viewport_height": 1374,
		"display/window/size/window_width_override": 900,
		"display/window/size/window_height_override": 951,
		"display/window/stretch/mode": "canvas_items",
		"display/window/stretch/aspect": "keep",
		"rendering/renderer/rendering_method": "gl_compatibility",
		"rendering/renderer/rendering_method.mobile": "gl_compatibility",
		"rendering/environment/defaults/default_clear_color": Color("#12182c"),
		"rendering/2d/snap/snap_2d_transforms_to_pixel": false,
		"physics/common/physics_ticks_per_second": 120,
		"physics/common/max_physics_steps_per_frame": 16,
		"gui/theme/custom_font": "res://assets/fonts/ui_font.ttf",
		"autoload/Sfx": "*res://scripts/core/sfx.gd",
		"layer_names/2d_physics/layer_1": "world_solid",
		"layer_names/2d_physics/layer_2": "world_oneway",
		"layer_names/2d_physics/layer_3": "player",
		"layer_names/2d_physics/layer_4": "world_moving",
		"layer_names/2d_physics/layer_5": "hazard",
		"layer_names/2d_physics/layer_6": "pickup",
		"debug/gdscript/warnings/untyped_declaration": 1,
		"input/move_left": _action([KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], [Vector2(JOY_AXIS_LEFT_X, -1)], 0.35),
		"input/move_right": _action([KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], [Vector2(JOY_AXIS_LEFT_X, 1)], 0.35),
		# Higher deadzone so a diagonal run on the stick does not drop through planks by accident.
		"input/move_down": _action([KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], [Vector2(JOY_AXIS_LEFT_Y, 1)], 0.6),
		"input/jump": _action([KEY_SPACE, KEY_W, KEY_UP], [JOY_BUTTON_A]),
		"input/dash": _action([KEY_SHIFT], [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER], [Vector2(JOY_AXIS_TRIGGER_RIGHT, 1)], 0.5),
		"input/restart": _action([KEY_R], [JOY_BUTTON_BACK]),
		"input/pause": _action([KEY_P], [JOY_BUTTON_START]),
		"input/cancel_place": _action([KEY_ESCAPE]),
		"input/shield": _action([KEY_Q], [JOY_BUTTON_Y]),
		"input/screen_clear": _action([KEY_E], [JOY_BUTTON_B]),
		"input/confirm": _action([KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_A, JOY_BUTTON_START]),
	}
	for key: String in s:
		ProjectSettings.set_setting(key, s[key])
	# The project was created with Forward+/D3D12 defaults; web export needs Compatibility only.
	ProjectSettings.set_setting("rendering/rendering_device/driver.windows", null)
	var err: Error = ProjectSettings.save()
	print("bootstrap: project settings saved -> ", error_string(err))
	return err == OK

# ---------------------------------------------------------------- scenes

func _own(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_own(child, owner_node)

func _save(root: Node, path: String) -> bool:
	_own(root, root)
	var packed := PackedScene.new()
	var err: Error = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("bootstrap: ", path, " -> ", error_string(err))
	root.free()
	return err == OK

func _scripted(type_node: Node, script_path: String, node_name: String) -> Node:
	type_node.set_script(load(script_path))
	type_node.name = node_name
	return type_node

func _build_level(data: Dictionary) -> Node:
	var root: Node2D = _scripted(Node2D.new(), "res://scripts/level/level.gd", "Level")
	root.set("level_name", String(data.get("name", "关卡")))
	root.set("world_size", Vector2i(int(data.get("width", 2000)), int(data.get("height", 540))))
	root.set("theme", int(data.get("theme", 0)))

	var spikes := Node2D.new()
	spikes.name = "Spikes"
	root.add_child(spikes)
	var i: int = 0
	for s: Dictionary in data.get("spikes", []):
		i += 1
		var sp: Node2D = _scripted(Area2D.new(), "res://scripts/level/spike.gd", "Spike%d" % i)
		sp.position = Vector2(float(s["x"]), float(s["y"]))
		sp.set("size", Vector2(float(s["w"]), float(s["h"])))
		spikes.add_child(sp)

	var goal: Node2D = _scripted(Area2D.new(), "res://scripts/level/goal.gd", "Goal")
	var g: Dictionary = data["goal"]
	goal.position = Vector2(float(g["x"]), float(g["y"]))
	root.add_child(goal)

	var coins := Node2D.new()
	coins.name = "Coins"
	root.add_child(coins)
	i = 0
	for c: Array in data.get("coins", []):
		i += 1
		var coin: Node2D = _scripted(Area2D.new(), "res://scripts/level/coin.gd", "Coin%d" % i)
		coin.position = Vector2(float(c[0]), float(c[1]))
		coins.add_child(coin)

	var plats := Node2D.new()
	plats.name = "Platforms"
	root.add_child(plats)
	i = 0
	for p: Dictionary in data.get("platforms", []):
		i += 1
		var kind: String = String(p.get("type", "solid"))
		var node: Node2D
		if kind == "moving":
			node = _scripted(AnimatableBody2D.new(), "res://scripts/level/moving_platform.gd", "Moving%d" % i)
			node.set("axis", 1 if String(p.get("ax", "x")) == "y" else 0)
			node.set("distance", float(p.get("dist", 120)))
			node.set("speed", float(p.get("speed", 60)))
		else:
			node = _scripted(StaticBody2D.new(), "res://scripts/level/platform.gd", "Platform%d" % i)
			node.set("kind", 1 if kind == "oneway" else 0)
		node.position = Vector2(float(p["x"]), float(p["y"]))
		node.set("size", Vector2(float(p["w"]), float(p["h"])))
		plats.add_child(node)

	var turrets := Node2D.new()
	turrets.name = "Turrets"
	root.add_child(turrets)
	i = 0
	for t: Dictionary in data.get("turrets", []):
		i += 1
		var tn: Node2D = _scripted(Node2D.new(), "res://scripts/defense/turret.gd", "Turret%d" % i)
		tn.position = Vector2(float(t["x"]), float(t["y"]))
		tn.set("direction", clampi(int(t.get("dir", 0)), 0, 7))
		var interval: float = float(t.get("interval", 1.8))
		var speed: float = float(t.get("speed", 280))
		if not is_equal_approx(interval, 1.8) or not is_equal_approx(speed, 280.0):
			# Non-default values from the web editor become a per-instance override table.
			var ov: Resource = load("res://scripts/config/turret_stats.gd").new()
			ov.set("fire_interval", interval)
			ov.set("projectile_speed", speed)
			ov.set("arm_time", 0.0)
			tn.set("stats_override", ov)
		turrets.add_child(tn)

	var spawn: Node2D = _scripted(Marker2D.new(), "res://scripts/level/spawn_point.gd", "Spawn")
	var sp_data: Dictionary = data["spawn"]
	spawn.position = Vector2(float(sp_data["x"]) + 14.0, float(sp_data["y"]) + 18.0)
	root.add_child(spawn)
	return root

func _unique(node: Node, node_name: String) -> Node:
	node.name = node_name
	node.unique_name_in_owner = true
	return node

func _build_main(levels: Array[PackedScene]) -> Node:
	var root: Control = _scripted(Control.new(), "res://scripts/game/game.gd", "Main")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.set("level_scenes", levels)
	root.set("defense_config", load(CONFIG_DEFENSE))
	root.set("player_config", load(CONFIG_PLAYER))

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color("#12182c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	root.add_child(margin)
	var layout := HBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override(&"separation", 12)
	margin.add_child(layout)

	var view := SubViewportContainer.new()
	view.name = "GameView"
	view.stretch = true
	view.custom_minimum_size = VIEW_SIZE
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	layout.add_child(view)
	var vp := SubViewport.new()
	vp.name = "GameViewport"
	vp.size = Vector2i(VIEW_SIZE)
	vp.handle_input_locally = true
	view.add_child(vp)

	var sky_layer := CanvasLayer.new()
	sky_layer.name = "SkyLayer"
	sky_layer.layer = -10
	vp.add_child(sky_layer)
	sky_layer.add_child(_unique(_scripted(Node2D.new(), "res://scripts/game/sky_backdrop.gd", "Sky"), "Sky"))

	var world := Node2D.new()
	world.name = "World"
	vp.add_child(world)
	world.add_child(_unique(Node2D.new(), "LevelSlot"))
	world.add_child(_unique(_scripted(Node2D.new(), "res://scripts/defense/defense_controller.gd", "Defense"), "Defense"))
	world.add_child(_unique(_scripted(Node2D.new(), "res://scripts/fx/fx_layer.gd", "Fx"), "Fx"))
	world.add_child(_unique(_scripted(CharacterBody2D.new(), "res://scripts/player/player.gd", "Player"), "Player"))
	world.add_child(_unique(_scripted(Node2D.new(), "res://scripts/defense/defense_placer.gd", "Placer"), "Placer"))
	world.add_child(_unique(_scripted(Camera2D.new(), "res://scripts/game/game_camera.gd", "Camera"), "Camera"))
	var fx: Node = world.get_node("Fx")
	world.get_node("Player").set("fx", fx)
	world.get_node("Defense").set("fx", fx)
	world.get_node("Defense").set("runner", world.get_node("Player"))

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 5
	vp.add_child(hud_layer)
	hud_layer.add_child(_unique(_scripted(Node2D.new(), "res://scripts/game/hud.gd", "Hud"), "Hud"))

	var shop: Control = _unique(_scripted(PanelContainer.new(), "res://scripts/ui/shop_panel.gd", "Shop"), "Shop")
	shop.custom_minimum_size = Vector2(304, 0)
	layout.add_child(shop)

	var overlay: Control = _unique(_scripted(Control.new(), "res://scripts/ui/overlay.gd", "Overlay"), "Overlay")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)

	# Top-right settings button sits above the overlay so it also works on title / game-over screens.
	var gear: Control = _unique(_scripted(Button.new(), "res://scripts/ui/settings_button.gd", "SettingsButton"), "SettingsButton")
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -70.0
	gear.offset_top = 22.0
	gear.offset_right = -26.0
	gear.offset_bottom = 66.0
	root.add_child(gear)

	var dialog: Control = _unique(_scripted(Control.new(), "res://scripts/ui/settings_dialog.gd", "Settings"), "Settings")
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.visible = false
	root.add_child(dialog)
	return root

# ---------------------------------------------------------------- config tables

func _res(script_path: String, values: Dictionary) -> Resource:
	var r: Resource = load(script_path).new()
	for k: String in values:
		r.set(k, values[k])
	return r

## Saves [param res] to [param path] unless it exists (and not forced); returns the resource on disk.
func _save_res(res: Resource, path: String, force: bool) -> Resource:
	if FileAccess.file_exists(path) and not force:
		print("bootstrap: keep existing ", path)
		return load(path)
	var err: Error = ResourceSaver.save(res, path)
	print("bootstrap: ", path, " -> ", error_string(err))
	res.take_over_path(path)
	return res

func _build_configs(force: bool) -> bool:
	DirAccess.make_dir_recursive_absolute("res://config/defense")
	DirAccess.make_dir_recursive_absolute("res://config/runner_classes")
	var ts: String = "res://scripts/config/turret_stats.gd"
	var turret: Resource = _save_res(_res(ts, {
		"display_name": "炮塔", "description": "朝安装时指定的方向发射炮弹，命中扣 1 点血", "price": 200,
		"arm_time": 3.0, "first_shot_delay": 0.3, "fire_interval": 1.8,
		"projectile_speed": 280.0, "projectile_lifetime": 5.0, "homing": false,
		"upgrade_cost": 0, "upgraded_price": 300, "upgrade_effects": 1}), CONFIG_TURRET, force)
	var rocket: Resource = _save_res(_res(ts, {
		"display_name": "火箭炮", "description": "发射自动追踪跑者的火箭弹，命中扣 1 点血", "price": 300,
		"arm_time": 3.0, "first_shot_delay": 0.3, "fire_interval": 2.6,
		"projectile_speed": 220.0, "projectile_lifetime": 6.0, "homing": true, "homing_turn_rate_deg": 149.0,
		"upgrade_cost": 0, "upgraded_price": 450, "upgrade_effects": 2}), CONFIG_ROCKET, force)
	var caltrop: Resource = _save_res(_res("res://scripts/config/caltrop_stats.gd", {
		"display_name": "铁刺", "description": "点哪投哪，落地下落吸附地形；跑者踩到掉 1 点血", "price": 120,
		"arm_time": 3.0, "fall_gravity": 900.0, "max_fall_speed": 1000.0, "knockback_speed": 360.0}), CONFIG_CALTROP, force)
	_save_res(_res("res://scripts/config/defense_config.gd", {
		"start_budget": 400, "income_per_sec": 20.0, "coin_bonus": 100,
		"turret": turret, "rocket": rocket, "caltrop": caltrop}), CONFIG_DEFENSE, force)

	var cs: String = "res://scripts/config/runner_class_config.gd"
	var class_defs: Array[Dictionary] = [
		{"display_name": "炸弹小队", "color": Color("#ff8c42"), "max_jumps": 2, "death_ability": 1, "description": "阵亡时引爆，摧毁周围防御单位"},
		{"display_name": "工程师", "color": Color("#6cf0a0"), "max_jumps": 2, "death_ability": 2, "description": "阵亡时生成一座左右巡逻平台"},
		{"display_name": "火箭兵", "color": Color("#7fd4ff"), "max_jumps": 3, "death_ability": 0, "description": "三段跳，机动性最强"},
	]
	var classes: Array[Resource] = []
	for i: int in class_defs.size():
		classes.append(_save_res(_res(cs, class_defs[i]), CONFIG_CLASSES[i], force))
	var pc: Resource = _res("res://scripts/config/player_config.gd", {})
	var typed_classes: Array = pc.get("classes")
	typed_classes.assign(classes)
	_save_res(pc, CONFIG_PLAYER, force)
	return true

func _build_scenes(force: bool) -> bool:
	var file := FileAccess.open("res://data/default_levels.json", FileAccess.READ)
	if file == null:
		push_error("bootstrap: data/default_levels.json missing")
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("bootstrap: invalid JSON")
		return false
	var levels_data: Array = (parsed as Dictionary)["levels"]
	var ok: bool = true
	DirAccess.make_dir_recursive_absolute("res://scenes/levels")
	# Test fixtures: pristine copies of the original levels, always regenerated, so
	# automated tests never depend on edits made to the real level scenes.
	DirAccess.make_dir_recursive_absolute("res://tests/fixtures")
	for i: int in levels_data.size():
		ok = _save(_build_level(levels_data[i]), "res://tests/fixtures/fixture_level_%02d.tscn" % (i + 1)) and ok
	for i: int in mini(levels_data.size(), LEVEL_FILES.size()):
		if FileAccess.file_exists(LEVEL_FILES[i]) and not force:
			print("bootstrap: keep existing ", LEVEL_FILES[i])
			continue
		ok = _save(_build_level(levels_data[i]), LEVEL_FILES[i]) and ok
	var packed: Array[PackedScene] = []
	for path: String in LEVEL_FILES:
		packed.append(load(path) as PackedScene)
	ok = _save(_build_main(packed), "res://scenes/main.tscn") and ok
	return ok
