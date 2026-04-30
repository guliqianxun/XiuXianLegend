extends Control
class_name StarNode
## 单颗星按钮：圆点（亮/暗）+ 装备数量徽章 + click 信号
## 由 CodexScreen 实例化，根据 SuData.position_x/y 在星图上摆位

signal clicked(su_id: StringName)

const SIZE_DIM: float = 12.0
const SIZE_LIT: float = 18.0
const COLOR_DIM := Color(0.30, 0.30, 0.40)
const COLOR_LIT := Color(1.00, 0.85, 0.35)

var su_id: StringName = &""
var equipment_count: int = 0

@onready var _dot: ColorRect = $Dot
@onready var _count_label: Label = $CountLabel
@onready var _btn: Button = $HitArea


func _ready() -> void:
	_btn.pressed.connect(_on_pressed)
	_refresh_visual()


## 设置星位状态。count > 0 = 亮；= 0 = 暗。
func setup(su_id_: StringName, count: int) -> void:
	su_id = su_id_
	equipment_count = count
	if is_inside_tree():
		_refresh_visual()


func _refresh_visual() -> void:
	if equipment_count > 0:
		var s: float = SIZE_LIT
		_dot.color = COLOR_LIT
		_dot.offset_left = -s / 2
		_dot.offset_top = -s / 2
		_dot.offset_right = s / 2
		_dot.offset_bottom = s / 2
		_count_label.text = str(equipment_count)
		_count_label.visible = true
	else:
		var s2: float = SIZE_DIM
		_dot.color = COLOR_DIM
		_dot.offset_left = -s2 / 2
		_dot.offset_top = -s2 / 2
		_dot.offset_right = s2 / 2
		_dot.offset_bottom = s2 / 2
		_count_label.visible = false


func _on_pressed() -> void:
	clicked.emit(su_id)
