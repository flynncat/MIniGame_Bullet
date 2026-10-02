## Full-screen modal used for title / pause / level clear / game over / victory screens.
class_name Overlay
extends Control

signal confirmed

var _title: Label
var _body: RichTextLabel
var _button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.05, 0.094, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 18)
	center.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 44)
	_title.add_theme_font_override(&"font", DrawUtil.bold())
	col.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(900, 0)
	_body.add_theme_font_size_override(&"normal_font_size", 19)
	_body.add_theme_font_size_override(&"bold_font_size", 19)
	_body.add_theme_font_override(&"bold_font", DrawUtil.bold())
	_body.add_theme_color_override(&"default_color", Color("#a9b6d0"))
	_body.add_theme_constant_override(&"line_separation", 12)
	col.add_child(_body)
	var btn_row := CenterContainer.new()
	col.add_child(btn_row)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(220, 56)
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override(&"font_size", 20)
	_button.add_theme_color_override(&"font_color", Color("#101828"))
	_button.add_theme_color_override(&"font_hover_color", Color("#101828"))
	_button.add_theme_color_override(&"font_pressed_color", Color("#101828"))
	_button.add_theme_stylebox_override(&"normal", _pill(Color("#ffc94d")))
	_button.add_theme_stylebox_override(&"hover", _pill(Color("#ffd97a")))
	_button.add_theme_stylebox_override(&"pressed", _pill(Color("#f0b53a")))
	_button.pressed.connect(func() -> void: confirmed.emit())
	btn_row.add_child(_button)

## [param body_bbcode] may use [b]...[/b]; bold text is tinted gold automatically.
func show_screen(title: String, body_bbcode: String, button_text: String) -> void:
	_title.text = title
	_body.text = "[center]" + body_bbcode.replace("[b]", "[color=#ffd76a][b]").replace("[/b]", "[/b][/color]") + "[/center]"
	_button.text = button_text
	visible = true

func hide_screen() -> void:
	visible = false

static func _pill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(10)
	return sb
