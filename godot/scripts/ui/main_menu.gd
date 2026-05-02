extends Control
## 主菜单 — 标题 + 入口。

const SHOP_SCENE := "res://scenes/shop.tscn"

@onready var _start_btn: Button = $Layout/Panel/VBox/StartButton
@onready var _quit_btn: Button = $Layout/Panel/VBox/QuitButton
@onready var _subtitle: Label = $Layout/Panel/VBox/Subtitle


func _ready() -> void:
	_start_btn.pressed.connect(_on_start)
	_quit_btn.pressed.connect(_on_quit)
	_apply_subtitle()
	# 标题轻 fade-in
	modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6)


func _apply_subtitle() -> void:
	# 显示存档状态：有存档说"继续"否则"开始"
	var has_save: bool = FileAccess.file_exists(SaveSystem.SAVE_PATH)
	if has_save:
		_start_btn.text = "继续"
		_subtitle.text = "—— 老铁的炉火还没凉 ——"
	else:
		_start_btn.text = "推门"
		_subtitle.text = "—— 这间铺子，刚刚有人接手 ——"


func _on_start() -> void:
	get_tree().change_scene_to_file(SHOP_SCENE)


func _on_quit() -> void:
	get_tree().quit()
