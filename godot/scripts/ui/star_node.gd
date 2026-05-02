extends Control
class_name StarNode
## 单颗星按钮：自绘 glow 圆点（亮/暗）+ 装备数量徽章 + click 信号
## 由 CodexScreen 实例化，根据 SuData.position_x/y 在星图上摆位

signal clicked(su_id: StringName)

const RADIUS_DIM: float = 3.0
const RADIUS_LIT_CORE: float = 4.5
const GLOW_LAYERS: int = 5
const GLOW_RADIUS_MAX: float = 16.0

const COLOR_DIM := Color(0.345, 0.300, 0.270, 0.65)
const COLOR_DIM_RING := Color(0.510, 0.430, 0.350, 0.40)
const COLOR_LIT_CORE := Color(1.000, 0.950, 0.785, 1.0)
const COLOR_LIT_GLOW := Color(0.940, 0.685, 0.345, 0.55)

var su_id: StringName = &""
var equipment_count: int = 0

@onready var _count_label: Label = $CountLabel
@onready var _btn: Button = $HitArea


func _ready() -> void:
	# 旧的 ColorRect Dot 移除（如果场景仍有）— 由 _draw 取代
	if has_node("Dot"):
		$Dot.queue_free()
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
		_count_label.text = str(equipment_count)
		_count_label.visible = true
	else:
		_count_label.visible = false
	queue_redraw()


func _draw() -> void:
	var c := Vector2.ZERO  # Control 局部 (0,0) 即星位中心（父级 position 已偏移）
	if equipment_count > 0:
		# glow 多层圆，从外到内
		for i in GLOW_LAYERS:
			var t: float = float(i + 1) / float(GLOW_LAYERS)
			var r: float = lerpf(RADIUS_LIT_CORE, GLOW_RADIUS_MAX, t)
			var col: Color = COLOR_LIT_GLOW
			col.a = COLOR_LIT_GLOW.a * (1.0 - t) * 0.6
			draw_circle(c, r, col)
		# 中心亮核
		draw_circle(c, RADIUS_LIT_CORE, COLOR_LIT_CORE)
	else:
		# 暗态：小圆 + 微环
		draw_circle(c, RADIUS_DIM + 1.5, COLOR_DIM_RING)
		draw_circle(c, RADIUS_DIM, COLOR_DIM)


func _on_pressed() -> void:
	clicked.emit(su_id)
