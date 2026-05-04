class_name ScrollCard
extends Control
## 卷宗卡片：朱红印章 + 楷书标题 + 实时近况文字 + hover 抬起。
## 整张卷宗可点击 → emit opened。

signal opened

@export var seal_char: String = "炉"
@export var card_title: String = "今日炉记"
@export var card_size: Vector2 = Vector2(280, 160)
@export_range(-10.0, 10.0) var z_rotation_degrees: float = 0.0

const HOVER_LIFT_PX := 6.0
const HOVER_TWEEN_SEC := 0.15

var _hover: bool = false
var _origin_y: float = 0.0
var _active_tween: Tween

@onready var _frame: PanelContainer = $Frame
@onready var _seal_label: Label = $Frame/VBox/Header/Seal/Label
@onready var _title_label: Label = $Frame/VBox/Header/TitleLabel
@onready var _status_label: Label = $Frame/VBox/StatusLabel
@onready var _status_area: Control = $Frame/VBox/StatusArea


func _ready() -> void:
	custom_minimum_size = card_size
	rotation_degrees = z_rotation_degrees
	pivot_offset = card_size * 0.5
	_origin_y = position.y
	_seal_label.text = seal_char
	_title_label.text = card_title
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	gui_input.connect(_on_gui_input)


## 设置近况文本（外部按需调用）
func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


## 把外部 Control（如 DoorVisual）嵌入 StatusArea 替代 status text
func mount_status_widget(widget: Control) -> void:
	if _status_label != null:
		_status_label.visible = false
	if _status_area != null:
		_status_area.add_child(widget)


func _on_mouse_enter() -> void:
	_hover = true
	_animate_hover(true)


func _on_mouse_exit() -> void:
	_hover = false
	_animate_hover(false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			opened.emit()


func _animate_hover(on: bool) -> void:
	if _active_tween != null and _active_tween.is_running():
		_active_tween.kill()
	var t := create_tween()
	_active_tween = t
	var target_y: float = _origin_y - HOVER_LIFT_PX if on else _origin_y
	var target_mod: Color = Color(1.1, 1.05, 1.0, 1.0) if on else Color.WHITE
	t.set_parallel(true)
	t.tween_property(self, "position:y", target_y, HOVER_TWEEN_SEC)
	t.tween_property(_frame, "modulate", target_mod, HOVER_TWEEN_SEC)
