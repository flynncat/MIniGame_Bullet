## Modal settings dialog: manual level select + "continue from the level of death" option.
## Pure view: emits intent signals; Game owns the actual state and persistence.
class_name SettingsDialog
extends Control

## Player picked a level (0-based index into Game.level_scenes).
signal level_chosen(index: int)
## "Continue from the level of death after Game Over" toggled.
signal continue_mode_toggled(enabled: bool)
## Dialog was closed via × / Esc / clicking the dimmed backdrop.
signal closed

var _level_list: VBoxContainer
var _continue_check: CheckButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_backdrop_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override(&"panel", _box(Color("#161d31"), Color(1, 1, 1, 0.14), 16, 22))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 14)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_font_override(&"font", DrawUtil.bold())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "×"
	close.tooltip_text = "关闭（Esc）"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(40, 40)
	close.add_theme_font_size_override(&"font_size", 26)
	close.add_theme_stylebox_override(&"normal", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 20, 0))
	close.add_theme_stylebox_override(&"hover", _box(Color("#8b3a52"), Color(0, 0, 0, 0), 20, 0))
	close.add_theme_stylebox_override(&"pressed", _box(Color("#63283a"), Color(0, 0, 0, 0), 20, 0))
	close.pressed.connect(close_dialog)
	header.add_child(close)

	col.add_child(_section("选择关卡"))
	var level_hint := _hint("点击关卡立即开始该关（生命、得分、防御资金重置）")
	col.add_child(level_hint)
	_level_list = VBoxContainer.new()
	_level_list.add_theme_constant_override(&"separation", 8)
	col.add_child(_level_list)

	col.add_child(HSeparator.new())
	col.add_child(_section("游戏结束后"))
	_continue_check = CheckButton.new()
	_continue_check.name = "ContinueCheck"
	_continue_check.text = "从死亡关卡继续游玩"
	_continue_check.focus_mode = Control.FOCUS_NONE
	_continue_check.add_theme_font_size_override(&"font_size", 17)
	_continue_check.toggled.connect(func(on: bool) -> void: continue_mode_toggled.emit(on))
	col.add_child(_continue_check)
	col.add_child(_hint("开启：游戏结束后按钮变为「从本关继续」，在倒下的关卡重新开始（生命重置为 3）。\n关闭：回到第 1 关重新开始。设置会自动保存。"))

## Rebuilds the level list and shows the dialog.
func open(level_names: PackedStringArray, current_index: int, continue_enabled: bool) -> void:
	for child: Node in _level_list.get_children():
		child.queue_free()
	for i: int in level_names.size():
		var b := Button.new()
		b.name = "Level%d" % (i + 1)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override(&"font_size", 16)
		var is_current: bool = i == current_index
		b.text = "  %d.  %s%s" % [i + 1, level_names[i], "　（当前）" if is_current else ""]
		b.add_theme_stylebox_override(&"normal", _box(Color("#2a3350") if is_current else Color("#1e2740"), Color("#ffbe3d") if is_current else Color(1, 1, 1, 0.08), 10, 8))
		b.add_theme_stylebox_override(&"hover", _box(Color("#313d61"), Color("#ffd76a"), 10, 8))
		b.add_theme_stylebox_override(&"pressed", _box(Color("#3a4770"), Color("#ffd76a"), 10, 8))
		var index: int = i
		b.pressed.connect(func() -> void: level_chosen.emit(index))
		_level_list.add_child(b)
	_continue_check.set_pressed_no_signal(continue_enabled)
	visible = true

func close_dialog() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"cancel_place")):
		close_dialog()
		get_viewport().set_input_as_handled()

func _on_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		close_dialog()

static func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 18)
	l.add_theme_color_override(&"font_color", Color("#ffd76a"))
	return l

static func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.add_theme_font_size_override(&"font_size", 13)
	l.add_theme_color_override(&"font_color", Color("#8b98b6"))
	return l

static func _box(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.0 else 0)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb
