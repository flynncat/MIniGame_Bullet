## In-game HUD drawn over the game view: score, defender budget, lives, dash meter,
## current runner class, timer, tower altitude bar, and the placement hint strip.
class_name Hud
extends Node2D

var run: RunState
var player: Player
var defense: DefenseController
var placer: DefensePlacer
var world_height: float = 540.0

const TOAST_TIME: float = 1.8

var _toast_text: String = ""
var _toast_color: Color = Color.WHITE
var _toast_t: float = 0.0
var _banner_title: String = ""
var _banner_sub: String = ""
var _banner_t: float = -1.0

## Short message under the top bar (ability feedback).
func toast(text: String, color: Color = Color.WHITE) -> void:
	_toast_text = text
	_toast_color = color
	_toast_t = TOAST_TIME
	queue_redraw()

## Large animated banner in the middle of the view (level-clear sweep).
func show_banner(title: String, subtitle: String) -> void:
	_banner_title = title
	_banner_sub = subtitle
	_banner_t = 0.0
	queue_redraw()

func hide_banner() -> void:
	_banner_t = -1.0
	# Redraw even while the tree is paused (CLEAR / WIN overlay).
	queue_redraw()

func banner_visible() -> bool:
	return _banner_t >= 0.0

func _process(delta: float) -> void:
	_toast_t = maxf(0.0, _toast_t - delta)
	if _banner_t >= 0.0:
		_banner_t += delta
	queue_redraw()

func _draw() -> void:
	if run == null or player == null:
		return
	var v: Vector2 = Palette.VIEW_SIZE
	var panel := Color(0.04, 0.055, 0.1, 0.45)
	DrawUtil.round_rect(self, Rect2(14, 12, 330, 44), 10, panel)
	DrawUtil.text(self, Vector2(28, 26), "★ %d" % run.score, 17, Color("#ffd76a"), HORIZONTAL_ALIGNMENT_LEFT, true)
	var budget: int = int(defense.budget) if defense else 0
	var income: int = int(defense.config.income_per_sec) if defense and defense.config else 0
	DrawUtil.text(self, Vector2(150, 26), "资金 %d  +%d/s" % [budget, income], 15, Color("#7fd4ff"), HORIZONTAL_ALIGNMENT_LEFT, true)
	DrawUtil.text(self, Vector2(28, 45), "%s   本关金币 %d/%d" % [run.level_name, run.level_coins, run.coin_total], 13, Color("#cfe0ff"))

	if placer and placer.is_placing():
		DrawUtil.round_rect(self, Rect2(v.x * 0.5 - 250, 196, 500, 34), 10, Color(0.04, 0.055, 0.1, 0.6))
		DrawUtil.text(self, Vector2(v.x * 0.5, 213), "放置防御道具 · 按住拖动决定方向 · 松开放置 · ESC / 右键取消", 14, Color("#ffd76a"), HORIZONTAL_ALIGNMENT_CENTER, true)

	DrawUtil.round_rect(self, Rect2(v.x - 130, 12, 116, 30), 10, panel)
	DrawUtil.text(self, Vector2(v.x - 72, 27), "时间 " + RunState.format_time(run.level_time), 15, Color("#cfe0ff"), HORIZONTAL_ALIGNMENT_CENTER, true)
	var pads: Array[int] = Input.get_connected_joypads()
	if not pads.is_empty():
		DrawUtil.round_rect(self, Rect2(v.x - 130, 48, 116, 24), 8, panel)
		DrawUtil.text(self, Vector2(v.x - 72, 60), "玩家1 手柄已连接", 11, Color("#6cf0a0"), HORIZONTAL_ALIGNMENT_CENTER, true)

	for i: int in run.max_lives():
		_heart(Vector2(28 + i * 26, 74), Color("#ff5c7a") if i < run.lives else Color(1, 1, 1, 0.18))

	var cw: float = 70.0
	DrawUtil.round_rect(self, Rect2(110, 68, cw, 14), 7, panel)
	var ready: float = 1.0 - clampf(player.dash_cooldown / maxf(player.config.dash_cooldown, 0.001), 0.0, 1.0)
	if ready > 0.0:
		DrawUtil.round_rect(self, Rect2(112, 70, (cw - 4) * ready, 10), 5, Color("#7fd4ff") if ready >= 1.0 else Color("#4b6bb5"))
	DrawUtil.text(self, Vector2(114, 91), "DASH", 10, Color("#9fb2d8"))

	var cls: RunnerClassConfig = run.current_class()
	DrawUtil.text(self, Vector2(28, 108), "● " + cls.display_name, 12, cls.color, HORIZONTAL_ALIGNMENT_LEFT, true)
	DrawUtil.text(self, Vector2(100, 108), cls.description, 11, Color("#9fb2d8"))

	_ability_bar()
	if world_height > v.y + 50.0:
		_altitude_bar(v)
	if _toast_t > 0.0:
		var ta: float = clampf(_toast_t / 0.4, 0.0, 1.0)
		DrawUtil.round_rect(self, Rect2(v.x * 0.5 - 230, 150, 460, 32), 10, Color(0.04, 0.055, 0.1, 0.7 * ta))
		DrawUtil.text(self, Vector2(v.x * 0.5, 166), _toast_text, 15, Color(_toast_color, ta), HORIZONTAL_ALIGNMENT_CENTER, true)
	if _banner_t >= 0.0:
		_banner(v)

