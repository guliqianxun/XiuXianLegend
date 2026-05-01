extends Control
class_name NarrativeOverlay
## 屏幕上方淡入淡出的叙事文本 overlay。
## 用于显示手写卡片触发的短文。不阻塞输入。

@onready var _label: Label = $Frame/Label
@onready var _frame: PanelContainer = $Frame

const SHOW_SEC: float = 2.0
const FADE_SEC: float = 0.5


func _ready() -> void:
	# 不拦截鼠标
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_text(text: String) -> void:
	if text.is_empty():
		return
	# 防御性 size + position（同其他 overlay）
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	visible = true
	_label.text = text
	_frame.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_frame, "modulate:a", 1.0, FADE_SEC)
	tw.tween_interval(SHOW_SEC)
	tw.tween_property(_frame, "modulate:a", 0.0, FADE_SEC)
	tw.tween_callback(func() -> void: visible = false)
