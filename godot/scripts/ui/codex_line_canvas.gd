extends Node2D
class_name CodexLineCanvas
## 画古谱主脉骨架线 + N7b 玩家自连线。

## 主脉骨架默认金色（古谱无 accent_color 时的回退）
const COLOR_PRESET_CORE_DEFAULT := Color(0.940, 0.685, 0.345, 0.85)
const COLOR_PRESET_GLOW_DEFAULT := Color(0.940, 0.685, 0.345, 0.18)
## 玩家自连青线（亮内 + 淡外）
const COLOR_PLAYER_CORE := Color(0.55, 0.85, 1.0, 0.95)
const COLOR_PLAYER_GLOW := Color(0.55, 0.85, 1.0, 0.20)
const WIDTH_CORE: float = 1.6
const WIDTH_GLOW: float = 5.5

var _gupu: GuPuData = null
var _field_size: Vector2 = Vector2.ZERO


func setup(gupu: GuPuData, field_size: Vector2) -> void:
	_gupu = gupu
	_field_size = field_size
	queue_redraw()


func _draw() -> void:
	if _gupu == null or _field_size == Vector2.ZERO:
		return
	# 主脉骨架 — 用古谱 accent_color
	var core: Color = _gupu.accent_color
	core.a = 0.85
	var glow: Color = _gupu.accent_color
	glow.a = 0.18
	var lines := _gupu.preset_lines
	var i: int = 0
	while i + 1 < lines.size():
		var a: int = lines[i]
		var b: int = lines[i + 1]
		i += 2
		_draw_glow_line_by_index(a, b, glow, core)
	# 玩家自连
	var su_to_idx: Dictionary = {}
	for k in _gupu.stars.size():
		var s: SuData = _gupu.stars[k]
		if s != null:
			su_to_idx[s.id] = k
	for pair in CodexState.lines_of(_gupu.id):
		var ia: int = int(su_to_idx.get(StringName(pair[0]), -1))
		var ib: int = int(su_to_idx.get(StringName(pair[1]), -1))
		_draw_glow_line_by_index(ia, ib, COLOR_PLAYER_GLOW, COLOR_PLAYER_CORE)


func _draw_glow_line_by_index(a: int, b: int, glow_color: Color, core_color: Color) -> void:
	if a < 0 or a >= _gupu.stars.size() or b < 0 or b >= _gupu.stars.size():
		return
	var su_a: SuData = _gupu.stars[a]
	var su_b: SuData = _gupu.stars[b]
	if su_a == null or su_b == null:
		return
	var pa := Vector2(su_a.position_x * _field_size.x, su_a.position_y * _field_size.y)
	var pb := Vector2(su_b.position_x * _field_size.x, su_b.position_y * _field_size.y)
	# 外宽淡 + 内细亮
	draw_line(pa, pb, glow_color, WIDTH_GLOW, true)
	draw_line(pa, pb, core_color, WIDTH_CORE, true)