## Wallet + coin abilities (dimmed when unaffordable).
func _ability_bar() -> void:
	var cfg: PlayerConfig = player.config
	DrawUtil.round_rect(self, Rect2(14, 122, 330, 30), 10, Color(0.04, 0.055, 0.1, 0.45))
	draw_circle(Vector2(32, 137), 8, Color("#ffd76a"))
	draw_circle(Vector2(32, 137), 4, Color("#f0b53a"))
	DrawUtil.text(self, Vector2(46, 137), "%d" % run.wallet, 15, Color("#ffd76a"), HORIZONTAL_ALIGNMENT_LEFT, true)
	var can_shield: bool = run.wallet >= cfg.shield_cost
	var can_clear: bool = run.wallet >= cfg.screen_clear_cost
	DrawUtil.text(self, Vector2(92, 137), "Y/Q 护盾 %d" % cfg.shield_cost, 13, Color("#9fe8ff") if can_shield else Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_LEFT, can_shield)
	DrawUtil.text(self, Vector2(212, 137), "B/E 清屏 %d" % cfg.screen_clear_cost, 13, Color("#7fd4ff") if can_clear else Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_LEFT, can_clear)

func _banner(v: Vector2) -> void:
	var t: float = _banner_t
	# Overshoot pop-in, then gentle pulse.
	var k: float = clampf(t / 0.35, 0.0, 1.0)
	var pop: float = 1.0 + 0.25 * sin(k * PI) if k < 1.0 else 1.0 + 0.03 * sin(t * 6.0)
	var zoom: float = lerpf(0.3, 1.0, 1.0 - pow(1.0 - k, 3.0)) * pop
	var c := Vector2(v.x * 0.5, v.y * 0.3)
	var band_a: float = clampf(t / 0.25, 0.0, 1.0)
	var band_w: float = v.x * clampf(t / 0.3, 0.0, 1.0)
	draw_rect(Rect2(c.x - band_w * 0.5, c.y - 62, band_w, 124), Color(0.04, 0.055, 0.1, 0.55 * band_a))
	draw_rect(Rect2(c.x - band_w * 0.5, c.y - 64, band_w, 3), Color("#ffd76a", band_a))
	draw_rect(Rect2(c.x - band_w * 0.5, c.y + 61, band_w, 3), Color("#ffd76a", band_a))
	draw_set_transform(c, 0.0, Vector2(zoom, zoom))
	DrawUtil.text(self, Vector2(3, -14 + 3), _banner_title, 64, Color(0.6, 0.3, 0.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER, true)
	DrawUtil.text(self, Vector2(0, -14), _banner_title, 64, Color("#ffe08a"), HORIZONTAL_ALIGNMENT_CENTER, true)
	draw_set_transform(Vector2.ZERO)
	var sub_a: float = clampf((t - 0.3) / 0.3, 0.0, 1.0)
	DrawUtil.text(self, c + Vector2(0, 38), _banner_sub, 20, Color(1, 1, 1, sub_a), HORIZONTAL_ALIGNMENT_CENTER, true)

func _altitude_bar(v: Vector2) -> void:
	var bx: float = v.x - 24.0
	var by: float = 118.0
	var bh: float = 210.0
	var top_y: float = player.global_position.y - Player.BODY.y * 0.5
	var t: float = clampf(1.0 - top_y / maxf(1.0, world_height - v.y), 0.0, 1.0)
	DrawUtil.round_rect(self, Rect2(bx - 10, by - 10, 20, bh + 20), 10, Color(0.04, 0.055, 0.1, 0.45))
	DrawUtil.round_rect(self, Rect2(bx - 5, by, 10, bh), 5, Color(1, 1, 1, 0.14))
	var hh: float = maxf(4.0, bh * t)
	DrawUtil.round_rect(self, Rect2(bx - 5, by + bh - hh, 10, hh), 5, Color("#7fd4ff"))
	draw_rect(Rect2(bx - 9, by + bh - hh - 2, 18, 4), Color("#ffd76a"))
	DrawUtil.text(self, Vector2(bx, by - 18), "顶 %dm" % roundi((world_height - v.y) / 10.0), 11, Color("#cfe0ff"), HORIZONTAL_ALIGNMENT_CENTER, true)
	DrawUtil.text(self, Vector2(bx, by + bh + 18), "%dm" % roundi(maxf(0.0, world_height - top_y) / 10.0), 11, Color("#ffd76a"), HORIZONTAL_ALIGNMENT_CENTER, true)

func _heart(at: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 24:
		var a: float = float(i) / 24.0 * TAU
		# Classic parametric heart, scaled to ~18 px.
		var x: float = 16.0 * pow(sin(a), 3.0)
		var y: float = -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(at + Vector2(9, 8) + Vector2(x, y) * 0.55)
	draw_colored_polygon(pts, color)
