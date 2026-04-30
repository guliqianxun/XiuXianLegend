extends Control
class_name ReturnNotice
## 装备归来时屏幕中上浮窗，3.5 秒自动消失。

const DISPLAY_SEC: float = 3.5

@onready var _label: Label = $Frame/Label


func _ready() -> void:
	visible = false


func show_notice(text: String) -> void:
	_label.text = text
	visible = true
	await get_tree().create_timer(DISPLAY_SEC).timeout
	visible = false
