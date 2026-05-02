extends Control
class_name ShichenDial
## 12 时辰刻度圆盘。当前时辰高亮 + 顺时针指针。
## 自绘（Control._draw），无资源依赖。

const RING_RADIUS_PX: float = 22.0
const DOT_RADIUS_PX: float = 2.6
const POINTER_LEN_PX: float = 18.0

const COLOR_RING := Color(0.345, 0.180, 0.130, 0.55)
const COLOR_DOT := Color(0.685, 0.520, 0.395, 0.85)
const COLOR_DOT_HIGHLIGHT := Color(0.940, 0.870, 0.685, 1.0)
const COLOR_POINTER := Color(0.745, 0.327, 0.235, 0.95)

var _shichen: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.time_advanced.connect(_on_time_advanced)
	EventBus.save_loaded.connect(_refresh_from_state)
	_refresh_from_state()


func _refresh_from_state() -> void:
	_shichen = TimeLine.shichen_of_unix(TimeLine.now_unix())
	queue_redraw()


func _on_time_advanced(_unix: int, _delta: int) -> void:
	var sh := TimeLine.shichen_of_unix(TimeLine.now_unix())
	if sh != _shichen:
		_shichen = sh
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	# 圆环
	draw_arc(c, RING_RADIUS_PX, 0.0, TAU, 32, COLOR_RING, 1.5, true)
	# 12 颗 dot
	for i in 12:
		var ang: float = (float(i) / 12.0) * TAU - PI / 2.0  # 子时在 12 点位置
		var p: Vector2 = c + Vector2(cos(ang), sin(ang)) * RING_RADIUS_PX
		var col: Color = COLOR_DOT_HIGHLIGHT if i == _shichen else COLOR_DOT
		var r: float = DOT_RADIUS_PX * (1.4 if i == _shichen else 1.0)
		draw_circle(p, r, col)
	# 指针指向当前时辰
	var pointer_ang: float = (float(_shichen) / 12.0) * TAU - PI / 2.0
	var tip: Vector2 = c + Vector2(cos(pointer_ang), sin(pointer_ang)) * POINTER_LEN_PX
	draw_line(c, tip, COLOR_POINTER, 1.6, true)
	# 中心墨点
	draw_circle(c, 2.0, COLOR_POINTER)
