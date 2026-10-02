## Static facade for the "Sfx" autoload. Gameplay scripts call [code]Audio.play(&"coin")[/code]
## instead of referencing the autoload directly, so they also compile and run in contexts
## where autoloads are absent (headless tool scripts, isolated scene tests with F6).
class_name Audio
extends RefCounted

static func play(id: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var sfx := tree.root.get_node_or_null(^"Sfx") as SfxPlayer
	if sfx:
		sfx.play(id)
