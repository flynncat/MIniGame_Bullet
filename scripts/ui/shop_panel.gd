## Right-side defender panel (player 2). Builds its item cards from the DefenseConfig table.
## Pure view: emits intent signals, receives state through the update_* methods.
class_name ShopPanel
extends PanelContainer

signal item_pressed(item: DefenseCatalog.Item)
signal clear_pressed
## The "升级" button under an item icon was pressed.
signal upgrade_pressed(item: DefenseCatalog.Item)

const TIP_DRAG: String = "按住拖动决定开火方向，松开放置 · 右键 / ESC 取消"

var _balance: Label
var _col: VBoxContainer
var _keys: Label
var _config: DefenseConfig = DefenseConfig.new()
var _tip_idle: String = ""
var _tip: Label
var _cards: Dictionary[DefenseCatalog.Item, Button] = {}
var _names: Dictionary[DefenseCatalog.Item, Label] = {}
var _descs: Dictionary[DefenseCatalog.Item, Label] = {}
var _icons: Dictionary[DefenseCatalog.Item, ItemIcon] = {}
var _up_buttons: Dictionary[DefenseCatalog.Item, Button] = {}
## Item types currently upgraded (mirrors DefenseController, pushed via update_upgrades).
var _upgraded: Dictionary[DefenseCatalog.Item, bool] = {}
var _budget: int = 0
var _selected: DefenseCatalog.Item = DefenseCatalog.Item.NONE
var _tip_timer: SceneTreeTimer

