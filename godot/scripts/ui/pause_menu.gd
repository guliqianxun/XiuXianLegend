extends Control
class_name PauseMenu
## ESC 唤出的暂停菜单：继续 / 回主菜单 / 退出。
## 监听 InputMap 'ui_pause'（项目已绑定 Esc 键）。

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

@onready var _resume_btn: Button = $Frame/VBox/ResumeButton
@onready var _menu_btn: Button = $Frame/VBox/MenuButton
@onready var _quit_btn: Button = $Frame/VBox/QuitButton


func _ready() -> void:
	visible = false
	_resume_btn.pressed.connect(_on_resume)
	_menu_btn.pressed.connect(_on_back_to_menu)
	_quit_btn.pressed.connect(_on_quit)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		_on_resume()
	else:
		open()


func open() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	visible = true
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍能 input
	Sfx.play_seal_stamp()


func _on_resume() -> void:
	visible = false
	get_tree().paused = false
	Sfx.play_paper_flutter()


func _on_back_to_menu() -> void:
	# 返回主菜单前强制存档
	get_tree().paused = false
	SaveSystem.save_now(true)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit() -> void:
	get_tree().paused = false
	SaveSystem.save_now(true)
	get_tree().quit()
