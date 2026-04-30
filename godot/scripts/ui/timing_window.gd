extends Control
class_name TimingWindow
## 3 秒火候判定条。一根条从左划到右，玩家在中间"靶区"按下空格/点击 → 得分 0..1。
## 信号 timing_finished(score: float) 回报，0=miss/超时，1=正中靶心。

signal timing_finished(score: float)

const DURATION_SEC: float = 3.0
const TARGET_CENTER: float = 0.65  ## 靶心位置（0..1）
const TARGET_RADIUS: float = 0.10  ## 满分窗口宽度

@onready var _bar: ProgressBar = $Bar
@onready var _target: ColorRect = $TargetZone
@onready var _cursor: ColorRect = $Cursor

var _running: bool = false
var _t: float = 0.0


func _ready() -> void:
	visible = false
	_bar.value = 0
	# 摆 target zone
	_target.anchor_left = TARGET_CENTER - TARGET_RADIUS
	_target.anchor_right = TARGET_CENTER + TARGET_RADIUS
	_target.offset_left = 0
	_target.offset_right = 0


## 启动倒计时；玩家按空格或点击场景结束。超时按 t=1.0 算 score=0
func start() -> void:
	_running = true
	_t = 0.0
	visible = true
	_bar.value = 0
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	var ratio: float = clampf(_t / DURATION_SEC, 0.0, 1.0)
	_bar.value = ratio * 100.0
	_cursor.anchor_left = ratio
	_cursor.anchor_right = ratio
	_cursor.offset_left = -2
	_cursor.offset_right = 2
	if _t >= DURATION_SEC:
		_finish(0.0)


func _input(event: InputEvent) -> void:
	if not _running:
		return
	var hit: bool = false
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		hit = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hit = true
	if hit:
		var ratio: float = clampf(_t / DURATION_SEC, 0.0, 1.0)
		var score: float = score_at_ratio(ratio)
		_finish(score)


func _finish(score: float) -> void:
	_running = false
	set_process(false)
	set_process_input(false)
	visible = false
	timing_finished.emit(score)


## 给定时间比例，返回得分 0..1。靠近 TARGET_CENTER 越近分数越高。
static func score_at_ratio(ratio: float) -> float:
	var dist: float = absf(ratio - TARGET_CENTER)
	if dist >= TARGET_RADIUS:
		var beyond: float = dist - TARGET_RADIUS
		var fade_window: float = TARGET_RADIUS
		if beyond >= fade_window:
			return 0.0
		return 1.0 - (beyond / fade_window)
	return 1.0