func _ready() -> void:
	custom_minimum_size.x = 304
	add_theme_stylebox_override(&"panel", _box(Color("#161d31"), Color(1, 1, 1, 0.07), 12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	add_child(col)
	_col = col

	var title := Label.new()
	title.text = "防御系统"
	title.add_theme_font_size_override(&"font_size", 20)
	col.add_child(title)
	var tag := Label.new()
	tag.text = "玩家 2 · 鼠标操控"
	tag.add_theme_color_override(&"font_color", Color("#7fd4ff"))
	tag.add_theme_font_size_override(&"font_size", 13)
	col.add_child(tag)
	_balance = Label.new()
	_balance.add_theme_color_override(&"font_color", Color("#ffd76a"))
	_balance.add_theme_font_size_override(&"font_size", 18)
	col.add_child(_balance)

	var clear := Button.new()
	clear.text = "清空防御（不返还资金）"
	clear.focus_mode = Control.FOCUS_NONE
	clear.pressed.connect(func() -> void: clear_pressed.emit())
	col.add_child(clear)

	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_tip.add_theme_color_override(&"font_color", Color("#8b98b6"))
	_tip.add_theme_font_size_override(&"font_size", 13)
	_tip.custom_minimum_size = Vector2(270, 90)
	col.add_child(_tip)

	var keys := Label.new()
	_keys = keys
	keys.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	keys.add_theme_color_override(&"font_color", Color("#7f8ca8"))
	keys.add_theme_font_size_override(&"font_size", 12)
	keys.text = "玩家 1 手柄：左摇杆/十字键 移动 · A 跳跃（空中可多段跳）· X/RB/RT 冲刺 · 下 穿过木板 · Y 护盾 · B 清屏 · Back 回出生点 · Start 暂停 · A/Start 确认\n玩家 1 键盘：←/→ 或 A/D 移动 · 空格/W/↑ 跳跃 · Shift 冲刺 · ↓/S 穿过木板 · Q 护盾 · E 清屏 · R 回出生点 · P 暂停 · Enter 确认"
	col.add_child(keys)
	set_config(_config)

## (Re)builds the item cards and tips from the config table.
func set_config(config: DefenseConfig) -> void:
	_config = config
	for b: Button in _cards.values():
		b.queue_free()
	_cards.clear()
	_names.clear()
	_descs.clear()
	_icons.clear()
	_up_buttons.clear()
	var at: int = _keys.get_index()
	for it: DefenseCatalog.Item in DefenseCatalog.shop_items():
		var card: Button = _make_card(it)
		_col.add_child(card)
		_col.move_child(card, at)
		at += 1
	_tip_idle = "在右侧面板选道具 → 在游戏画面按住拖动决定方向 → 松手安放 · 放置后充能生效（圆环倒计时）· 跑者吃金币会给你 +%d 资金" % _config.coin_bonus
	_tip.text = _tip_idle
	update_budget(_budget)

func _make_card(it: DefenseCatalog.Item) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(270, 138)
	b.add_theme_stylebox_override(&"normal", _box(Color("#1b2339"), Color(1, 1, 1, 0.08), 12))
	b.add_theme_stylebox_override(&"hover", _box(Color("#1e2740"), Color(1, 1, 1, 0.16), 12))
	b.add_theme_stylebox_override(&"pressed", _box(Color("#2a3350"), Color("#ffbe3d"), 12))
	b.add_theme_stylebox_override(&"hover_pressed", _box(Color("#2a3350"), Color("#ffbe3d"), 12))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	b.add_child(row)
	# Icon with the "升级" button underneath.
	var icon_col := VBoxContainer.new()
	icon_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_col.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_col.add_theme_constant_override(&"separation", 6)
	row.add_child(icon_col)
	var icon := ItemIcon.new()
	icon.item = it
	icon_col.add_child(icon)
	_icons[it] = icon
	var up := Button.new()
	up.focus_mode = Control.FOCUS_NONE
	up.custom_minimum_size = Vector2(52, 24)
	up.mouse_filter = Control.MOUSE_FILTER_STOP
	up.add_theme_font_size_override(&"font_size", 12)
	up.add_theme_color_override(&"font_color", Color("#1a1400"))
	up.add_theme_color_override(&"font_hover_color", Color("#1a1400"))
	up.add_theme_color_override(&"font_pressed_color", Color("#1a1400"))
	up.add_theme_color_override(&"font_disabled_color", Color("#ffd76a"))
	up.add_theme_stylebox_override(&"normal", _pill(Color("#ffc94d")))
	up.add_theme_stylebox_override(&"hover", _pill(Color("#ffdb80")))
	up.add_theme_stylebox_override(&"pressed", _pill(Color("#e8ae2e")))
	up.add_theme_stylebox_override(&"disabled", _pill(Color(1, 0.84, 0.42, 0.14)))
	up.pressed.connect(func() -> void: upgrade_pressed.emit(it))
	icon_col.add_child(up)
	_up_buttons[it] = up
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)
	var name_l := Label.new()
	name_l.add_theme_font_size_override(&"font_size", 15)
	text_col.add_child(name_l)
	_names[it] = name_l
	var desc := Label.new()
	_descs[it] = desc
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 190
	desc.add_theme_font_size_override(&"font_size", 11)
	desc.add_theme_color_override(&"font_color", Color("#8b98b6"))
	text_col.add_child(desc)
	b.pressed.connect(func() -> void: item_pressed.emit(it))
	_cards[it] = b
	_refresh_card_text(it)
	return b

## Mirrors the controller's upgraded item types and refreshes prices / texts / buttons.
func update_upgrades(defense: DefenseController) -> void:
	for it: DefenseCatalog.Item in DefenseCatalog.shop_items():
		_upgraded[it] = defense.is_item_upgraded(it)
		if _cards.has(it):
			_refresh_card_text(it)
	_refresh_cards()

func is_upgraded(it: DefenseCatalog.Item) -> bool:
	return _upgraded.get(it, false)

## Current placement price shown on the card.
func price_of(it: DefenseCatalog.Item) -> int:
	return _config.upgraded_price(it) if is_upgraded(it) else _config.price(it)

func _refresh_card_text(it: DefenseCatalog.Item) -> void:
	var up: bool = is_upgraded(it)
	_names[it].text = "%s%s    %d" % [_config.display_name(it), "（升级）" if up else "", price_of(it)]
	_names[it].add_theme_color_override(&"font_color", Color("#ffd76a") if up else Color("#e8eefc"))
	_descs[it].text = _card_description(it)
	_icons[it].upgraded = up
	var btn: Button = _up_buttons[it]
	var cost: int = _config.upgrade_cost(it)
	btn.disabled = up
	btn.text = "已升级" if up else ("升级" if cost <= 0 else "升级 %d" % cost)
	btn.tooltip_text = "" if up else "升级后：%s\n之后每次放置 %d（已放置的不变）" % [_config.upgrade_summary(it), _config.upgraded_price(it)]

func update_budget(budget: int) -> void:
	_budget = budget
	_balance.text = "资金 %d（+%d/s）" % [budget, int(_config.income_per_sec)]
	_refresh_cards()

func update_selection(item: DefenseCatalog.Item) -> void:
	_selected = item
	_tip.remove_theme_color_override(&"font_color")
	_tip.add_theme_color_override(&"font_color", Color("#8b98b6"))
	_tip.text = TIP_DRAG if item != DefenseCatalog.Item.NONE else _tip_idle
	_refresh_cards()

## Shows a highlighted message for 1.5 s, then restores the default tip.
func flash(text: String) -> void:
	_tip.text = text
	_tip.add_theme_color_override(&"font_color", Color("#ff9f43"))
	_tip_timer = get_tree().create_timer(1.5, true)
	var my_timer: SceneTreeTimer = _tip_timer
	my_timer.timeout.connect(func() -> void:
		if my_timer == _tip_timer:
			update_selection(_selected))

func _refresh_cards() -> void:
	for it: DefenseCatalog.Item in _cards:
		var b: Button = _cards[it]
		b.set_pressed_no_signal(it == _selected)
		b.modulate.a = 0.48 if _budget < price_of(it) else 1.0
		if _up_buttons.has(it) and not is_upgraded(it):
			_up_buttons[it].disabled = _budget < _config.upgrade_cost(it)

## Card text = designer description (if any) + live numbers from the table.
func _card_description(it: DefenseCatalog.Item) -> String:
	var custom: String = _config.description(it).strip_edges()
	var nums: String
	if it == DefenseCatalog.Item.CALTROP:
		nums = "充能 %ss" % DefenseController._fmt_s(_config.caltrop_stats().arm_time)
	else:
		var t: TurretStats = _config.turret_stats(Turret.Kind.ROCKET if it == DefenseCatalog.Item.ROCKET else Turret.Kind.GUN)
		nums = "每 %ss 一发 · 弹速 %d%s · 充能 %ss" % [DefenseController._fmt_s(t.fire_interval), int(t.projectile_speed), " · 追踪" if t.homing else "", DefenseController._fmt_s(t.arm_time)]
	if is_upgraded(it):
		nums += "\n升级效果：" + _config.upgrade_summary(it)
	return nums if custom.is_empty() else "%s\n%s" % [custom, nums]

static func _pill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(2)
	return sb

static func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb
