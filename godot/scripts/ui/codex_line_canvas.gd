extends Node2D
class_name CodexLineCanvas
## 画古谱主脉骨架线。父节点 StarField 给 size，本节点读 GuPuData.preset_lines 绘线。

const COLOR_PRESET := Color(0.72, 0.55, 0.32, 0.7)
const WIDTH_PRESET: float = 1.5

var _gupu: GuPuData = null
var _field_size: Vector2 = Vector2.ZERO


func setup(gupu: GuPuData, field_size: Vector2) -> void:
	_gupu = gupu
	_field_size = field_size
	queue_redraw()


func _draw() -> void:
	if _gupu == null or _field_size == Vector2.ZERO:
		return
	var lines := _gupu.preset_lines
	var i: int = 0
	while i + 1 < lines.size():
		var a: int = lines[i]
		var b: int = lines[i + 1]
		i += 2
		if a < 0 or a >= _gupu.stars.size() or b < 0 or b >= _gupu.stars.size():
			continue
		var su_a: SuData = _gupu.stars[a]
		var su_b: SuData = _gupu.stars[b]
		if su_a == null or su_b == null:
			continue
		var pa := Vector2(su_a.position_x * _field_size.x, su_a.position_y * _field_size.y)
		var pb := Vector2(su_b.position_x * _field_size.x, su_b.position_y * _field_size.y)
		draw_line(pa, pb, COLOR_PRESET, WIDTH_PRESET)
