extends Node2D
class_name CodexLineCanvas
## 画古谱主脉骨架线 + N7b 玩家自连线。

const COLOR_PRESET := Color(0.72, 0.55, 0.32, 0.7)  # 主脉骨架（金线）
const COLOR_PLAYER := Color(0.55, 0.85, 1.0, 0.85)  # 玩家自连（青线）
const WIDTH_PRESET: float = 1.5
const WIDTH_PLAYER: float = 2.0

var _gupu: GuPuData = null
var _field_size: Vector2 = Vector2.ZERO


func setup(gupu: GuPuData, field_size: Vector2) -> void:
	_gupu = gupu
	_field_size = field_size
	queue_redraw()


func _draw() -> void:
	if _gupu == null or _field_size == Vector2.ZERO:
		return
	# 主脉骨架
	var lines := _gupu.preset_lines
	var i: int = 0
	while i + 1 < lines.size():
		var a: int = lines[i]
		var b: int = lines[i + 1]
		i += 2
		_draw_pair_by_index(a, b, COLOR_PRESET, WIDTH_PRESET)
	# 玩家自连（青色虚感）
	var su_to_idx: Dictionary = {}
	for k in _gupu.stars.size():
		var s: SuData = _gupu.stars[k]
		if s != null:
			su_to_idx[s.id] = k
	for pair in CodexState.lines_of(_gupu.id):
		var ia: int = int(su_to_idx.get(StringName(pair[0]), -1))
		var ib: int = int(su_to_idx.get(StringName(pair[1]), -1))
		_draw_pair_by_index(ia, ib, COLOR_PLAYER, WIDTH_PLAYER)


func _draw_pair_by_index(a: int, b: int, color: Color, width: float) -> void:
	if a < 0 or a >= _gupu.stars.size() or b < 0 or b >= _gupu.stars.size():
		return
	var su_a: SuData = _gupu.stars[a]
	var su_b: SuData = _gupu.stars[b]
	if su_a == null or su_b == null:
		return
	var pa := Vector2(su_a.position_x * _field_size.x, su_a.position_y * _field_size.y)
	var pb := Vector2(su_b.position_x * _field_size.x, su_b.position_y * _field_size.y)
	draw_line(pa, pb, color, width)
